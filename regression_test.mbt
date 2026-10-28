///|
fn suite_model() -> @lens.Machine raise {
  @lens.Machine::new(["a", "b"], [
    [{ target: 1, output: "0", }, { target: 0, output: "0", }],
    [{ target: 0, output: "1", }, { target: 1, output: "0", }],
  ])
}

///|
test "suite export is recomputed on import and rejects changed assertions or evidence" {
  let suite = suite_model().regression_suite(state_bound=3)
  let document = Json(suite)
  assert_eq(Json(@lens.RegressionSuite::from_json(document)), document)
  let changed = @json.parse(document.stringify())
  guard changed is Object(object) &&
    object["cases"] is Array(cases) &&
    cases[1] is Object(c) else {
    fail("suite document")
  }
  c["expected"] = Json(["forged"])
  let rejected = try {
    ignore(@lens.RegressionSuite::from_json(changed))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let partial = suite_model().regression_suite(state_bound=3, max_candidates=1)
  assert_false(partial.is_complete())
  assert_false(
    partial
    .plan()
    .run(@lens.Experiment::new(suite_model().system(), ["a", "b"]))
    is { "passed": True, .. },
  )
}

///|
test "prefix sharing preserves all positions and independent fresh stability probes" {
  let model = suite_model()
  for profile in ["state", "transition", "w", "wp"] {
    let suite = model.regression_suite(profile~, state_bound=3)
    assert_true(suite.is_complete())
    if profile == "w" || profile == "wp" || profile == "transition" {
      guard suite.coverage()
        is { "states_visited": 2, "transitions_visited": 4, .. } else {
        fail("full reachable model coverage")
      }
    }
    let compact = suite.plan()
    assert_true(compact.validate())
    let normal = @lens.Experiment::new(model.system(), model.alphabet())
    let report = compact.run(normal, stability_rechecks=2)
    guard report
      is { "passed": True, "failed_cases": 0, "pending_cases": 0, .. } else {
      fail("suite execution")
    }
    assert_eq(normal.statistics().resets, compact.words().length() * 3)
    let raw = @lens.Experiment::new(model.system(), model.alphabet())
    let raw_report = suite.plan(compact=false).run(raw, stability_rechecks=2)
    guard raw_report is { "passed": True, .. } else { fail("raw execution") }
    assert_true(normal.statistics().resets <= raw.statistics().resets)
  }
  let suite = model.regression_suite(profile="transition")
  guard suite.coverage()
    is { "states_visited": 2, "transitions_visited": 4, .. } else {
    fail("coverage")
  }
}

///|
test "import rejects forged completion and copies remain isolated" {
  let suite = suite_model().regression_suite(state_bound=3, max_candidates=1)
  let document = Json(suite)
  guard document is Object(fields) && fields["evidence"] is Object(evidence) else {
    fail("document")
  }
  evidence["generation_complete"] = Json(true)
  try @lens.RegressionSuite::from_json(document) catch {
    @lens.InvalidArgument(_) => ()
    error => raise error
  } noraise {
    _ => fail("accepted forged completion")
  }
  let full = suite_model().regression_suite()
  let cases = full.cases()
  cases[0].inputs.push("not-in-alphabet")
  assert_true(full.plan().validate())
  let words = full.plan().words()
  words[0].push("not-in-alphabet")
  assert_true(full.plan().validate())
}

///|
test "suite runner reports first failure positions and never accepts truncated runs" {
  let model = suite_model()
  let rows = model.table()
  rows[1][0] = { target: 0, output: "bad", }
  let mutant = @lens.Machine::new(model.alphabet(), rows)
  let plan = model.regression_suite(state_bound=2).plan()
  let failed = plan.run(
    @lens.Experiment::new(mutant.system(), mutant.alphabet()),
  )
  guard failed
    is {
      "execution_complete": True,
      "passed": False,
      "failed_cases": Number(n, ..),
      ..
    } &&
    n > 0 else {
    fail("mutation detection")
  }
  let limited = plan.run(
    @lens.Experiment::new(model.system(), model.alphabet(), max_queries=1),
  )
  guard limited
    is {
      "execution_complete": False,
      "passed": False,
      "pending_cases": Number(n, ..),
      ..
    } &&
    n > 0 else {
    fail("budget must be incomplete")
  }
  let execution = plan.execution()
  let word = execution.next_word().unwrap()
  execution.observe(model.trace(word))
  execution.observe(word.map(_ => "unstable"))
  guard execution.report() is { "unstable": True, "passed": False, .. } else {
    fail("fresh recheck")
  }
}
