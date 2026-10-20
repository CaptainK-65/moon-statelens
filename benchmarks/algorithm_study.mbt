///|
/// Reproducible costs under identical Wp plans. Counts are observations, not a
/// claim that either algorithm is universally faster.
pub fn algorithm_study() -> Json raise {
  let cases = []
  for count in [2, 4, 7] {
    let rows : Array[Array[@lens.Transition]] = Array::makei(count, state => {
      [
        { target: (state + 1) % count, output: "tick", },
        { target: 0, output: if state == count - 1 { "yes" } else { "no" }, },
      ]
    })
    let target = @lens.Machine::new(["advance", "probe"], rows)
    for algorithm in [@lens.Algorithm::LStar, @lens.Algorithm::KearnsVazirani] {
      let experiment = @lens.Experiment::new(target.system(), target.alphabet())
      let verification_counts = [0, 0]
      let inner = @lens.Oracle::wp_method(count, max_tests=100000)
      let oracle = @lens.Oracle::new((model, experiment) => {
        let before = experiment.statistics()
        let decision = inner.evaluate(model, experiment)
        let after = experiment.statistics()
        verification_counts[0] += after.resets - before.resets
        verification_counts[1] += after.steps - before.steps
        decision
      })
      let learned = @lens.learn_with(experiment, oracle, algorithm)
      guard learned.status is Supported(ConditionalStateBound(_)) &&
        learned.model is Some(model) &&
        @lens.distinguish(target, model) is None else {
        fail("benchmark learner did not complete correctly")
      }
      cases.push(
        Json::object({
          "target": Json("delayed-probe"),
          "states": Json(count),
          "algorithm": Json(algorithm.name()),
          "oracle": Json("wp"),
          "statistics": Json(learned.statistics),
          "verification_resets": Json(verification_counts[0]),
          "verification_steps": Json(verification_counts[1]),
          "rounds": Json(learned.rounds.length()),
          "correct": Json(true),
        }),
      )
    }
  }
  Json::object({
    "format": Json("moonstatelens.algorithm-study"),
    "version": Json(1),
    "scope": Json(
      "fixed deterministic targets; same Wp budgets; no universal speed claim",
    ),
    "cases": Json(cases),
  })
}
