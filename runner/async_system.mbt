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
) -> AsyncExperiment raise {
  if query_timeout_ms < 1 || step_timeout_ms < 1 || cleanup_timeout_ms < 1 {
    raise Configuration("timeouts must be positive")
  }
  {
    system,
    query_timeout_ms,
    step_timeout_ms,
    cleanup_timeout_ms,
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
    Cached(outputs) => outputs
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
      self.session.commit(request.id)
    }
  }
}
