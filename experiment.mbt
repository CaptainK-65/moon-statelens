///|
/// Immutable counters. Attempts include target calls that fail.
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
/// Synchronous compatibility facade over the IO-independent query session.
pub struct Experiment {
  priv system : System
  priv alphabet : Array[String]
  priv session : QuerySession
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
  {
    system,
    alphabet: alphabet.copy(),
    session: QuerySession::new(
      alphabet,
      max_queries~,
      max_steps~,
      max_word_length~,
      max_cache_nodes~,
      max_output_code_units~,
      use_cache~,
      recheck_every~,
    ),
  }
}

///|
pub fn Experiment::statistics(self : Experiment) -> Statistics {
  self.session.statistics()
}

///|
pub fn Experiment::alphabet(self : Experiment) -> Array[String] {
  self.alphabet.copy()
}

///|
pub fn Experiment::query(
  self : Experiment,
  requested_word : Array[String],
  bypass_cache~ : Bool = false,
) -> Array[String] raise {
  match self.session.start(requested_word, bypass_cache~) {
    Cached(outputs) => outputs
    Execute(request) => {
      defer self.session.abort(request.id)
      {
        errdefer ((self.system.close)() catch { _ => () })
        self.session.reset_started(request.id)
        (self.system.reset)()
        for input in request.inputs {
          self.session.step_started(request.id)
          self.session.accept_output(request.id, (self.system.step)(input))
        }
      }
      (self.system.close)()
      self.session.commit(request.id)
    }
  }
}

///|
/// Freshly replay a candidate word against both real targets.
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
