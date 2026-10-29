///|
test "custom quota changes, equal versions and exhausted budgets" {
  for (old, next) in [(1, 3), (3, 1), (2, 2)] {
    let result = execute({
      "mode": "quota",
      "old_capacity": old,
      "new_capacity": next,
      "queries": 20000,
    })
    assert_true(result is { "complete": True, .. })
    if old == next {
      assert_true(result is { "confirmed_difference": Null, .. })
    } else {
      assert_true(result is { "confirmed_difference": Object(_), .. })
    }
  }
  assert_true(
    execute({
      "mode": "quota",
      "old_capacity": 2,
      "new_capacity": 3,
      "queries": 1,
    })
    is { "complete": False, .. },
  )
}

///|
test "uploaded models use exact observable comparison" {
  let left = @lens.Machine::new(["x"], [[{ target: 0, output: "a", }]])
  let right = @lens.Machine::new(["x"], [[{ target: 0, output: "b", }]])
  assert_true(
    execute({ "mode": "models", "left": Json(left), "right": Json(right) })
    is { "difference": Object(_), .. },
  )
  assert_true(
    execute({ "mode": "models", "left": Json(left), "right": Json(left) })
    is { "difference": Null, .. },
  )
  let rejected = try {
    ignore(
      execute({
        "mode": "quota",
        "old_capacity": 0,
        "new_capacity": 3,
        "queries": 20000,
      }),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
