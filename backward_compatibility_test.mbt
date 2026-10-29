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
