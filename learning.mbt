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
/// Learn only through experiment queries. The oracle searches for counterexamples;
/// its evidence determines what a Supported status actually means.
/// Resource limits return Inconclusive with the last completed hypothesis, if any.
pub fn learn(
  experiment : Experiment,
  oracle : Oracle,
  max_states~ : Int32 = 256,
  max_rounds~ : Int32 = 64,
  max_table_cells~ : Int32 = 1000000,
  max_table_symbols~ : Int32 = 4000000,
  max_prefixes~ : Int32 = 20000,
) -> LearningResult raise {
  if max_states < 1 ||
    max_states > 4096 ||
    max_rounds < 1 ||
    max_table_cells < 1 ||
    max_table_symbols < 1 ||
    max_prefixes < 1 {
    raise InvalidArgument("invalid learning budget")
  }
  let table = ObservationTable::new(
    experiment,
    max_cells=max_table_cells,
    max_symbols=max_table_symbols,
    max_prefixes~,
    max_states~,
  )
  let mut last = None
  let rounds = []
  let counterexamples = []
  try {
    for index in 1..<=max_rounds {
      table.stabilize()
      let hypothesis = table.hypothesis()
      last = Some(hypothesis)
      let decision = (oracle.check)(hypothesis, experiment)
      let mut counterexample_length = None
      if decision is Counterexample(word) {
        counterexample_length = Some(word.length())
      }
      rounds.push({
        index,
        states: hypothesis.state_count(),
        prefixes: table.prefixes.length(),
        suffixes: table.suffixes.length(),
        table_cells: table.cells,
        table_symbols: table.symbols,
        queries: experiment.queries,
        counterexample_length,
      })
      match decision {
        Counterexample(word) => {
          let actual = experiment.query(word, bypass_cache=true)
          let expected = hypothesis.trace(word)
          guard actual != expected else {
            raise InvalidArgument("oracle returned a non-counterexample")
          }
          // Ignore any tail after the first mismatching output. This is a
          // distinguishing prefix, not a globally shortest counterexample claim.
          let mut end = 0
          for i in 0..<actual.length() {
            if actual[i] != expected[i] {
              end = i + 1
              break
            }
          }
          let inputs = word[:end].to_owned()
          counterexamples.push({
            inputs,
            left_outputs: expected[:end].to_owned(),
            right_outputs: actual[:end].to_owned(),
          })
          table.refine(inputs)
        }
        NoCounterexample(evidence) =>
          return learning_result(
            experiment,
            last,
            Supported(evidence),
            rounds,
            counterexamples,
          )
        Inconclusive(reason) =>
          return learning_result(
            experiment,
            last,
            Inconclusive(reason),
            rounds,
            counterexamples,
          )
      }
    }
    learning_result(
      experiment,
      last,
      Inconclusive("learning-rounds"),
      rounds,
      counterexamples,
    )
  } catch {
    LimitExceeded(reason) =>
      learning_result(
        experiment,
        last,
        Inconclusive(reason),
        rounds,
        counterexamples,
      )
    InconsistentObservation(word~, expected~, actual~) =>
      learning_result(
        experiment,
        last,
        Unstable(word~, expected~, actual~),
        rounds,
        counterexamples,
      )
    error => raise error
  }
}
