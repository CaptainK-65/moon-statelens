///|
/// Asynchronous reset/step/cleanup callbacks. IO may suspend; operations within
/// one target session are still strictly sequential.
pub struct AsyncSystem {
  priv reset : async () -> Unit
  priv step : async (String) -> String
  priv close : async () -> Unit
}

///|
pub fn AsyncSystem::new(
  reset~ : async () -> Unit,
  step~ : async (String) -> String,
  close~ : async () -> Unit,
) -> AsyncSystem {
  { reset, step, close, }
}

///|
pub(all) suberror AdapterError {
  Protocol(String)
  Target(String)
  TimedOut(String)
  Configuration(String)
  Transport(String)
} derive(Debug)

///|
pub extend AdapterError with @debug.Debug::{to_repr}

///|
pub struct AsyncExperiment {
  priv system : AsyncSystem
  priv session : @lens.QuerySession
  priv query_timeout_ms : Int32
  priv step_timeout_ms : Int32
  priv cleanup_timeout_ms : Int32
  priv traces : Array[Json]
  priv trace_limit : Int32
  priv mut trace_units : Int32
  priv mut trace_truncated : Bool
}

///|
pub fn AsyncExperiment::new(
  system : AsyncSystem,
  alphabet : Array[String],
  max_queries~ : Int32 = 100000,
  max_steps~ : Int32 = 2000000,
  max_word_length~ : Int32 = 4096,
  max_cache_nodes~ : Int32 = 1000000,
  max_output_code_units~ : Int32 = 16777216,
  use_cache~ : Bool = true,
  recheck_every~ : Int32 = 0,
  query_timeout_ms~ : Int32 = 30000,
  step_timeout_ms~ : Int32 = 3000,
  cleanup_timeout_ms~ : Int32 = 1000,
  trace_limit~ : Int32 = 0,
) -> AsyncExperiment raise {
  if query_timeout_ms < 1 ||
    step_timeout_ms < 1 ||
    cleanup_timeout_ms < 1 ||
    trace_limit < 0 ||
    trace_limit > 100000 {
    raise Configuration("timeouts must be positive")
  }
  {
    system,
    query_timeout_ms,
    step_timeout_ms,
    cleanup_timeout_ms,
    traces: [],
    trace_limit,
    trace_units: 0,
    trace_truncated: false,
    session: @lens.QuerySession::new(
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
pub fn AsyncExperiment::statistics(self : AsyncExperiment) -> @lens.Statistics {
  self.session.statistics()
}

///|
pub fn AsyncExperiment::alphabet(self : AsyncExperiment) -> Array[String] {
  self.session.alphabet()
}

///|
fn AsyncExperiment::record(
  self : AsyncExperiment,
  inputs : Array[String],
  outputs : Array[String],
  cached : Bool,
) -> Unit {
  if self.trace_limit == 0 {
    return
  }
  let entry = Json::object({
    "sequence": Json(self.statistics().queries),
    "inputs": Json(inputs.copy()),
    "outputs": Json(outputs.copy()),
    "cached": Json(cached),
  })
  let units = entry.stringify().length()
  if self.traces.length() >= self.trace_limit ||
    units > 2000000 - self.trace_units {
    self.trace_truncated = true
    return
  }
  self.trace_units += units
  self.traces.push(entry)
}

///|
/// Successful logical query traces only; failures remain errors, not observations.
/// Logging is bounded and explicitly reports truncation.
pub fn AsyncExperiment::traces_json(self : AsyncExperiment) -> Json {
  Json::object({
    "format": Json("moonstatelens.traces"),
    "version": Json(1),
    "enabled": Json(self.trace_limit > 0),
    "truncated": Json(self.trace_truncated),
    "scope": Json("successful logical queries, including cache hits"),
    "entries": Json(self.traces.copy()),
  })
}

///|
async fn AsyncExperiment::cleanup(self : AsyncExperiment) -> Unit {
  @async.protect_from_cancel(() => {
    @async.with_timeout(
      self.cleanup_timeout_ms,
      () => (self.system.close)(),
      error=TimedOut("cleanup"),
    )
  })
}

///|
/// Target errors keep priority over cleanup errors. Cancellation always attempts
/// bounded protected cleanup. Only successfully cleaned complete traces commit.
pub async fn AsyncExperiment::query(
  self : AsyncExperiment,
  word : Array[String],
  bypass_cache~ : Bool = false,
) -> Array[String] {
  match self.session.start(word, bypass_cache~) {
    Cached(outputs) => {
      self.record(word, outputs, true)
      outputs
    }
    Execute(request) => {
      defer self.session.abort(request.id)
      @async.with_timeout(
        self.query_timeout_ms,
        () => {
          {
            errdefer (self.cleanup() catch { _ => () })
            self.session.reset_started(request.id)
            @async.with_timeout(
              self.step_timeout_ms,
              () => (self.system.reset)(),
              error=TimedOut("reset"),
            )
            for input in request.inputs {
              self.session.step_started(request.id)
              let output = @async.with_timeout(
                self.step_timeout_ms,
                () => (self.system.step)(input),
                error=TimedOut("step"),
              )
              self.session.accept_output(request.id, output)
            }
          }
          self.cleanup()
        },
        error=TimedOut("query"),
      )
      let outputs = self.session.commit(request.id)
      self.record(request.inputs, outputs, false)
      outputs
    }
  }
}
