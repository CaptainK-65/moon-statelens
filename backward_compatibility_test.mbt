///|
test "directional compatibility handles extension removal and long history" {
  let old = @lens.Machine::new(["x"], [
    [{ target: 1, output: "ok", }],
    [{ target: 1, output: "done", }],
  ])
  let extension = @lens.Machine::new(["extra", "x"], [
    [{ target: 0, output: "new", }, { target: 1, output: "ok", }],
    [{ target: 0, output: "new", }, { target: 1, output: "done", }],
  ])
  assert_true(
    @lens.backward_compatibility(old, extension)
    is { "status": "compatible-on-old-inputs", .. },
  )
  assert_true(
    @lens.backward_compatibility(extension, old)
    is { "status": "missing-old-operations", .. },
  )
  let changed = @lens.Machine::new(["x"], [
    [{ target: 1, output: "ok", }],
    [{ target: 1, output: "wrong", }],
  ])
  assert_true(
    @lens.backward_compatibility(old, changed)
    is {
      "status": "changed-old-behavior",
      "difference": { "inputs": ["x", "x"], .. },
      ..
    },
  )
  let events = []
  let r = @lens.learn_with(
    @lens.Experiment::new(old.system(), old.alphabet()),
    @lens.Oracle::exact(old),
    LStar,
    on_event=e => events.push(e),
  )
  assert_true(r.status is Supported(_))
  assert_true(events[0] is { "kind": "hypothesis", "model": Object(_), .. })
  assert_true(events[events.length() - 1] is { "kind": "verification", .. })
}

///|
test "directional comparison preserves state renumbering and fails on pair limits" {
  let a = @lens.Machine::new(["x"], [
    [{ target: 1, output: "a", }],
    [{ target: 0, output: "b", }],
  ])
  let b = @lens.Machine::new(
    ["new", "x"],
    [
      [{ target: 0, output: "new", }, { target: 1, output: "b", }],
      [{ target: 0, output: "new", }, { target: 0, output: "a", }],
    ],
    initial=1,
  )
  assert_true(
    @lens.backward_compatibility(a, b)
    is { "status": "compatible-on-old-inputs", .. },
  )
  let limited = try {
    ignore(@lens.backward_compatibility(a, b, max_pairs=1))
    false
  } catch {
    @lens.LimitExceeded(_) => true
    _ => false
  }
  assert_true(limited)
}

///|
test "recorded counterexamples contain actual fresh outputs and incomplete is terminal" {
  let table : Array[Array[@lens.Transition]] = Array::makei(7, i => {
    [
      { target: (i + 1) % 7, output: "tick", },
      { target: i, output: if i == 6 { "hit" } else { "miss" }, },
    ]
  })
  let target = @lens.Machine::new(["advance", "probe"], table)
  for algorithm in [@lens.Algorithm::LStar, @lens.Algorithm::KearnsVazirani] {
    let events : Array[Json] = []
    let r = @lens.learn_with(
      @lens.Experiment::new(target.system(), target.alphabet()),
      @lens.Oracle::exact(target),
      algorithm,
      on_event=e => events.push(e),
    )
    assert_true(r.status is Supported(_))
    assert_true(events.any(e => e is { "kind": "counterexample", .. }))
    for event in events {
      if event
        is {
          "kind": "counterexample",
          "inputs": Array(words),
          "observed": observed,
          ..
        } {
        let inputs = words.map(x => {
          match x {
            String(s) => s
            _ => fail("input")
          }
        })
        assert_eq(observed, Json(target.trace(inputs)))
      }
    }
    let plain = @lens.learn_with(
      @lens.Experiment::new(target.system(), target.alphabet()),
      @lens.Oracle::exact(target),
      algorithm,
    )
    assert_true(
      @lens.distinguish(r.model.unwrap(), plain.model.unwrap()) is None,
    )
  }
  let events : Array[Json] = []
  let incomplete = @lens.learn_with(
    @lens.Experiment::new(target.system(), target.alphabet(), max_queries=0),
    @lens.Oracle::exact(target),
    LStar,
    on_event=e => events.push(e),
  )
  assert_true(incomplete.status is Inconclusive(_))
  assert_true(events[events.length() - 1] is { "kind": "inconclusive", .. })
}
