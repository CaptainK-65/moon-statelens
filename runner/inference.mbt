///|
pub(all) struct InferenceReport {
  algorithm : String
  learning : @lens.LearningResult
  metrics : @lens.DriverMetrics
  verification : Array[Array[@lens.VerificationStage]]
} derive(Debug)

///|
pub extend InferenceReport with @debug.Debug::{to_repr}

///|
pub impl ToJson for InferenceReport with fn to_json(self) {
  Json::object({
    "format": Json("moonstatelens.inference"),
    "version": Json(2),
    "algorithm": Json(self.algorithm),
    "learning": Json(self.learning),
    "metrics": Json(self.metrics),
    "verification": Json(self.verification),
  })
}

///|
pub extend InferenceReport with ToJson::{to_json}

///|
/// Learn with real async IO. No reference model is required for non-exact plans.
pub async fn infer(
  experiment : AsyncExperiment,
  plan : @lens.VerificationPlan,
  algorithm~ : @lens.Algorithm = LStar,
  max_states~ : Int32 = 256,
  max_rounds~ : Int32 = 64,
  max_table_cells~ : Int32 = 1000000,
  max_table_symbols~ : Int32 = 4000000,
  max_prefixes~ : Int32 = 20000,
) -> InferenceReport {
  let mut driver : @lens.LearningDriver? = None
  let verification : Array[Array[@lens.VerificationStage]] = []
  let mut cursor : @lens.VerificationCursor? = None
  fn result(status) {
    let learning = match driver {
      Some(d) => d.result(experiment.statistics(), status)
      None =>
        {
          model: None,
          status,
          statistics: experiment.statistics(),
          rounds: [],
          counterexamples: [],
        }
    }
    if cursor is Some(c) {
      verification.push(c.stages())
    }
    {
      algorithm: algorithm.name(),
      learning,
      metrics: match driver {
        Some(d) => d.metrics()
        None =>
          {
            states: 0,
            access_sequences: 0,
            discriminators: 0,
            table_cells: 0,
            table_symbols: 0,
            tree_nodes: 0,
          }
      },
      verification: verification.copy(),
    }
  }
  try {
    let active = @lens.LearningDriver::new(
      algorithm,
      experiment.alphabet(),
      max_states~,
      max_rounds~,
      max_table_cells~,
      max_table_symbols~,
      max_prefixes~,
    )
    driver = Some(active)
    for ;; {
      match active.event(queries=experiment.statistics().queries) {
        Query(request) =>
          active.submit(request.id, experiment.query(request.inputs))
        Hypothesis(model) => {
          let checking = @lens.VerificationCursor::new(plan, model)
          cursor = Some(checking)
          let decision = for ;; {
            match checking.event() {
              Query(request) =>
                checking.submit(
                  request.id,
                  experiment.query(request.inputs, bypass_cache=true),
                )
              Completed(result) => break result
            }
          }
          verification.push(checking.stages())
          cursor = None
          match decision {
            Counterexample(word) =>
              active.refine(word, experiment.query(word, bypass_cache=true))
            NoCounterexample(evidence) => return result(Supported(evidence))
            Inconclusive(reason) => return result(Inconclusive(reason))
          }
        }
      }
    }
  } catch {
    @lens.LimitExceeded(reason) => result(Inconclusive(reason))
    @lens.InconsistentObservation(word~, expected~, actual~) =>
      result(Unstable(word~, expected~, actual~))
    error => raise error
  }
}
