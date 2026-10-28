///|
fn regression_target(states : Int32, salt : Int32) -> @lens.Machine raise {
  @lens.Machine::new(
    ["advance", "probe"],
    Array::makei(states, state => {
      [
        {
          target: (state + 1) % states,
          output: if salt % 3 == 2 && state == states - 1 {
            "cycle-marker-\{salt}"
          } else {
            "tick-\{salt}"
          },
        },
        {
          target: if salt % 2 == 0 {
            0
          } else {
            (state * 3 + salt) % states
          },
          output: if salt % 3 == 0 {
            "state-\{salt}-\{state}"
          } else if salt % 3 == 1 {
            if state == states - 1 {
              "hit-\{salt}"
            } else {
              "miss-\{salt}"
            }
          } else {
            "group-\{salt}-\{state % 3}"
          },
        },
      ]
    }),
  )
}

///|
fn run_suite(
  suite : @lens.RegressionSuite,
  target : @lens.Machine,
  compact : Bool,
) -> (Json, @lens.Statistics) raise {
  let experiment = @lens.Experiment::new(
    target.system(),
    target.alphabet(),
    max_queries=1000000,
    max_steps=20000000,
  )
  let report = suite.plan(compact~).run(experiment)
  (report, experiment.statistics())
}

///|
fn report_failures(report : Json) -> Array[Json] raise {
  guard report is { "execution_complete": True, "cases": Array(cases), .. } else {
    fail("study suite did not complete")
  }
  cases
  .filter(c => c is { "status": "failed", .. })
  .map(c => {
    guard c is { "case": id, "actual": actual, "first_mismatch": mismatch, .. } else {
      fail("case result")
    }
    Json::object({ "case": id, "actual": actual, "first_mismatch": mismatch })
  })
}

///|
/// Fixed finite mutation corpus. Equivalent mutants are independently classified
/// using exact explicit-model comparison; incomplete comparisons are failures.
pub fn regression_study() -> Json raise {
  let records = []
  let reductions = []
  let mut mutants = 0
  let mut equivalent = 0
  let mut killed = 0
  let mut preserved = 0
  let mut false_positives = 0
  for states in 2..<=6 {
    for salt in 0..<6 {
      let base = regression_target(states, salt)
      assert_eq(base.minimize().state_count(), states)
      for profile in ["w", "wp"] {
        let suite = base.regression_suite(profile~, state_bound=states)
        if !suite.is_complete() || !suite.plan().validate() {
          fail("study certificate/generation")
        }
        let cases = suite.cases().length()
        guard suite.coverage()
          is {
            "states_visited": Number(s, ..),
            "transitions_visited": Number(t, ..),
            ..
          } &&
          s == states.to_double() &&
          t == (states * 2).to_double() else {
          fail("incomplete model coverage")
        }
        preserved += cases
        let (raw, raw_stats) = run_suite(suite, base, false)
        let (compact, compact_stats) = run_suite(suite, base, true)
        if !(raw is { "passed": True, .. }) ||
          !(compact is { "passed": True, .. }) {
          false_positives += 1
        }
        let reduction = 1.0 -
          compact_stats.resets.to_double() / raw_stats.resets.to_double()
        reductions.push(reduction)
        records.push(
          Json::object({
            "states": Json(states),
            "salt": Json(salt),
            "profile": Json(profile),
            "original_cases": Json(cases),
            "compact_words": Json(suite.plan().words().length()),
            "raw_statistics": Json(raw_stats),
            "compact_statistics": Json(compact_stats),
            "reset_reduction": Json(reduction),
            "coverage": suite.coverage(),
          }),
        )
      }
      let suite = base.regression_suite(profile="wp", state_bound=states)
      let renamed = @lens.Machine::new(
        base.alphabet(),
        Array::makei(states, i => {
          base.table()[states - 1 - i].map(e => {
            target: states - 1 - e.target,
            output: e.output,
          })
        }),
        initial=states - 1,
      )
      if !@lens.diagnose_models(base, renamed).differences.is_empty() {
        fail("state renumbering false positive")
      }
      let (same, _) = run_suite(suite, renamed, true)
      if !(same is { "passed": True, .. }) {
        false_positives += 1
      }
      fn mutant(rows : Array[Array[@lens.Transition]]) -> Unit raise {
        let changed = @lens.Machine::new(base.alphabet(), rows)
        if @lens.distinguish(base, changed) is None {
          equivalent += 1
          return
        }
        mutants += 1
        let (raw, _) = run_suite(suite, changed, false)
        let (compact, _) = run_suite(suite, changed, true)
        let rf = report_failures(raw)
        let cf = report_failures(compact)
        if rf.is_empty() || rf != cf {
          fail("mutant escaped or original assertion outcomes changed")
        }
        killed += 1
      }
      for state in 0..<states {
        for column in 0..<2 {
          let rows = base.table()
          let edge = rows[state][column]
          rows[state][column] = {
            target: edge.target,
            output: "controlled-mutation",
          }
          mutant(rows)
          for destination in 0..<states {
            if destination == edge.target {
              continue
            }
            let rows = base.table()
            rows[state][column] = { target: destination, output: edge.output, }
            mutant(rows)
          }
        }
      }
    }
  }
  reductions.sort()
  let median = (
      reductions[reductions.length() / 2 - 1] +
      reductions[reductions.length() / 2]
    ) /
    2.0
  if mutants < 1000 || killed != mutants || false_positives != 0 {
    fail("mutation correctness gate")
  }
  Json::object({
    "format": Json("moonstatelens.regression-study"),
    "version": Json(1),
    "scope": Json(
      "fixed 30 minimal 2..6-state deterministic models: direct observation, delayed probe, grouped cycle outputs; W/Wp at m=n; complete runs with one fresh recheck per word; no universal speed/detection claim",
    ),
    "non_equivalent_mutants": Json(mutants),
    "equivalent_mutants_excluded": Json(equivalent),
    "mutants_killed": Json(killed),
    "identical_original_case_failures": Json(killed == mutants),
    "false_positives_on_baselines": Json(false_positives),
    "certified_original_cases": Json(preserved),
    "state_renumbered_equivalents": Json(30),
    "median_reset_reduction": Json(median),
    "cases": Json(records),
  })
}

///|
/// Explicit prefix-nested family, reported separately from the mixed corpus.
pub fn prefix_study() -> Json raise {
  let cases = []
  for count in [8, 16, 32, 64] {
    let model = @lens.Machine::new(
      ["advance"],
      Array::makei(count, state => {
        [
          {
            target: (state + 1) % count,
            output: if state == count - 1 {
              "hit"
            } else {
              "tick"
            },
          },
        ]
      }),
    )
    let suite = model.regression_suite(profile="state")
    let (raw, rs) = run_suite(suite, model, false)
    let (compact, cs) = run_suite(suite, model, true)
    guard raw is { "passed": True, .. } && compact is { "passed": True, .. } else {
      fail("prefix study")
    }
    cases.push(
      Json::object({
        "states": Json(count),
        "raw_resets": Json(rs.resets),
        "compact_resets": Json(cs.resets),
        "reset_reduction": Json(
          1.0 - cs.resets.to_double() / rs.resets.to_double(),
        ),
        "coverage": suite.coverage(),
      }),
    )
  }
  Json::object({
    "format": Json("moonstatelens.prefix-study"),
    "version": Json(1),
    "scope": Json(
      "state-cover suites on deliberately nested access paths; not W/Wp completeness or a representative workload",
    ),
    "cases": Json(cases),
  })
}
