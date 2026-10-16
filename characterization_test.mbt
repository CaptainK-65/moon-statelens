///|
test "reverse pair graph suffixes agree with independent product BFS" {
  for seed in 1..<=40 {
    let model = generated_target(seed.reinterpret_as_uint(), 3 + seed % 10).minimize()
    let suffixes = model.characterizing_set()
    for left in 0..<model.state_count() {
      for right in (left + 1)..<model.state_count() {
        let shortest = model.distinguish_states(left, right).unwrap()
        let mut found_shortest = false
        for suffix in suffixes {
          if suffix.length() == shortest.length() &&
            model.trace_from(left, suffix) != model.trace_from(right, suffix) {
            found_shortest = true
            break
          }
        }
        assert_true(found_shortest)
      }
    }
  }
}

///|
test "preparation budgets cannot produce an incomplete characterizing set labeled complete" {
  let target = delayed_target(8)
  try target.characterizing_set(max_work=1) catch {
    @lens.LimitExceeded(reason) => assert_eq(reason, "characterization-work")
    error => raise error
  } noraise {
    _ => fail("expected characterization budget")
  }
  try target.minimize(max_work=1) catch {
    @lens.LimitExceeded(reason) => assert_eq(reason, "minimization-work")
    error => raise error
  } noraise {
    _ => fail("expected minimization budget")
  }
  let result = @lens.learn(
    @lens.Experiment::new(sample().system(), ["a", "b"]),
    @lens.Oracle::w_method(2, max_characterization_work=1),
  )
  assert_true(result.status is Inconclusive("characterization-work"))
}
