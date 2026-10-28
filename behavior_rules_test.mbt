///|
fn logout_rule() -> @lens.BehaviorRule raise {
  @lens.BehaviorRule::new(
    "logout-isolation",
    { input: "request", output: "allowed", },
    kind="until",
    trigger={ input: "logout", output: "ok", },
    release={ input: "login", output: "ok", },
  )
}

///|
test "finite rules use successful events and release only after successful login" {
  let rule = logout_rule()
  assert_eq(
    rule.check_trace(["logout", "login", "request"], ["ok", "failed", "allowed"]),
    Some(2),
  )
  assert_eq(
    rule.check_trace(["logout", "login", "request"], ["ok", "ok", "allowed"]),
    None,
  )
  assert_eq(
    rule.check_trace(["logout", "request"], ["failed", "allowed"]),
    None,
  )
  assert_eq(Json(@lens.BehaviorRule::from_json(Json(rule))), Json(rule))
  let always = @lens.BehaviorRule::new("no-allow", {
    input: "request",
    output: "allowed",
  })
  assert_eq(always.check_trace(["request"], ["allowed"]), Some(0))
  let after = @lens.BehaviorRule::new(
    "no-reopen",
    { input: "request", output: "allowed", },
    kind="after",
    trigger={ input: "logout", output: "ok", },
  )
  assert_eq(
    after.check_trace(["logout", "login", "request"], ["ok", "ok", "allowed"]),
    Some(2),
  )
}

///|
test "rule finds defects shared by both versions and refuses spurious predictions" {
  let alphabet = ["login", "logout", "request"]
  let bad = @lens.Machine::new(alphabet, [
    [
      { target: 0, output: "ok", },
      { target: 0, output: "ok", },
      { target: 0, output: "allowed", },
    ],
  ])
  let good = @lens.Machine::new(alphabet, [
    [
      { target: 0, output: "ok", },
      { target: 0, output: "ok", },
      { target: 0, output: "denied", },
    ],
  ])
  assert_true(@lens.distinguish(bad, bad) is None)
  let rule = logout_rule()
  let prediction = rule.search(bad)
  assert_eq(prediction.witness, Some(["logout", "request"]))
  guard rule.verify(bad, @lens.Experiment::new(bad.system(), alphabet))
    is { "status": "confirmed-violation", "violation_position": 1, .. } else {
    fail("shared defect")
  }
  guard rule.verify(bad, @lens.Experiment::new(good.system(), alphabet))
    is { "status": "not-reproduced", .. } else {
    fail("model prediction must be checked")
  }
  let limited = rule.search(bad, max_pairs=1)
  assert_false(limited.search_complete)
  assert_true(limited.witness is None)
  let missing = rule.search(good)
  assert_true(missing.search_complete)
  assert_true(missing.witness is None)
}

///|
test "multi-context diagnosis handles renamed states, alphabet order and explicit truncation" {
  let left = @lens.Machine::new(["a", "b"], [
    [{ target: 1, output: "x", }, { target: 0, output: "y", }],
    [{ target: 0, output: "z", }, { target: 1, output: "y", }],
  ])
  let renamed = @lens.Machine::new(
    ["b", "a"],
    [
      [{ target: 0, output: "y", }, { target: 1, output: "z", }],
      [{ target: 1, output: "y", }, { target: 0, output: "x", }],
    ],
    initial=1,
  )
  let equal = @lens.diagnose_models(left, renamed)
  assert_true(equal.complete)
  assert_true(equal.differences.is_empty())
  let rows = left.table()
  rows[0][1] = { target: 0, output: "bad1", }
  rows[1][0] = { target: 0, output: "bad2", }
  let right = @lens.Machine::new(left.alphabet(), rows)
  let diagnosis = @lens.diagnose_models(left, right)
  assert_true(diagnosis.complete)
  assert_eq(diagnosis.differences.length(), 2)
  for diff in diagnosis.differences {
    assert_true(diff.left_outputs != diff.right_outputs)
  }
  assert_false(@lens.diagnose_models(left, right, max_findings=1).complete)
  assert_false(@lens.diagnose_models(left, right, max_pairs=1).complete)
  assert_false(@lens.diagnose_models(left, right, max_edges=1).complete)
}
