///|
fn generated_target(seed : UInt32, states : Int32) -> @lens.Machine raise {
  let mut random = seed
  let table : Array[Array[@lens.Transition]] = []
  for _ in 0..<states {
    let row : Array[@lens.Transition] = []
    for _ in 0..<3 {
      random = random * 1664525U + 1013904223U
      let next = ((random >> 8) % states.reinterpret_as_uint()).reinterpret_as_int()
      random = random * 1664525U + 1013904223U
      row.push({ target: next, output: ((random >> 16) % 4U).to_string(), })
    }
    table.push(row)
  }
  @lens.Machine::new(["a", "b", "c"], table)
}

///|
test "200 reproducible generated targets are learned and independently model-checked" {
  for case in 0..<200 {
    let target = generated_target(
      (case + 100).reinterpret_as_uint(),
      1 + case % 20,
    )
    let experiment = @lens.Experiment::new(target.system(), target.alphabet())
    let result = @lens.learn(experiment, @lens.Oracle::exact(target))
    assert_true(result.status is Supported(ExactReference))
    let learned = result.model.unwrap()
    assert_true(@lens.distinguish(target, learned) is None)
    assert_eq(learned.state_count(), target.minimize().state_count())
    assert_eq(learned.access_sequences().length(), learned.state_count())
  }
}

///|
test "all binary two-state output tables agree with minimization and shortest-word checks" {
  for mask in 0..<16 {
    let table : Array[Array[@lens.Transition]] = [
      [
        { target: 1, output: (mask & 1).to_string(), },
        { target: 0, output: ((mask >> 1) & 1).to_string(), },
      ],
      [
        { target: 1, output: ((mask >> 2) & 1).to_string(), },
        { target: 0, output: ((mask >> 3) & 1).to_string(), },
      ],
    ]
    let model = @lens.Machine::new(["a", "b"], table)
    assert_true(@lens.distinguish(model, model.minimize()) is None)
    match model.distinguish_states(0, 1) {
      Some(word) => {
        assert_true(model.trace_from(0, word) != model.trace_from(1, word))
        assert_eq(word.length(), 1)
      }
      None => assert_eq(model.minimize().state_count(), 1)
    }
  }
}

///|
test "every observable generated transition mutation has a replayable witness" {
  for case in 0..<30 {
    let model = generated_target((case + 900).reinterpret_as_uint(), 5)
    let changed = model.table()
    let reachable = model.access_sequences()
    let state = reachable[case % reachable.length()].0
    let column = case % 3
    changed[state][column] = {
      target: changed[state][column].target,
      output: "mutant",
    }
    let mutant = @lens.Machine::new(model.alphabet(), changed)
    let diff = @lens.distinguish(model, mutant).unwrap()
    assert_true(diff.left_outputs != diff.right_outputs)
    let confirmed = @lens.confirm_difference(
      @lens.Experiment::new(model.system(), model.alphabet()),
      @lens.Experiment::new(mutant.system(), mutant.alphabet()),
      diff.inputs,
    )
    assert_true(confirmed is Some(_))
  }
}
