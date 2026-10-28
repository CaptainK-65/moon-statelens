///|
fn session_result() -> @lens.LearningResult raise {
  @lens.learn(
    @lens.Experiment::new(
      @targets.session_system(),
      @targets.session_alphabet(),
    ),
    @lens.Oracle::w_method(2),
  )
}

///|
fn lru_result() -> @lens.LearningResult raise {
  @lens.learn(
    @lens.Experiment::new(
      @lru.system(),
      @lru.alphabet(),
      max_queries=200000,
      max_steps=5000000,
    ),
    @lens.Oracle::w_method(10),
  )
}

///|
fn regression_result() -> @lens.CompatibilityResult raise {
  let alphabet = @targets.session_alphabet()
  @lens.compare(
    @lens.Experiment::new(@targets.session_system(), alphabet),
    @lens.Experiment::new(@targets.session_system(buggy=true), alphabet),
    @lens.Oracle::w_method(2),
    @lens.Oracle::w_method(2),
  )
}

///|
/// Learn via public MoonLarder API, serialize the suite, then run it against a
/// fresh real library adapter. The inference never reads private LRU state.
fn lru_gate() -> Json raise {
  let learned = lru_result()
  guard learned.model is Some(model) && learned.status is Supported(_) else {
    fail("MoonLarder baseline learning did not complete")
  }
  let suite = @lens.RegressionSuite::from_json(
    Json(model.regression_suite(state_bound=10)),
  )
  let report = suite
    .plan()
    .run(
      @lens.Experiment::new(
        @lru.system(),
        @lru.alphabet(),
        max_queries=200000,
        max_steps=5000000,
      ),
    )
  guard report is { "passed": True, .. } else {
    fail("saved suite failed against real MoonLarder")
  }
  Json::object({
    "format": Json("moonstatelens.moonlarder-gate"),
    "version": Json(1),
    "scope": Json(
      "real jhshuai/moonlarder public API; capacity 2, three keys, no TTL; model learned before suite generation",
    ),
    "learning": Json(learned),
    "regression": report,
  })
}
