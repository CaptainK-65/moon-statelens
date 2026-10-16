///|
fn sample() -> @lens.Machine raise {
  @lens.Machine::new(["a", "b"], [
    [{ target: 1, output: "0", }, { target: 0, output: "0", }],
    [{ target: 1, output: "0", }, { target: 0, output: "1", }],
  ])
}

///|
test "model constructor and accessors do not leak mutable tables" {
  let alphabet = ["x"]
  let row : Array[@lens.Transition] = [{ target: 0, output: "ok", }]
  let machine = @lens.Machine::new(alphabet, [row])
  alphabet[0] = "bad"
  row[0] = { target: 0, output: "bad", }
  machine.alphabet()[0] = "bad"
  machine.table()[0][0] = { target: 0, output: "bad", }
  assert_eq(machine.trace(["x", "x"]), ["ok", "ok"])
}

///|
test "product BFS returns a shortest distinguishing word" {
  let left = sample()
  let right = @lens.Machine::new(["b", "a"], [
    [{ target: 0, output: "0", }, { target: 0, output: "0", }],
  ])
  let diff = @lens.distinguish(left, right).unwrap()
  assert_eq(diff.inputs, ["a", "b"])
  assert_eq(diff.left_outputs, ["0", "1"])
  assert_eq(diff.right_outputs, ["0", "0"])
  for input in left.alphabet() {
    assert_eq(left.trace([input]), right.trace([input]))
  }
  assert_eq(@lens.distinguish(left, right).unwrap().inputs.length(), 2)
  assert_true(@lens.distinguish(left, left) is None)
  assert_eq(left.distinguish_states(0, 1), Some(["b"]))
}

///|
test "unreachable model states do not affect behavioral equivalence" {
  let left = @lens.Machine::new(["x"], [
    [{ target: 0, output: "ok", }],
    [{ target: 1, output: "bad", }],
  ])
  let right = @lens.Machine::new(["x"], [[{ target: 0, output: "ok", }]])
  assert_true(@lens.distinguish(left, right) is None)
  assert_eq(left.access_sequences().length(), 1)
}

///|
fn expect_invalid(f : () -> Unit raise) -> Unit raise {
  try f() catch {
    @lens.InvalidArgument(_) => ()
    error => raise error
  } noraise {
    _ => fail("expected invalid argument")
  }
}

///|
test "invalid models and unknown input are rejected" {
  expect_invalid(() => {
    ignore(
      @lens.Machine::new(["x", "x"], [
        [{ target: 0, output: "", }, { target: 0, output: "", }],
      ]),
    )
  })
  expect_invalid(() => ignore(@lens.Machine::new(["x"], [])))
  expect_invalid(() => ignore(@lens.Machine::new(["x"], [[]])))
  expect_invalid(() => {
    ignore(@lens.Machine::new(["x"], [[{ target: 2, output: "", }]]))
  })
  expect_invalid(() => ignore(sample().trace_from(-1, [])))
  try sample().trace(["missing"]) catch {
    @lens.UnknownInput(input) => assert_eq(input, "missing")
    error => raise error
  } noraise {
    _ => fail("expected unknown input")
  }
}
