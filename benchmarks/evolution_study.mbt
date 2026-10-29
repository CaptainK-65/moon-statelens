///|
/// Baselines already exist; their first acquisition is excluded from BOTH
/// upgrade runs. Independent Wp verification and actual physical IO are counted.
pub fn evolution_study() -> Json raise {
  let records = []
  let reductions = []
  for states in 3..<=12 {
    for change in 0..<2 {
      fn model(updated : Bool) -> @lens.Machine raise {
        @lens.Machine::new(
          ["a", "b"],
          Array::makei(states, i => {
            [
              { target: (i + 1) % states, output: "tick", },
              {
                target: 0,
                output: if i == states - 1 {
                  if updated {
                    "changed"
                  } else {
                    "hit"
                  }
                } else if change == 1 && i == 0 {
                  "origin"
                } else {
                  "miss"
                },
              },
            ]
          }),
        )
      }
      let old = model(false)
      let target = model(true)
      let runs = []
      for guided in [false, true] {
        let experiment = @lens.Experiment::new(
          target.system(),
          target.alphabet(),
        )
        let verify = [0, 0]
        let oracle = @lens.Oracle::wp_method(states)
        let measured = @lens.Oracle::new((m, e) => {
          let before = e.statistics()
          let result = oracle.evaluate(m, e)
          let after = e.statistics()
          verify[0] += after.resets - before.resets
          verify[1] += after.steps - before.steps
          result
        })
        let learned = @lens.learn_with(
          experiment,
          measured,
          LStar,
          seed?=if guided { Some(old) } else { None },
        )
        guard learned.status is Supported(ConditionalStateBound(_)) &&
          learned.model is Some(actual) &&
          @lens.distinguish(actual, target) is None else {
          fail("evolution study correctness")
        }
        runs.push(learned.statistics.resets)
        records.push(
          Json::object({
            "states": Json(states),
            "change": Json(change),
            "guided": Json(guided),
            "correct": Json(true),
            "statistics": Json(learned.statistics),
            "verification_resets": Json(verify[0]),
            "verification_steps": Json(verify[1]),
            "rounds": Json(learned.rounds.length()),
            "target": Json(target),
          }),
        )
      }
      reductions.push(1.0 - runs[1].to_double() / runs[0].to_double())
    }
  }
  reductions.sort()
  Json::object({
    "format": Json("moonstatelens.evolution-study"),
    "version": Json(1),
    "pairs": Json(20),
    "scope": Json(
      "fixed delayed-observation cycles, output changes; baseline model already available; all fresh new-version observations, same Wp bounds and cache settings; no universal speed claim",
    ),
    "median_reset_reduction": Json((reductions[9] + reductions[10]) / 2.0),
    "all_pair_reductions": Json(reductions),
    "cases": Json(records),
  })
}
