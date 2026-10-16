///|
test "W-method finds a hidden extra-state defect and learns the complete target" {
  let target = delayed_target(6)
  let result = @lens.learn(
    @lens.Experiment::new(target.system(), target.alphabet()),
    @lens.Oracle::w_method(6, max_tests=50000),
  )
  assert_true(result.status is Supported(ConditionalStateBound(6)))
  assert_true(@lens.distinguish(target, result.model.unwrap()) is None)
  assert_true(result.counterexamples.length() > 0)
}

///|
test "W-method checks outputs of single-state machines" {
  let target = @lens.Machine::new(["x"], [[{ target: 0, output: "yes", }]])
  let result = @lens.learn(
    @lens.Experiment::new(target.system(), ["x"]),
    @lens.Oracle::w_method(1),
  )
  assert_true(result.status is Supported(ConditionalStateBound(1)))
  assert_eq(result.model.unwrap().trace(["x"]), ["yes"])
}

///|
test "truncated conformance suites and insufficient state bounds are explicit" {
  let target = delayed_target(5)
  let limited = @lens.learn(
    @lens.Experiment::new(target.system(), target.alphabet()),
    @lens.Oracle::w_method(5, max_tests=1),
  )
  assert_true(limited.status is Inconclusive("conformance-tests"))
  let wrong_bound = @lens.learn(
    @lens.Experiment::new(sample().system(), ["a", "b"]),
    @lens.Oracle::w_method(1),
  )
  assert_true(
    wrong_bound.status is Inconclusive("state-bound-below-hypothesis"),
  )
}

///|
test "exhaustive and random experiments report their limited evidence" {
  let target = sample()
  let exhaustive = @lens.learn(
    @lens.Experiment::new(target.system(), target.alphabet()),
    @lens.Oracle::exhaustive(4),
  )
  assert_true(exhaustive.status is Supported(Budgeted(_)))
  let random = @lens.learn(
    @lens.Experiment::new(target.system(), target.alphabet()),
    @lens.Oracle::random_words(seed=42, tests=100),
  )
  assert_true(random.status is Supported(Budgeted(_)))
  assert_true(@lens.distinguish(target, random.model.unwrap()) is None)
  let exhausted = @lens.learn(
    @lens.Experiment::new(target.system(), target.alphabet()),
    @lens.Oracle::exhaustive(12, max_tests=1),
  )
  assert_true(exhausted.status is Inconclusive("conformance-tests"))
}

///|
test "minimization merges equivalent states removes unreachable states and normalizes initial state" {
  let model = @lens.Machine::new(
    ["x"],
    [
      [{ target: 0, output: "unused", }],
      [{ target: 2, output: "ok", }],
      [{ target: 1, output: "ok", }],
    ],
    initial=2,
  )
  let reduced = model.minimize()
  assert_eq(reduced.state_count(), 1)
  assert_eq(reduced.initial_state(), 0)
  assert_true(@lens.distinguish(model, reduced) is None)
  assert_eq(reduced.characterizing_set(), [[]])
}
