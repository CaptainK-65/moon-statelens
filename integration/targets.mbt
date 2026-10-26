///|
async fn[T] Config::with_target(
  self : Config,
  action : async (@runner.AsyncSystem) -> T,
) -> T {
  match self.target {
    Jsonl(program, args, frame, stderr) =>
      @external.with_jsonl(
        program,
        args,
        action,
        max_frame_bytes=frame,
        max_stderr_bytes=stderr,
      )
    Sqlite(program, mutant) =>
      @external.with_sqlite(program, action, rollback_as_commit=mutant)
    Http(url, reset, actions, close, field, header, limit) =>
      action(
        @external.http_system(
          url,
          reset,
          actions,
          close,
          session_field=field,
          session_header=header,
          max_response_bytes=limit,
        ),
      )
    Model(model) => {
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
