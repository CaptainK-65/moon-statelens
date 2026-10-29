///|
fn main raise {
  let alphabet = ["acquire", "release"]
  let baseline = @lens.learn(
    @lens.Experiment::new(@limit.quota_system(2), alphabet),
    @lens.Oracle::wp_method(3),
  ).model.unwrap()
  let cold = @lens.learn_with(
    @lens.Experiment::new(@limit.quota_system(3), alphabet),
    @lens.Oracle::wp_method(4),
    LStar,
  )
  let guided = @lens.learn_with(
    @lens.Experiment::new(@limit.quota_system(3), alphabet),
    @lens.Oracle::wp_method(4),
    LStar,
    seed=baseline,
  )
  let token = @lens.learn(
    @lens.Experiment::new(@limit.token_system(), ["request", "tick"]),
    @lens.Oracle::wp_method(3),
  )
  let cache = @lens.learn(
    @lens.Experiment::new(@lru.system(), @lru.alphabet()),
    @lens.Oracle::wp_method(10),
  )
  guard guided.status is Supported(_) &&
    cold.status is Supported(_) &&
    token.status is Supported(_) &&
    cache.status is Supported(_) else {
    fail("actual component inference incomplete")
  }
  assert_true(
    @lens.distinguish(cold.model.unwrap(), guided.model.unwrap()) is None,
  )
  let word = @lens.distinguish(baseline, guided.model.unwrap()).unwrap().inputs
  let confirmation = @lens.confirm_difference(
    @lens.Experiment::new(@limit.quota_system(2), alphabet),
    @lens.Experiment::new(@limit.quota_system(3), alphabet),
    word,
  ).unwrap()
  println(
    Json::object({
      "format": Json("moonstatelens.evolution-demo"),
      "version": Json(1),
      "scope": Json(
        "actual MoonLimit/MoonLarder public APIs; quota configuration 2 to 3, not an upstream defect",
      ),
      "baseline": Json(baseline),
      "cold": Json(cold),
      "guided": Json(guided),
      "token_bucket": Json(token),
      "moonlarder": Json(cache),
      "confirmed_difference": Json(confirmation),
      "junit": Json(
        @lens.regression_junit(
          baseline
          .regression_suite()
          .plan()
          .run(@lens.Experiment::new(@limit.quota_system(3), alphabet)),
        ),
      ),
    }).stringify(),
  )
}
