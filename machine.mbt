///|
/// One transition of a complete deterministic Mealy machine.
pub(all) struct Transition {
  target : Int32
  output : String
} derive(Eq, Debug, ToJson)

///|
pub extend Transition with Eq::{equal, not_equal}

///|
pub extend Transition with @debug.Debug::{to_repr}

///|
pub extend Transition with ToJson::{to_json}

///|
/// Validated model; construction and accessors defensively copy arrays.
pub struct Machine {
  priv alphabet : Array[String]
  priv initial : Int32
  priv transitions : Array[Array[Transition]]
} derive(Debug)

///|
pub extend Machine with @debug.Debug::{to_repr}

///|
fn validate_alphabet(alphabet : Array[String]) -> Unit raise LensError {
  if alphabet.is_empty() || alphabet.length() > 256 {
    raise InvalidArgument("alphabet must contain 1..256 distinct symbols")
  }
  let seen : Map[String, Unit] = Map([])
  for input in alphabet {
    if seen.contains(input) {
      raise InvalidArgument("duplicate input symbol: " + input)
    }
    seen[input] = ()
  }
}

///|
/// Construct a complete machine. Table columns follow alphabet order.
pub fn Machine::new(
  alphabet : Array[String],
  transitions : Array[Array[Transition]],
  initial~ : Int32 = 0,
) -> Machine raise LensError {
  validate_alphabet(alphabet)
  if transitions.is_empty() || transitions.length() > 4096 {
    raise InvalidArgument("model must contain 1..4096 states")
  }
  if initial < 0 || initial >= transitions.length() {
    raise InvalidArgument("initial state out of range")
  }
  for row in transitions {
    if row.length() != alphabet.length() {
      raise InvalidArgument("model must have exactly one transition per input")
    }
    for edge in row {
      if edge.target < 0 || edge.target >= transitions.length() {
        raise InvalidArgument("transition target out of range")
      }
    }
  }
  {
    alphabet: alphabet.copy(),
    initial,
    transitions: transitions.map(row => row.copy()),
  }
}

///|
pub fn Machine::alphabet(self : Machine) -> Array[String] {
  self.alphabet.copy()
}

///|
pub fn Machine::state_count(self : Machine) -> Int32 {
  self.transitions.length()
}

///|
pub fn Machine::initial_state(self : Machine) -> Int32 {
  self.initial
}

///|
pub fn Machine::table(self : Machine) -> Array[Array[Transition]] {
  self.transitions.map(row => row.copy())
}

///|
fn Machine::input_index(
  self : Machine,
  input : String,
) -> Int32 raise LensError {
  match self.alphabet.search(input) {
    Some(index) => index
    None => raise UnknownInput(input)
  }
}

///|
/// Execute an input word starting at the model's initial state.
pub fn Machine::trace(
  self : Machine,
  word : Array[String],
) -> Array[String] raise LensError {
  self.trace_from(self.initial, word)
}

///|
/// Execute an input word starting at an explicitly selected state.
pub fn Machine::trace_from(
  self : Machine,
  state : Int32,
  word : Array[String],
) -> Array[String] raise LensError {
  if state < 0 || state >= self.state_count() {
    raise InvalidArgument("state out of range")
  }
  let mut current = state
  let outputs = []
  for input in word {
    let edge = self.transitions[current][self.input_index(input)]
    outputs.push(edge.output)
    current = edge.target
  }
  outputs
}

///|
/// Shortest access words for reachable states, in BFS/input order.
pub fn Machine::access_sequences(
  self : Machine,
) -> Array[(Int32, Array[String])] {
  let seen : Map[Int32, Unit] = Map([(self.initial, ())])
  let queue = [(self.initial, [])]
  for head = 0; head < queue.length(); head = head + 1 {
    let (state, word) = queue[head]
    for input, edge in self.transitions[state] {
      if !seen.contains(edge.target) {
        seen[edge.target] = ()
        queue.push((edge.target, word + [self.alphabet[input]]))
      }
    }
  }
  queue
}
