///|
fn drive_reference(
  algorithm : @lens.Algorithm,
  target : @lens.Machine,
) -> @lens.LearningDriver raise {
  let driver = @lens.LearningDriver::new(algorithm, target.alphabet())
  for _ in 0..<100000 {
    match driver.event() {
      Query(request) => driver.submit(request.id, target.trace(request.inputs))
      Hypothesis(model) =>
        match @lens.distinguish(model, target) {
          Some(diff) => driver.refine(diff.inputs, target.trace(diff.inputs))
          None => return driver
        }
    }
  }
  fail("driver did not terminate")
}

///|
test "both suspended learners learn 200 generated targets against independent references" {
  for case in 0..<200 {
    let target = generated_target(
      (case + 100).reinterpret_as_uint(),
      1 + case % 20,
    )
    for algorithm in [@lens.Algorithm::LStar, @lens.Algorithm::KearnsVazirani] {
      let driver = drive_reference(algorithm, target)
      guard driver.event() is Hypothesis(model) else { fail("missing model") }
      assert_true(@lens.distinguish(model, target) is None)
      assert_eq(model.minimize().state_count(), target.minimize().state_count())
      if algorithm == KearnsVazirani {
        assert_eq(driver.metrics().table_cells, 0)
        assert_true(driver.metrics().tree_nodes > 0)
      }
    }
  }
}

///|
test "both learners cover all 256 two-state binary transition and output machines" {
  for encoding in 0..<256 {
    let table : Array[Array[@lens.Transition]] = []
    for state in 0..<2 {
      let row : Array[@lens.Transition] = []
      for input in 0..<2 {
        let pair = (encoding >> ((state * 2 + input) * 2)) & 3
        row.push({ target: pair & 1, output: (pair >> 1).to_string(), })
      }
      table.push(row)
    }
    let target = @lens.Machine::new(["a", "b"], table)
    for algorithm in [@lens.Algorithm::LStar, @lens.Algorithm::KearnsVazirani] {
      let driver = drive_reference(algorithm, target)
      guard driver.event() is Hypothesis(model) else { fail("missing model") }
      assert_true(@lens.distinguish(target, model) is None)
    }
  }
}

///|
test "suspended requests are copied and stale or partial replies do not advance the learner" {
  let driver = @lens.LearningDriver::new(KearnsVazirani, ["x"])
  let request = match driver.event() {
    Query(q) => q
    _ => fail("query")
  }
  request.inputs.clear()
  let again = match driver.event() {
    Query(q) => q
    _ => fail("query")
  }
  assert_eq(again.inputs, ["x"])
  expect_invalid(() => driver.submit(again.id + 1, ["ok"]))
  expect_invalid(() => driver.submit(again.id, []))
  driver.submit(again.id, ["ok"])
  expect_invalid(() => driver.submit(again.id, ["ok"]))
  assert_true(driver.event() is Hypothesis(_))
}
