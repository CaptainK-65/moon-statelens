///|
/// Structurally different Mealy learners sharing query and model infrastructure.
pub(all) enum Algorithm {
  LStar
  KearnsVazirani
} derive(Debug, Eq)

///|
pub extend Algorithm with @debug.Debug::{to_repr}

///|
pub extend Algorithm with Eq::{equal, not_equal}

///|
pub fn Algorithm::name(self : Algorithm) -> String {
  match self {
    LStar => "lstar"
    KearnsVazirani => "kv"
  }
}

///|
pub(all) struct DriverMetrics {
  states : Int32
  access_sequences : Int32
  discriminators : Int32
  table_cells : Int32
  table_symbols : Int32
  tree_nodes : Int32
} derive(Debug, ToJson)

///|
pub extend DriverMetrics with @debug.Debug::{to_repr}

///|
pub extend DriverMetrics with ToJson::{to_json}

///|
priv struct ActiveMetrics {
  mut states : Int32
  mut accesses : Int32
  mut discriminators : Int32
  mut cells : Int32
  mut symbols : Int32
  mut nodes : Int32
}

///|
fn ActiveMetrics::snapshot(self : ActiveMetrics) -> DriverMetrics {
  {
    states: self.states,
    access_sequences: self.accesses,
    discriminators: self.discriminators,
    table_cells: self.cells,
    table_symbols: self.symbols,
    tree_nodes: self.nodes,
  }
}

///|
/// Continuations retain the actual algorithm state. Resuming does not restart
/// learning or replay previously executed algorithm phases.
priv enum Instruction {
  Ask(Array[String], (Array[String]) -> Instruction raise)
  Candidate(Machine, (Array[String], Array[String]) -> Instruction raise)
}

///|
pub(all) enum LearningEvent {
  Query(QueryRequest)
  Hypothesis(Machine)
} derive(Debug)

///|
pub extend LearningEvent with @debug.Debug::{to_repr}

///|
/// IO-independent suspended learner. Execute Query using a QuerySession/runner;
/// verify each Hypothesis, then refine with a freshly executed counterexample.
pub struct LearningDriver {
  priv algorithm : Algorithm
  priv metrics : ActiveMetrics
  priv max_rounds : Int32
  priv rounds : Array[LearningRound]
  priv counterexamples : Array[Difference]
  priv mut instruction : Instruction
  priv mut serial : Int32
  priv mut pending : Int32?
  priv mut announced : Bool
  priv mut failed : Bool
  priv mut last : Machine?
}

///|
pub fn LearningDriver::new(
  algorithm : Algorithm,
  alphabet : Array[String],
  max_states~ : Int32 = 256,
  max_rounds~ : Int32 = 64,
  max_table_cells~ : Int32 = 1000000,
  max_table_symbols~ : Int32 = 4000000,
  max_prefixes~ : Int32 = 20000,
) -> LearningDriver raise {
  validate_alphabet(alphabet)
  if max_states < 1 ||
    max_states > 4096 ||
    max_rounds < 1 ||
    max_table_cells < 1 ||
    max_table_symbols < 1 ||
    max_prefixes < 1 {
    raise InvalidArgument("invalid learning budget")
  }
  let metrics = {
    states: 0,
    accesses: 0,
    discriminators: 0,
    cells: 0,
    symbols: 0,
    nodes: 0,
  }
  let instruction = match algorithm {
    LStar =>
      ActiveTable::new(
        alphabet, metrics, max_states, max_table_cells, max_table_symbols, max_prefixes,
      ).fill()
    KearnsVazirani =>
      ActiveTree::new(alphabet, metrics, max_states, max_prefixes).build()
  }
  {
    algorithm,
    metrics,
    max_rounds,
    rounds: [],
    counterexamples: [],
    instruction,
    serial: 0,
    pending: None,
    announced: false,
    failed: false,
    last: None,
  }
}

