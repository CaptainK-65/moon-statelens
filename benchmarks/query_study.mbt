///|
fn delayed(states : Int32) -> @lens.Machine raise {
  let rows : Array[Array[@lens.Transition]] = Array::makei(states, state => {
    [
      { target: (state + 1) % states, output: "tick", },
      { target: 0, output: if state == states - 1 { "yes" } else { "no" }, },
    ]
  })
  @lens.Machine::new(["advance", "probe"], rows)
}

///|
/// Deterministic query-cost study. The baseline validates an already learned
/// model by exhaustive words; it is not a competing learner or timing benchmark.
/// Active counts include inference and W-method experiments, with no exact oracle.
pub fn query_study() -> Json raise {
  let cases : Array[Json] = []
  for states in 2..<=7 {
    let target = delayed(states)
    let active = @lens.Experiment::new(target.system(), target.alphabet())
    let learned = @lens.learn(active, @lens.Oracle::w_method(states))
    guard learned.status is Supported(ConditionalStateBound(_)) else {
      raise @lens.InvalidArgument("study learning did not complete")
    }
    let model = learned.model.unwrap()
    guard @lens.distinguish(model, target) is None else {
      raise @lens.InvalidArgument("study produced an incorrect model")
    }
    let baseline = @lens.Experiment::new(target.system(), target.alphabet())
    let depth = 2 * states - 1
    let check = @lens.Oracle::exhaustive(depth, max_tests=100000).evaluate(
      model, baseline,
    )
    guard check is NoCounterexample(_) else {
      raise @lens.InvalidArgument("study baseline did not complete")
    }
    cases.push(
      Json::object({
        "target_states": Json(states),
        "alphabet_size": Json(2),
        "exhaustive_depth": Json(depth),
        "reference_equivalent": Json(true),
        "active_learning_and_w_method": Json(active.statistics()),
        "exhaustive_validation_of_final_model": Json(baseline.statistics()),
        "learning_rounds": Json(learned.rounds.length()),
      }),
    )
  }
  Json::object({
    "format": Json("moonstatelens.query-study"),
    "version": Json(1),
    "methodology": Json(
      "Active includes inference and W-method queries. Baseline receives the final model and freshly checks all words through the stated depth. This is a cost reference, not a like-for-like learner speedup claim.",
    ),
    "cases": Json(cases),
  })
}
