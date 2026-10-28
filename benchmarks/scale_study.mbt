///|
/// Two cycle families: sparse delayed observation and direct state observation.
/// Every generated state is reachable and independently checked to be minimal.
pub fn scale_study() -> Json raise {
  let cases = []
  for count in [8, 16, 24, 32, 48, 64] {
    for seed in 0..<10 {
      let family = if seed % 2 == 0 {
        "delayed-probe"
      } else {
        "cycle-observation"
      }
      let model = @lens.Machine::new(
        ["advance", "probe"],
        Array::makei(count, state => {
          [
            { target: (state + 1) % count, output: "tick", },
            {
              target: if seed % 3 == 0 {
                state
              } else {
                0
              },
              output: if seed % 2 == 0 {
                if state == count - 1 - seed / 2 {
                  "hit"
                } else {
                  "miss"
                }
              } else {
                "s\{state}-\{seed}"
              },
            },
          ]
        }),
      )
      if model.minimize().state_count() != count ||
        model.access_sequences().length() != count {
        fail("scale target not reachable/minimal")
      }
      for algorithm in [@lens.Algorithm::LStar, @lens.Algorithm::KearnsVazirani] {
        let experiment = @lens.Experiment::new(
          model.system(),
          model.alphabet(),
          max_queries=1000000,
          max_steps=20000000,
        )
        let learned = @lens.learn_with(
          experiment,
          @lens.Oracle::exact(model),
          algorithm,
          max_states=128,
          max_rounds=256,
          max_table_cells=2000000,
          max_table_symbols=16000000,
        )
        guard learned.status is Supported(ExactReference) &&
          learned.model is Some(actual) &&
          actual.state_count() == count &&
          @lens.distinguish(actual, model) is None else {
          fail("scale learning gate")
        }
        cases.push(
          Json::object({
            "family": Json(family),
            "seed": Json(seed),
            "minimal_reachable_states": Json(count),
            "algorithm": Json(algorithm.name()),
            "correct": Json(true),
            "statistics": Json(experiment.statistics()),
            "rounds": Json(learned.rounds.length()),
          }),
        )
      }
    }
  }
  Json::object({
    "format": Json("moonstatelens.scale-study"),
    "version": Json(1),
    "scope": Json(
      "60 new minimal reachable deterministic targets, both learners; exact reference oracle for independently checkable scale, not external-target W/Wp cost",
    ),
    "targets": Json(60),
    "learning_runs": Json(cases.length()),
    "max_minimal_reachable_states": Json(64),
    "cases": Json(cases),
  })
}
