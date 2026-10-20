///|
/// A requested physical query. The runner must reset, execute each input, then
/// clean up successfully before committing. Arrays are defensive copies.
pub(all) struct QueryRequest {
  id : Int32
  inputs : Array[String]
} derive(Debug)

///|
pub(all) enum QueryStart {
  Cached(Array[String])
  Execute(QueryRequest)
} derive(Debug)

///|
pub extend QueryRequest with @debug.Debug::{to_repr}

///|
pub extend QueryStart with @debug.Debug::{to_repr}

///|
priv struct PendingQuery {
  id : Int32
  word : Array[String]
  cached : Array[String]
  outputs : Array[String]
  mut reset_started : Bool
  mut awaiting_output : Bool
}

///|
/// IO-independent cache, budgets and observation consistency. Exactly one
/// outstanding query is allowed. Failed/cancelled work must be aborted.
pub struct QuerySession {
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
  priv mut serial : Int32
  priv mut pending : PendingQuery?
  priv mut conflict : (Array[String], Array[String], Array[String])?
}

///|
pub fn QuerySession::new(
  alphabet : Array[String],
  max_queries~ : Int32 = 100000,
  max_steps~ : Int32 = 2000000,
  max_word_length~ : Int32 = 4096,
  max_cache_nodes~ : Int32 = 1000000,
  max_output_code_units~ : Int32 = 16777216,
  use_cache~ : Bool = true,
  recheck_every~ : Int32 = 0,
) -> QuerySession raise LensError {
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
    serial: 0,
    pending: None,
    conflict: None,
  }
}

///|
pub fn QuerySession::alphabet(self : QuerySession) -> Array[String] {
  self.alphabet.copy()
}

///|
pub fn QuerySession::statistics(self : QuerySession) -> Statistics {
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
pub fn QuerySession::start(
  self : QuerySession,
  requested : Array[String],
  bypass_cache~ : Bool = false,
) -> QueryStart raise LensError {
  if self.pending is Some(_) {
    raise InvalidArgument("reentrant experiment query")
  }
  if self.conflict is Some((word, expected, actual)) {
    raise InconsistentObservation(
      word=word.copy(),
      expected=expected.copy(),
      actual=actual.copy(),
    )
  }
  if requested.length() > self.max_word_length {
    raise LimitExceeded("word-length")
  }
  let word = requested.copy()
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
    return Cached(cached)
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
  if self.serial == 2147483647 {
    raise LimitExceeded("query-identifiers")
  }
  self.serial += 1
  self.pending = Some({
    id: self.serial,
    word,
    cached,
    outputs: [],
    reset_started: false,
    awaiting_output: false,
  })
  Execute({ id: self.serial, inputs: word.copy(), })
}

///|
fn QuerySession::require_pending(
  self : QuerySession,
  id : Int32,
) -> PendingQuery raise LensError {
  guard self.pending is Some(pending) && pending.id == id else {
    raise InvalidArgument("stale or missing query identifier")
  }
  pending
}

///|
/// Record the attempted reset immediately before invoking the target.
pub fn QuerySession::reset_started(
  self : QuerySession,
  id : Int32,
) -> Unit raise LensError {
  let pending = self.require_pending(id)
  if pending.reset_started {
    raise InvalidArgument("duplicate reset")
  }
  self.resets += 1
  pending.reset_started = true
}

///|
/// Record an attempted step before invoking it, including attempts that fail.
pub fn QuerySession::step_started(
  self : QuerySession,
  id : Int32,
) -> Unit raise LensError {
  let pending = self.require_pending(id)
  if !pending.reset_started ||
    pending.awaiting_output ||
    pending.outputs.length() >= pending.word.length() {
    raise InvalidArgument("invalid step lifecycle")
  }
  self.steps += 1
  pending.awaiting_output = true
}

///|
pub fn QuerySession::accept_output(
  self : QuerySession,
  id : Int32,
  output : String,
) -> Unit raise LensError {
  let pending = self.require_pending(id)
  if !pending.awaiting_output {
    raise InvalidArgument("unsolicited step output")
  }
  if output.length() > self.max_output_code_units - self.output_code_units {
    raise LimitExceeded("output-code-units")
  }
  self.output_code_units += output.length()
  pending.outputs.push(output)
  pending.awaiting_output = false
}

///|
/// Commit only AFTER successful target cleanup. Conflicts poison the session.
pub fn QuerySession::commit(
  self : QuerySession,
  id : Int32,
) -> Array[String] raise LensError {
  let pending = self.require_pending(id)
  if !pending.reset_started ||
    pending.awaiting_output ||
    pending.outputs.length() != pending.word.length() {
    raise InvalidArgument("incomplete query")
  }
  self.pending = None
  self.completed_queries += 1
  let word = pending.word
  let outputs = pending.outputs
  for index in 0..<pending.cached.length() {
    if pending.cached[index] != outputs[index] {
      self.conflict = Some(
        (
          word[:index + 1].to_owned(),
          pending.cached[:index + 1].to_owned(),
          outputs[:index + 1].to_owned(),
        ),
      )
      raise InconsistentObservation(
        word=word[:index + 1].to_owned(),
        expected=pending.cached[:index + 1].to_owned(),
        actual=outputs[:index + 1].to_owned(),
      )
    }
  }
  let mut node = 0
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
  outputs.copy()
}

///|
/// Discard an unfinished query. Idempotent after commit/abort for safe defers.
/// A different outstanding request cannot be aborted by an old identifier.
pub fn QuerySession::abort(self : QuerySession, id : Int32) -> Unit {
  if self.pending is Some(pending) && pending.id == id {
    self.pending = None
  }
}
