///|
/// Immutable counters. Queries count logical requests; resets and steps count
/// attempted target calls, including failed calls. Cache hits execute no target code.
pub(all) struct Statistics {
  queries : Int32
  cache_hits : Int32
  resets : Int32
  steps : Int32
  completed_queries : Int32
  cache_nodes : Int32
  output_code_units : Int32
} derive(Debug, ToJson)

///|
pub extend Statistics with @debug.Debug::{to_repr}

///|
pub extend Statistics with ToJson::{to_json}

///|
priv struct TraceNode {
  children : Map[String, Int32]
  output : String?
}

///|
/// Bounded experiment session, with a prefix trace cache and consistency checks.
/// Do not run a session concurrently or mutate a target outside its adapter.
pub struct Experiment {
  priv system : System
  priv alphabet : Array[String]
  priv nodes : Array[TraceNode]
  priv max_queries : Int32
  priv max_steps : Int32
  priv max_word_length : Int32
  priv max_cache_nodes : Int32
  priv max_output_code_units : Int32
  priv use_cache : Bool
  priv recheck_every : Int32
  priv mut queries : Int32
  priv mut cache_hits : Int32
  priv mut resets : Int32
  priv mut steps : Int32
  priv mut completed_queries : Int32
  priv mut output_code_units : Int32
  priv mut in_flight : Bool
  priv mut conflict : (Array[String], Array[String], Array[String])?
}

///|
pub fn Experiment::new(
  system : System,
  alphabet : Array[String],
  max_queries~ : Int32 = 100000,
  max_steps~ : Int32 = 2000000,
  max_word_length~ : Int32 = 4096,
  max_cache_nodes~ : Int32 = 1000000,
  max_output_code_units~ : Int32 = 16777216,
  use_cache~ : Bool = true,
  recheck_every~ : Int32 = 0,
) -> Experiment raise LensError {
  validate_alphabet(alphabet)
  if max_queries < 0 ||
    max_steps < 0 ||
    max_word_length < 0 ||
    max_cache_nodes < 1 ||
    max_output_code_units < 0 ||
    recheck_every < 0 {
    raise InvalidArgument("invalid experiment budget")
  }
  {
    system,
    alphabet: alphabet.copy(),
    nodes: [{ children: Map([]), output: None, }],
    max_queries,
    max_steps,
    max_word_length,
    max_cache_nodes,
    max_output_code_units,
    use_cache,
    recheck_every,
    queries: 0,
    cache_hits: 0,
    resets: 0,
    steps: 0,
    completed_queries: 0,
    output_code_units: 0,
    in_flight: false,
    conflict: None,
  }
}

///|
pub fn Experiment::statistics(self : Experiment) -> Statistics {
  {
    queries: self.queries,
    cache_hits: self.cache_hits,
    resets: self.resets,
    steps: self.steps,
    completed_queries: self.completed_queries,
    cache_nodes: self.nodes.length(),
    output_code_units: self.output_code_units,
  }
}

///|
pub fn Experiment::alphabet(self : Experiment) -> Array[String] {
  self.alphabet.copy()
}

///|
/// Query one word. Every physical execution starts with reset and ends with close.
/// Bypass forces a new observation, checked against every previously observed prefix.
pub fn Experiment::query(
  self : Experiment,
  requested_word : Array[String],
  bypass_cache~ : Bool = false,
) -> Array[String] raise {
  if self.in_flight {
    raise InvalidArgument("reentrant experiment query")
  }
  self.in_flight = true
  defer {
    self.in_flight = false
  }
  if self.conflict is Some((word, expected, actual)) {
    raise InconsistentObservation(
      word=word.copy(),
      expected=expected.copy(),
      actual=actual.copy(),
    )
  }
  if requested_word.length() > self.max_word_length {
    raise LimitExceeded("word-length")
  }
  let word = requested_word.copy()
  for input in word {
    if !self.alphabet.contains(input) {
      raise UnknownInput(input)
    }
  }
  if self.queries == 2147483647 {
    raise LimitExceeded("logical-queries")
  }
  self.queries += 1
  let cached = []
  let mut node = 0
  for input in word {
    match self.nodes[node].children.get(input) {
      Some(next) => {
        node = next
        cached.push(self.nodes[node].output.unwrap())
      }
      None => break
    }
  }
  let force = bypass_cache ||
    (self.recheck_every > 0 && self.queries % self.recheck_every == 0)
  if self.use_cache && !force && cached.length() == word.length() {
    self.cache_hits += 1
    return cached
  }
  if self.resets >= self.max_queries {
    raise LimitExceeded("physical-queries")
  }
  if word.length() > self.max_steps - self.steps {
    raise LimitExceeded("target-steps")
  }
  if word.length() - cached.length() >
    self.max_cache_nodes - self.nodes.length() {
    raise LimitExceeded("cache-nodes")
  }
  let outputs = {
    errdefer ((self.system.close)() catch { _ => () })
    self.resets += 1
    (self.system.reset)()
    let result = []
    for input in word {
      self.steps += 1
      let output = (self.system.step)(input)
      if output.length() > self.max_output_code_units - self.output_code_units {
        raise LimitExceeded("output-code-units")
      }
      self.output_code_units += output.length()
      result.push(output)
    }
    result
  }
  (self.system.close)()
  self.completed_queries += 1
  // Check before inserting, so a conflicting trace cannot partially update the cache.
  for index in 0..<cached.length() {
    if cached[index] != outputs[index] {
      self.conflict = Some(
        (
          word[:index + 1].to_owned(),
          cached[:index + 1].to_owned(),
          outputs[:index + 1].to_owned(),
        ),
      )
      raise InconsistentObservation(
        word=word[:index + 1].to_owned(),
        expected=cached[:index + 1].to_owned(),
        actual=outputs[:index + 1].to_owned(),
      )
    }
  }
  node = 0
  for index, input in word {
    match self.nodes[node].children.get(input) {
      Some(next) => node = next
      None => {
        let next = self.nodes.length()
        self.nodes.push({ children: Map([]), output: Some(outputs[index]), })
        self.nodes[node].children[input] = next
        node = next
      }
    }
  }
  outputs
}

///|
/// Freshly replay a candidate word against both real targets.
/// None means the candidate did not reproduce a difference.
pub fn confirm_difference(
  left : Experiment,
  right : Experiment,
  inputs : Array[String],
) -> Difference? raise {
  let word = inputs.copy()
  let left_outputs = left.query(word, bypass_cache=true)
  let right_outputs = right.query(word, bypass_cache=true)
  if left_outputs == right_outputs {
    None
  } else {
    Some({ inputs: word, left_outputs, right_outputs, })
  }
}
