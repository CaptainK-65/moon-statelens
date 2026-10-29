///|
fn learning_result(
  experiment : Experiment,
  model : Machine?,
  status : LearningStatus,
  rounds : Array[LearningRound],
  counterexamples : Array[Difference],
) -> LearningResult {
  {
    model,
    status,
    statistics: experiment.statistics(),
    rounds,
    counterexamples,
  }
}

///|
/// Synchronous L* compatibility entry. The same suspended learner also powers
/// native asynchronous runners.
pub fn learn(
  experiment : Experiment,
  oracle : Oracle,
  max_states~ : Int32 = 256,
  max_rounds~ : Int32 = 64,
  max_table_cells~ : Int32 = 1000000,
  max_table_symbols~ : Int32 = 4000000,
  max_prefixes~ : Int32 = 20000,
) -> LearningResult raise {
  learn_with(
    experiment,
    oracle,
    LStar,
    max_states~,
    max_rounds~,
    max_table_cells~,
    max_table_symbols~,
    max_prefixes~,
  )
}

///|
/// Select L* or KV without changing the synchronous custom-oracle contract.
pub fn learn_with(
  experiment : Experiment,
  oracle : Oracle,
  algorithm : Algorithm,
  max_states~ : Int32 = 256,
  max_rounds~ : Int32 = 64,
  max_table_cells~ : Int32 = 1000000,
  max_table_symbols~ : Int32 = 4000000,
  max_prefixes~ : Int32 = 20000,
  seed? : Machine,
  binary_cex~ : Bool = false,
  on_event~ : (Json) -> Unit = _ => (),
) -> LearningResult raise {
  let mut driver : LearningDriver? = None
  fn result(status) {
    match driver {
      Some(driver) => driver.result(experiment.statistics(), status)
      None => learning_result(experiment, None, status, [], [])
    }
  }
  try {
    let active = LearningDriver::new(
      algorithm,
      experiment.alphabet,
      max_states~,
      max_rounds~,
      max_table_cells~,
      max_table_symbols~,
      max_prefixes~,
      seed?,
      binary_cex~,
    )
    driver = Some(active)
    for ;; {
      match active.event(queries=experiment.statistics().queries) {
        Query(request) =>
          active.submit(request.id, experiment.query(request.inputs))
        Hypothesis(model) => {
          on_event(
            Json::object({
              "kind": Json("hypothesis"),
              "model": Json(model),
              "statistics": Json(experiment.statistics()),
            }),
          )
          match (oracle.check)(model, experiment) {
            Counterexample(word) => {
              let outputs = experiment.query(word, bypass_cache=true)
              on_event(
                Json::object({
                  "kind": Json("counterexample"),
                  "inputs": Json(word),
                  "predicted": Json(model.trace(word)),
                  "observed": Json(outputs),
                  "statistics": Json(experiment.statistics()),
                }),
              )
              active.refine(word, outputs)
            }
            NoCounterexample(evidence) => {
              on_event(
                Json::object({
                  "kind": Json("verification"),
                  "evidence": Json(evidence),
                  "statistics": Json(experiment.statistics()),
                }),
              )
              return result(Supported(evidence))
            }
            Inconclusive(reason) => {
              on_event(
                Json::object({
                  "kind": Json("inconclusive"),
                  "reason": Json(reason),
                }),
              )
              return result(Inconclusive(reason))
            }
          }
        }
      }
    }
  } catch {
    LimitExceeded(reason) => {
      on_event(
        Json::object({ "kind": Json("inconclusive"), "reason": Json(reason) }),
      )
      result(Inconclusive(reason))
    }
    InconsistentObservation(word~, expected~, actual~) =>
      result(Unstable(word~, expected~, actual~))
    error => raise error
  }
}
