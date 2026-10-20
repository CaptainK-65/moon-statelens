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
    )
    driver = Some(active)
    for ;; {
      match active.event(queries=experiment.statistics().queries) {
        Query(request) =>
          active.submit(request.id, experiment.query(request.inputs))
        Hypothesis(model) =>
          match (oracle.check)(model, experiment) {
            Counterexample(word) =>
              active.refine(word, experiment.query(word, bypass_cache=true))
            NoCounterexample(evidence) => return result(Supported(evidence))
            Inconclusive(reason) => return result(Inconclusive(reason))
          }
      }
    }
  } catch {
    LimitExceeded(reason) => result(Inconclusive(reason))
    InconsistentObservation(word~, expected~, actual~) =>
      result(Unstable(word~, expected~, actual~))
    error => raise error
  }
}
