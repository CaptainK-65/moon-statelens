///|
test "prefix observations are reused and can be freshly rechecked" {
  let session = @lens.Experiment::new(sample().system(), ["a", "b"])
  let observed = session.query(["a", "b"])
  observed[0] = "mutated"
  assert_eq(session.query(["a"]), ["0"])
  assert_eq(session.statistics().resets, 1)
  assert_eq(session.statistics().cache_hits, 1)
  assert_eq(session.query(["a", "b"], bypass_cache=true), ["0", "1"])
  assert_eq(session.statistics().resets, 2)
  assert_eq(session.statistics().steps, 4)
  assert_eq(session.statistics().cache_nodes, 3)
}

///|
test "uncached observations detect reset drift rather than hiding it" {
  let epoch = [0]
  let closed = [0]
  let target = @lens.System::new(
    reset=() => epoch[0] += 1,
    step=_ => epoch[0].to_string(),
    close=() => closed[0] += 1,
  )
  let session = @lens.Experiment::new(target, ["x"], recheck_every=2)
  assert_eq(session.query(["x"]), ["1"])
  try session.query(["x"]) catch {
    @lens.InconsistentObservation(word~, expected~, actual~) => {
      assert_eq(word, ["x"])
      assert_eq(expected, ["1"])
      assert_eq(actual, ["2"])
    }
    error => raise error
  } noraise {
    _ => fail("expected conflicting observation")
  }
  assert_eq(closed[0], 2)
}

///|
test "query budgets reject before executing a partial word" {
  let session = @lens.Experiment::new(
    sample().system(),
    ["a", "b"],
    max_steps=1,
  )
  try session.query(["a", "b"]) catch {
    @lens.LimitExceeded(kind) => assert_eq(kind, "target-steps")
    error => raise error
  } noraise {
    _ => fail("expected budget limit")
  }
  assert_eq(session.statistics().steps, 0)
  assert_eq(session.statistics().resets, 0)
  assert_eq(session.query(["b"]), ["0"])
}

///|
suberror TargetFailure

///|
test "target exceptions close the target and do not cache failed queries" {
  let closed = [0]
  let target = @lens.System::new(
    reset=() => (),
    step=_ => raise TargetFailure,
    close=() => closed[0] += 1,
  )
  let session = @lens.Experiment::new(target, ["x"])
  for _ in 0..<2 {
    try session.query(["x"]) catch {
      TargetFailure => ()
      error => raise error
    } noraise {
      _ => fail("expected target exception")
    }
  }
  assert_eq(closed[0], 2)
  assert_eq(session.statistics().cache_hits, 0)
  assert_eq(session.statistics().completed_queries, 0)
  assert_eq(session.statistics().cache_nodes, 1)
}

///|
test "confirmation queries real adapters and preserves input ownership" {
  let left = @lens.Experiment::new(sample().system(), ["a", "b"])
  let right_model = @lens.Machine::new(["a", "b"], [
    [{ target: 0, output: "0", }, { target: 0, output: "0", }],
  ])
  let right = @lens.Experiment::new(right_model.system(), ["a", "b"])
  let inputs = ["a", "b"]
  let confirmed = @lens.confirm_difference(left, right, inputs).unwrap()
  inputs[0] = "bad"
  assert_eq(confirmed.inputs, ["a", "b"])
  assert_eq(left.statistics().resets, 1)
  assert_true(@lens.confirm_difference(left, right, ["b"]) is None)
}