///|
pub fn LearningDriver::algorithm(self : LearningDriver) -> Algorithm {
  self.algorithm
}

///|
pub fn LearningDriver::metrics(self : LearningDriver) -> DriverMetrics {
  self.metrics.snapshot()
}

///|
/// Repeated calls return the same outstanding event with defensive word copies.
pub fn LearningDriver::event(
  self : LearningDriver,
  queries~ : Int32 = 0,
) -> LearningEvent raise LensError {
  if self.failed {
    raise InvalidArgument("failed learning driver")
  }
  match self.instruction {
    Ask(word, _) => {
      let id = match self.pending {
        Some(id) => id
        None => {
          if self.serial == 2147483647 {
            raise LimitExceeded("driver-identifiers")
          }
          self.serial += 1
          self.pending = Some(self.serial)
          self.serial
        }
      }
      Query({ id, inputs: word.copy(), })
    }
    Candidate(model, _) => {
      if !self.announced {
        self.last = Some(model)
        self.metrics.states = model.state_count()
        self.rounds.push({
          index: self.rounds.length() + 1,
          states: model.state_count(),
          prefixes: self.metrics.accesses,
          suffixes: self.metrics.discriminators,
          table_cells: self.metrics.cells,
          table_symbols: self.metrics.symbols,
          queries,
          counterexample_length: None,
        })
        self.announced = true
      }
      Hypothesis(model)
    }
  }
}

///|
pub fn LearningDriver::submit(
  self : LearningDriver,
  id : Int32,
  outputs : Array[String],
) -> Unit raise {
  if self.failed || self.pending != Some(id) {
    raise InvalidArgument("stale or missing learner request")
  }
  guard self.instruction is Ask(word, consume) else {
    raise InvalidArgument("learner is not waiting for a query")
  }
  if word.length() != outputs.length() {
    raise InvalidArgument("incomplete learner trace")
  }
  self.pending = None
  errdefer {
    self.failed = true
  }
  self.instruction = consume(outputs.copy())
}

///|
/// Validate and trim a real counterexample at its first mismatching output.
pub fn LearningDriver::refine(
  self : LearningDriver,
  requested : Array[String],
  actual : Array[String],
) -> Unit raise {
  if self.failed || !self.announced {
    raise InvalidArgument("no announced hypothesis")
  }
  guard self.instruction is Candidate(model, refine) else {
    raise InvalidArgument("cannot refine while a query is outstanding")
  }
  if requested.length() != actual.length() {
    raise InvalidArgument("incomplete counterexample")
  }
  let word = requested.copy()
  let expected = model.trace(word)
  let mut end = 0
  for i in 0..<word.length() {
    if expected[i] != actual[i] {
      end = i + 1
      break
    }
  }
  if end == 0 {
    raise InvalidArgument("oracle returned a non-counterexample")
  }
  let inputs = word[:end].to_owned()
  let observed = actual[:end].to_owned()
  self.counterexamples.push({
    inputs: inputs.copy(),
    left_outputs: expected[:end].to_owned(),
    right_outputs: observed.copy(),
  })
  let last = self.rounds.length() - 1
  self.rounds[last] = { ..self.rounds[last], counterexample_length: Some(end), }
  if self.rounds.length() >= self.max_rounds {
    self.failed = true
    raise LimitExceeded("learning-rounds")
  }
  self.announced = false
  errdefer {
    self.failed = true
  }
  self.instruction = refine(inputs, observed)
}

///|
/// Snapshot the last COMPLETE hypothesis, never an in-progress transition table.
pub fn LearningDriver::result(
  self : LearningDriver,
  statistics : Statistics,
  status : LearningStatus,
) -> LearningResult {
  {
    model: self.last,
    status,
    statistics,
    rounds: self.rounds.copy(),
    counterexamples: self.counterexamples.map(d => {
      inputs: d.inputs.copy(),
      left_outputs: d.left_outputs.copy(),
      right_outputs: d.right_outputs.copy(),
    }),
  }
}
