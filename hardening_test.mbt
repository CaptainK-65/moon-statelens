///|
fn stateless(output : String) -> @lens.Machine raise {
  @lens.Machine::new(["x"], [[{ target: 0, output, }]])
}

///|
test "a conflicting session cannot later return stale cached observations" {
  let epoch = [0]
  let session = @lens.Experiment::new(
    @lens.System::new(reset=() => epoch[0] += 1, step=_ => epoch[0].to_string()),
    ["x"],
  )
  ignore(session.query(["x"]))
  try session.query(["x"], bypass_cache=true) catch {
    @lens.InconsistentObservation(expected~, ..) =>
      expected[0] = "caller mutation"
    error => raise error
  } noraise {
    _ => fail("expected conflict")
  }
  try session.query(["x"]) catch {
    @lens.InconsistentObservation(expected~, actual~, ..) => {
      assert_eq(expected, ["1"])
      assert_eq(actual, ["2"])
    }
    error => raise error
  } noraise {
    _ => fail("poisoned session served cache")
  }
  assert_eq(session.statistics().resets, 2)
}

///|
test "target callbacks cannot mutate the in-flight caller word" {
  let inputs = ["a", "b"]
  let session = @lens.Experiment::new(
    @lens.System::new(reset=() => inputs.clear(), step=input => input),
    ["a", "b"],
  )
  assert_eq(session.query(inputs), ["a", "b"])
  assert_true(inputs.is_empty())
  assert_eq(session.query(["a"]), ["a"])
}

///|
test "reentrant callbacks fail before nesting a second target reset" {
  let cell : Array[@lens.Experiment?] = [None]
  let target = @lens.System::new(reset=() => (), step=_ => {
    expect_invalid(() => ignore(cell[0].unwrap().query(["x"])))
    "ok"
  })
  let session = @lens.Experiment::new(target, ["x"])
  cell[0] = Some(session)
  assert_eq(session.query(["x"]), ["ok"])
  assert_eq(session.statistics().resets, 1)
}

///|
test "output volume limits clean up and do not cache partial traces" {
  let closed = [0]
  let target = @lens.System::new(reset=() => (), step=_ => "x", close=() => {
    closed[0] += 1
  })
  let session = @lens.Experiment::new(target, ["x"], max_output_code_units=1)
  try session.query(["x", "x"]) catch {
    @lens.LimitExceeded(reason) => assert_eq(reason, "output-code-units")
    error => raise error
  } noraise {
    _ => fail("expected output limit")
  }
  assert_eq(closed[0], 1)
  assert_eq(session.statistics().cache_nodes, 1)
  assert_eq(session.statistics().completed_queries, 0)
  assert_eq(session.statistics().output_code_units, 1)
}

///|
suberror CleanupFailure

///|
test "cleanup failure cannot replace the original target exception" {
  let closed = [0]
  let session = @lens.Experiment::new(
    @lens.System::new(reset=() => (), step=_ => raise TargetFailure, close=() => {
      closed[0] += 1
      raise CleanupFailure
    }),
    ["x"],
  )
  try session.query(["x"]) catch {
    TargetFailure => ()
    error => raise error
  } noraise {
    _ => fail("expected original target failure")
  }
  assert_eq(closed[0], 1)
}

///|
test "close failure leaves the session unlocked and does not commit observations" {
  let fail_close = [true]
  let session = @lens.Experiment::new(
    @lens.System::new(reset=() => (), step=_ => "ok", close=() => {
      if fail_close[0] {
        raise CleanupFailure
      }
    }),
    ["x"],
  )
  try session.query(["x"]) catch {
    CleanupFailure => ()
    error => raise error
  } noraise {
    _ => fail("expected close failure")
  }
  assert_eq(session.statistics().completed_queries, 0)
  assert_eq(session.statistics().cache_nodes, 1)
  fail_close[0] = false
  assert_eq(session.query(["x"]), ["ok"])
  assert_eq(session.statistics().resets, 2)
}

///|
test "table output-symbol storage has its own budget" {
  let target = sample()
  let result = @lens.learn(
    @lens.Experiment::new(target.system(), target.alphabet()),
    @lens.Oracle::exact(target),
    max_table_symbols=1,
  )
  assert_true(result.status is Inconclusive("table-symbols"))
  assert_eq(result.statistics.resets, 0)
}

///|
test "confirmation calls are included in compatibility statistics" {
  let alphabet = ["login", "logout", "request"]
  let report = @lens.compare(
    @lens.Experiment::new(session_fixture(false), alphabet),
    @lens.Experiment::new(session_fixture(true), alphabet),
    @lens.Oracle::w_method(2),
    @lens.Oracle::w_method(2),
  )
  assert_true(report.status is ConfirmedDifference(_))
  assert_eq(report.left_statistics.resets, report.left.statistics.resets + 1)
  assert_eq(report.right_statistics.resets, report.right.statistics.resets + 1)
}

///|
test "confirmation budget exhaustion returns inconclusive rather than raising or declaring equivalence" {
  let left = stateless("left")
  let right = stateless("right")
  let report = @lens.compare(
    @lens.Experiment::new(left.system(), ["x"], max_queries=2),
    @lens.Experiment::new(right.system(), ["x"]),
    @lens.Oracle::exact(left),
    @lens.Oracle::exact(right),
  )
  assert_true(report.status is Inconclusive("comparison:physical-queries"))
  assert_eq(report.left_statistics.resets, 2)
  assert_true(report.left_statistics.queries > report.left.statistics.queries)
}

///|
test "reset drift during confirmation records the affected target and conflicting trace" {
  let resets = [0]
  let drifting = @lens.System::new(reset=() => resets[0] += 1, step=_ => {
    if resets[0] > 2 {
      "drift"
    } else {
      "left"
    }
  })
  let left = stateless("left")
  let right = stateless("right")
  let report = @lens.compare(
    @lens.Experiment::new(drifting, ["x"]),
    @lens.Experiment::new(right.system(), ["x"]),
    @lens.Oracle::exact(left),
    @lens.Oracle::exact(right),
  )
  guard report.status is ReplayUnstable(side~, word~, expected~, actual~) else {
    fail("expected replay instability")
  }
  assert_eq(side, "left")
  assert_eq(word, ["x"])
  assert_eq(expected, ["left"])
  assert_eq(actual, ["drift"])
}
