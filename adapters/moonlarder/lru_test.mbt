///|
// Independent finite LRU specification, used only AFTER black-box learning.
fn reference() -> @lens.Machine raise {
  let keys = ["a", "b", "c"]
  let states : Array[Array[String]] = [[]]
  for a in keys {
    states.push([a])
  }
  for a in keys {
    for b in keys {
      if a != b {
        states.push([a, b])
      }
    }
  }
  let table : Array[Array[@lens.Transition]] = states.map(order => {
    @adapter.alphabet().map(input => {
      let next = order.copy()
      let output = if input == "clear" {
        next.clear()
        "cleared"
      } else {
        let key = input.split(":").last().unwrap().to_owned()
        let present = next.contains(key)
        let is_put = input.has_prefix("put:")
        if is_put || present {
          if next.search(key) is Some(index) {
            ignore(next.remove(index))
          }
          next.push(key)
          if next.length() > 2 {
            ignore(next.remove(0))
          }
        }
        if is_put {
          "stored"
        } else if present {
          "hit:" + key
        } else {
          "miss"
        }
      }
      { target: states.search(next).unwrap(), output, }
    })
  })
  @lens.Machine::new(@adapter.alphabet(), table)
}

///|
test "actual moonlarder LRU is learned without exposing a reference model" {
  let experiment = @lens.Experiment::new(
    @adapter.system(),
    @adapter.alphabet(),
    max_queries=200000,
    max_steps=5000000,
  )
  let result = @lens.learn(
    experiment,
    @lens.Oracle::w_method(10, max_tests=100000),
  )
  assert_true(result.status is Supported(ConditionalStateBound(10)))
  let learned = result.model.unwrap()
  assert_eq(learned.state_count(), 10)
  assert_true(@lens.distinguish(learned, reference()) is None)
  let trace = ["put:a", "put:b", "get:a", "put:c", "get:b", "get:a"]
  assert_eq(experiment.query(trace, bypass_cache=true), [
    "stored", "stored", "hit:a", "stored", "miss", "hit:a",
  ])
}
