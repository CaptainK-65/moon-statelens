///|
test "historical hints handle changed outputs, added/merged states and unrelated structure with fresh observations" {
  for case in 0..<60 {
    let old = generated_target(
      (case + 100).reinterpret_as_uint(),
      2 + case % 10,
    )
    let changed = generated_target(
      (case + 800).reinterpret_as_uint(),
      1 + case % 12,
    )
    let observed = [0]
    let state = [changed.initial_state()]
    let rows = changed.table()
    let alphabet = changed.alphabet()
    let system = @lens.System::new(
      reset=() => {
        state[0] = changed.initial_state()
        observed[0] += 1
      },
      step=input => {
        let edge = rows[state[0]][alphabet.search(input).unwrap()]
        state[0] = edge.target
        edge.output
      },
    )
    let result = @lens.learn_with(
      @lens.Experiment::new(system, alphabet),
      @lens.Oracle::exact(changed),
      LStar,
      seed=old,
    )
    assert_true(result.status is Supported(ExactReference))
    assert_true(@lens.distinguish(changed, result.model.unwrap()) is None)
    assert_true(observed[0] > 0)
    let binary = @lens.learn_with(
      @lens.Experiment::new(changed.system(), alphabet),
      @lens.Oracle::exact(changed),
      KearnsVazirani,
      binary_cex=true,
    )
    assert_true(binary.status is Supported(ExactReference))
    assert_true(@lens.distinguish(changed, binary.model.unwrap()) is None)
  }
}

///|
test "history budgets and alphabet mismatches never certify a result" {
  let old = @lens.Machine::new(["a"], [[{ target: 0, output: "old", }]])
  let new = @lens.Machine::new(["a"], [[{ target: 0, output: "new", }]])
  let limited = @lens.learn_with(
    @lens.Experiment::new(new.system(), ["a"], max_queries=0),
    @lens.Oracle::exact(new),
    LStar,
    seed=old,
  )
  assert_true(limited.status is Inconclusive(_))
  let result = @lens.learn_with(
    @lens.Experiment::new(new.system(), ["a"]),
    @lens.Oracle::exact(new),
    LStar,
    seed=old,
  )
  assert_eq(result.model.unwrap().trace(["a"]), ["new"])
  let different = @lens.Machine::new(["b"], [[{ target: 0, output: "ok", }]])
  try @lens.LearningDriver::new(LStar, ["a"], seed=different) catch {
    @lens.InvalidArgument(_) => ()
    error => raise error
  } noraise {
    _ => fail("accepted incompatible history")
  }
}

///|
test "binary counterexample decomposition bounds long delayed split histories" {
  let target = @lens.Machine::new(["a", "b", "c"], [
    [
      { target: 0, output: "tick", },
      { target: 1, output: "ok", },
      { target: 0, output: "no", },
    ],
    [
      { target: 1, output: "tick", },
      { target: 1, output: "ok", },
      { target: 1, output: "yes", },
    ],
  ])
  for binary in [false, true] {
    let driver = @lens.LearningDriver::new(
      KearnsVazirani,
      target.alphabet(),
      binary_cex=binary,
    )
    let mut injected = false
    let mut refinement_queries = 0
    for _ in 0..<10000 {
      match driver.event() {
        Query(q) => {
          if injected {
            refinement_queries += 1
          }
          driver.submit(q.id, target.trace(q.inputs))
        }
        Hypothesis(model) => {
          if @lens.distinguish(model, target) is None {
            break
          }
          let word = Array::make(1023, "a") + ["b", "c"]
          assert_true(model.trace(word) != target.trace(word))
          driver.refine(word, target.trace(word))
          injected = true
        }
      }
    }
    guard driver.event() is Hypothesis(model) else { fail("no hypothesis") }
    assert_true(@lens.distinguish(model, target) is None)
    if binary {
      assert_true(refinement_queries < 30)
    } else {
      assert_true(refinement_queries > 1000)
    }
  }
}
