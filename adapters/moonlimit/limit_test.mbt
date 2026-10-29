///|
test "actual limiter public API infers quota and replenishment models" {
  for
    (alphabet, system, bound) in [
      (["acquire", "release"], @moonlimit.quota_system(2), 3),
      (["request", "tick"], @moonlimit.token_system(), 3),
    ] {
    let result = @lens.learn(
      @lens.Experiment::new(system, alphabet),
      @lens.Oracle::wp_method(bound),
    )
    assert_true(result.status is Supported(ConditionalStateBound(3)))
    assert_eq(result.model.unwrap().state_count(), 3)
  }
}
