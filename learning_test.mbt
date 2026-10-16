///|
fn delayed_target(states : Int32) -> @lens.Machine raise {
  let table : Array[Array[@lens.Transition]] = Array::makei(states, state => {
    [
      { target: (state + 1) % states, output: "tick", },
      { target: 0, output: if state == states - 1 { "yes" } else { "no" }, },
    ]
  })
  @lens.Machine::new(["advance", "probe"], table)
}

///|
test "learner refines hidden states with delayed distinguishing suffixes" {
  let target = delayed_target(7)
  let experiment = @lens.Experiment::new(target.system(), target.alphabet())
  let result = @lens.learn(experiment, @lens.Oracle::exact(target))
  assert_true(result.status is Supported(ExactReference))
  let model = result.model.unwrap()
  assert_eq(model.state_count(), 7)
  assert_true(@lens.distinguish(target, model) is None)
  assert_true(result.counterexamples.length() > 0)
  assert_true(result.rounds.length() > 1)
  assert_true(
    result.rounds.last().unwrap().suffixes > target.alphabet().length(),
  )
}

///|
test "learner receives an adapter and does not need a reference model" {
  let logged_in = [false]
  let target = @lens.System::new(reset=() => logged_in[0] = false, step=input => {
    match input {
      "login" => {
        logged_in[0] = true
        "ok"
      }
      "logout" => {
        logged_in[0] = false
        "ok"
      }
      _ => if logged_in[0] { "allowed" } else { "denied" }
    }
  })
  // This bounded independent experiment does not know or read the hidden flag.
  let oracle = @lens.Oracle::new((hypothesis, experiment) => {
    let actions = ["login", "logout", "request"]
    for a in actions {
      for b in actions {
        for c in actions {
          let word = [a, b, c]
          if hypothesis.trace(word) != experiment.query(word, bypass_cache=true) {
            return Counterexample(word)
          }
        }
      }
    }
    NoCounterexample(Budgeted("all words of length 3"))
  })
  let result = @lens.learn(
    @lens.Experiment::new(target, ["login", "logout", "request"]),
    oracle,
  )
  assert_true(result.status is Supported(Budgeted(_)))
  assert_eq(result.model.unwrap().state_count(), 2)
  assert_eq(result.model.unwrap().trace(["login", "logout", "request"]), [
    "ok", "ok", "denied",
  ])
}

///|
test "budget exhaustion returns inconclusive and retains a completed hypothesis" {
  let target = delayed_target(4)
  let no_budget = @lens.learn(
    @lens.Experiment::new(target.system(), target.alphabet(), max_queries=0),
    @lens.Oracle::exact(target),
  )
  assert_true(no_budget.status is Inconclusive("physical-queries"))
  assert_true(no_budget.model is None)
  let limited_rounds = @lens.learn(
    @lens.Experiment::new(target.system(), target.alphabet()),
    @lens.Oracle::exact(target),
    max_rounds=1,
  )
  assert_true(limited_rounds.status is Inconclusive("learning-rounds"))
  assert_true(limited_rounds.model is Some(_))
  let limited_states = @lens.learn(
    @lens.Experiment::new(target.system(), target.alphabet()),
    @lens.Oracle::exact(target),
    max_states=1,
  )
  assert_true(limited_states.status is Inconclusive("hypothesis-states"))
}

///|
test "oracle lies and unstable target observations cannot become successful learning" {
  let target = sample()
  let liar = @lens.Oracle::new((_, _) => Counterexample(["b"]))
  expect_invalid(() => {
    ignore(
      @lens.learn(
        @lens.Experiment::new(target.system(), target.alphabet()),
        liar,
      ),
    )
  })
  let count = [0]
  let unstable = @lens.System::new(reset=() => count[0] += 1, step=_ => {
    count[0].to_string()
  })
  let result = @lens.learn(
    @lens.Experiment::new(unstable, ["x"], recheck_every=1),
    @lens.Oracle::new((_, _) => NoCounterexample(Budgeted("unused"))),
  )
  assert_true(result.status is Unstable(..))
}
