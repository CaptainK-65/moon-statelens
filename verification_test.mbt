///|
fn binary_machine(encoding : Int32) -> @lens.Machine raise {
  let table : Array[Array[@lens.Transition]] = []
  for state in 0..<2 {
    let row : Array[@lens.Transition] = []
    for input in 0..<2 {
      let pair = (encoding >> ((state * 2 + input) * 2)) & 3
      row.push({ target: pair & 1, output: (pair >> 1).to_string(), })
    }
    table.push(row)
  }
  @lens.Machine::new(["a", "b"], table)
}

///|
fn verify_reference(
  plan : @lens.VerificationPlan,
  model : @lens.Machine,
  target : @lens.Machine,
) -> @lens.CheckResult raise {
  let cursor = @lens.VerificationCursor::new(plan, model)
  for _ in 0..<100000 {
    match cursor.event() {
      Query(q) => cursor.submit(q.id, target.trace(q.inputs))
      Completed(result) => return result
    }
  }
  fail("verification did not finish")
}

///|
test "Wp agrees with independent exact comparison for all 65536 pairs of binary two-state machines" {
  let machines = Array::makei(256, code => binary_machine(code))
  for model in machines {
    for target in machines {
      let check = verify_reference(
        WpMethod(bound=2, max_tests=1000, max_work=10000),
        model,
        target,
      )
      match @lens.distinguish(model, target) {
        None => assert_true(check is NoCounterexample(ConditionalStateBound(2)))
        Some(_) => {
          guard check is Counterexample(word) else {
            fail("Wp missed a two-state difference")
          }
          assert_true(model.trace(word) != target.trace(word))
        }
      }
    }
  }
}

///|
test "Wp learns hidden-state targets using both learners and reports truncation honestly" {
  let target = delayed_target(6)
  for algorithm in [@lens.Algorithm::LStar, @lens.Algorithm::KearnsVazirani] {
    let result = @lens.learn_with(
      @lens.Experiment::new(target.system(), target.alphabet()),
      @lens.Oracle::wp_method(6, max_tests=50000),
      algorithm,
    )
    assert_true(result.status is Supported(ConditionalStateBound(6)))
    assert_true(@lens.distinguish(result.model.unwrap(), target) is None)
  }
  let limited = verify_reference(
    WpMethod(bound=6, max_tests=1, max_work=10000),
    target,
    target,
  )
  assert_true(limited is Inconclusive("conformance-tests"))
}

///|
test "strategy chains freshly replay regressions and preserve final evidence and stage statistics" {
  let target = sample()
  let cursor = @lens.VerificationCursor::new(
    Chain([
      Replay([["a", "b"]]),
      RandomWords(seed=42U, max_length=6, tests=20),
      WpMethod(bound=2, max_tests=1000, max_work=10000),
    ]),
    target,
  )
  for _ in 0..<10000 {
    match cursor.event() {
      Query(q) => cursor.submit(q.id, target.trace(q.inputs))
      Completed(result) => {
        assert_true(result is NoCounterexample(ConditionalStateBound(2)))
        let stages = cursor.stages()
        assert_eq(stages.length(), 3)
        assert_eq(stages[0].tests, 1)
        assert_eq(stages[1].tests, 20)
        assert_true(stages.all(s => s.result == "completed"))
        return
      }
    }
  }
  fail("chain did not complete")
}

///|
test "single-state Wp checks transition outputs and a failed stage cannot be replaced by random success" {
  let target = stateless("yes")
  let mutant = stateless("no")
  assert_true(
    verify_reference(
      WpMethod(bound=1, max_tests=20, max_work=20),
      target,
      mutant,
    )
    is Counterexample(["x"]),
  )
  let result = verify_reference(
    Chain([
      RandomWords(seed=1U, max_length=1, tests=1),
      WpMethod(bound=3, max_tests=1, max_work=1000),
    ]),
    target,
    target,
  )
  assert_true(result is Inconclusive("conformance-tests"))
}

///|
test "verification snapshots nested caller-owned plans before suspending" {
  let target = stateless("ok")
  let word = ["x"]
  let words = [word]
  let plans : Array[@lens.VerificationPlan] = [
    Replay(words),
    WpMethod(bound=1, max_tests=10, max_work=10),
  ]
  let cursor = @lens.VerificationCursor::new(Chain(plans), target)
  plans.clear()
  words.clear()
  word.clear()
  for _ in 0..<20 {
    match cursor.event() {
      Query(request) => cursor.submit(request.id, target.trace(request.inputs))
      Completed(result) => {
        assert_true(result is NoCounterexample(ConditionalStateBound(1)))
        assert_eq(cursor.stages().length(), 2)
        return
      }
    }
  }
  fail("snapshot did not finish")
}
