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
