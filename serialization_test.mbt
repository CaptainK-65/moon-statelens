///|
test "versioned models round-trip and reject invalid decoded transitions" {
  let target = sample()
  let decoded = @lens.decode_model(target.encode())
  assert_true(@lens.distinguish(target, decoded) is None)
  let invalid =
    #|{"format":"moonstatelens.mealy","version":1,"alphabet":["x"],"initial":0,"transitions":[[{"target":2,"output":"bad"}]]}
  expect_invalid(() => ignore(@lens.decode_model(invalid)))
  let unknown =
    #|{"format":"moonstatelens.mealy","version":99,"alphabet":["x"],"initial":0,"transitions":[[{"target":0,"output":"ok"}]]}
  expect_invalid(() => ignore(@lens.decode_model(unknown)))
  try @lens.decode_model(target.encode(), max_code_units=1) catch {
    @lens.LimitExceeded(kind) => assert_eq(kind, "model-json-length")
    error => raise error
  } noraise {
    _ => fail("expected JSON length limit")
  }
}

///|
test "DOT labels cannot inject graph edges" {
  let model = @lens.Machine::new(["x\"; evil -> node; //"], [
    [{ target: 0, output: "a\nb\\c", }],
  ])
  let dot = model.to_dot()
  assert_true(dot.contains("\\\"; evil"))
  assert_true(dot.contains("a\\nb\\\\c"))
  assert_true(dot.has_prefix("digraph Mealy {"))
}
