///|
fn parse_http_action(value : Json) -> @external.HttpAction raise {
  let object = fields(value, [
    "path", "verb", "body", "output_field", "expect_status",
  ])
  let path = text(object, "path")
  let verb = text(object, "verb", default="POST")
  if !path.has_prefix("/") ||
    !["GET", "POST", "PUT", "DELETE", "PATCH"].contains(verb) {
    raise @runner.Configuration("invalid HTTP action path or verb")
  }
  let status = integer(object, "expect_status", 200, max=599)
  if status > 0 && status < 100 {
    raise @runner.Configuration("invalid HTTP status")
  }
  {
    path,
    verb,
    body: object.get("body").unwrap_or(Json::null()),
    output_field: text(object, "output_field", default="output"),
    expect_status: status,
  }
}

///|
async fn[T] Config::with_target(
  self : Config,
  action : async (@runner.AsyncSystem) -> T,
) -> T {
  match self.kind {
    "jsonl" => {
      let program = text(self.target, "program")
      let args = array_strings(
        self.target.get("args").unwrap_or(Json::array([])),
      )
      @external.with_jsonl(
        program,
        args,
        action,
        max_frame_bytes=integer(
          self.target,
          "max_frame_bytes",
          1048576,
          min=64,
          max=16777216,
        ),
        max_stderr_bytes=integer(
          self.target,
          "max_stderr_bytes",
          65536,
          max=16777216,
        ),
      )
    }
    "sqlite" => {
      let mutant = match self.target.get("rollback_as_commit") {
        None | Some(False) => false
        Some(True) => true
        _ => raise @runner.Configuration("expected boolean rollback_as_commit")
      }
      @external.with_sqlite(
        text(self.target, "program", default="sqlite3"),
        action,
        rollback_as_commit=mutant,
      )
    }
    "http" => {
      guard required(self.target, "actions") is Object(entries) else {
        raise @runner.Configuration("HTTP actions must be an object")
      }
      let mappings = Map([])
      for (input, value) in entries {
        if !self.alphabet.contains(input) {
          raise @runner.Configuration("HTTP action outside alphabet")
        }
        mappings[input] = parse_http_action(value)
      }
      if mappings.length() != self.alphabet.length() {
        raise @runner.Configuration("HTTP action missing from alphabet")
      }
      let system = @external.http_system(
        text(self.target, "base_url"),
        parse_http_action(required(self.target, "reset")),
        mappings,
        parse_http_action(required(self.target, "close")),
        session_field=text(self.target, "session_field"),
        session_header=text(
          self.target,
          "session_header",
          default="X-MoonStateLens-Session",
        ),
        max_response_bytes=integer(
          self.target,
          "max_response_bytes",
          1048576,
          min=1,
          max=16777216,
        ),
      )
      action(system)
    }
    "model" => {
      let model = @lens.Machine::from_json(required(self.target, "model"))
      if model.alphabet() != self.alphabet {
        raise @runner.Configuration("model alphabet order mismatch")
      }
      let state = [model.initial_state()]
      let table = model.table()
      let system = @runner.AsyncSystem::new(
        reset=() => {
          @async.pause()
          state[0] = model.initial_state()
        },
        step=input => {
          @async.pause()
          let edge = table[state[0]][self.alphabet.search(input).unwrap()]
          state[0] = edge.target
          edge.output
        },
        close=() => @async.pause(),
      )
      action(system)
    }
    _ => raise @runner.Configuration("unsupported target")
  }
}

///|
fn Config::experiment(
  self : Config,
  system : @runner.AsyncSystem,
) -> @runner.AsyncExperiment raise {
  let b = self.budgets
  @runner.AsyncExperiment::new(
    system,
    self.alphabet,
    max_queries=b.queries,
    max_steps=b.steps,
    max_word_length=b.word_length,
    max_cache_nodes=b.cache_nodes,
    max_output_code_units=b.output_code_units,
    query_timeout_ms=b.query_timeout_ms,
    step_timeout_ms=b.step_timeout_ms,
    cleanup_timeout_ms=b.cleanup_timeout_ms,
    trace_limit=if self.artifacts.contains("traces") { 10000 } else { 0 },
  )
}

///|
async fn Config::infer(
  self : Config,
  experiment : @runner.AsyncExperiment,
  plan : @lens.VerificationPlan,
) -> @runner.InferenceReport {
  let b = self.budgets
  @runner.infer(
    experiment,
    plan,
    algorithm=self.algorithm,
    max_states=b.states,
    max_rounds=b.rounds,
    max_table_cells=b.table_cells,
    max_table_symbols=b.table_symbols,
    max_prefixes=b.prefixes,
  )
}
