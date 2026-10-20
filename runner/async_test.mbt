///|
async fn delayed(
  target : @lens.Machine,
  closed : Array[Int32],
) -> @runner.AsyncSystem {
  @async.pause()
  // Adapter through independent explicit model state, not private callbacks.
  let current = [target.initial_state()]
  let alphabet = target.alphabet()
  let table = target.table()
  @runner.AsyncSystem::new(
    reset=() => {
      @async.pause()
      current[0] = target.initial_state()
    },
    step=input => {
      @async.pause()
      let edge = table[current[0]][alphabet.search(input).unwrap()]
      current[0] = edge.target
      edge.output
    },
    close=() => {
      @async.pause()
      closed[0] += 1
    },
  )
}

///|
async test "both async learners match their sync equivalents using actual suspensions" {
  let target = @lens.Machine::new(["a", "b"], [
    [{ target: 1, output: "ok", }, { target: 0, output: "no", }],
    [{ target: 0, output: "ok", }, { target: 1, output: "yes", }],
  ])
  for algorithm in [@lens.Algorithm::LStar, @lens.Algorithm::KearnsVazirani] {
    let closed = [0]
    let experiment = @runner.AsyncExperiment::new(
      delayed(target, closed),
      target.alphabet(),
    )
    let report = @runner.infer(
      experiment,
      WpMethod(bound=2, max_tests=1000, max_work=10000),
      algorithm~,
    )
    assert_true(report.learning.status is Supported(ConditionalStateBound(2)))
    assert_true(
      @lens.distinguish(report.learning.model.unwrap(), target) is None,
    )
    let sync = @lens.learn_with(
      @lens.Experiment::new(target.system(), target.alphabet()),
      @lens.Oracle::wp_method(2),
      algorithm,
    )
    assert_true(
      @lens.distinguish(sync.model.unwrap(), report.learning.model.unwrap())
      is None,
    )
    assert_eq(Json(sync.statistics), Json(report.learning.statistics))
    assert_eq(closed[0], report.learning.statistics.completed_queries)
  }
}

///|
async test "step timeout performs protected cleanup and rejects partial cache writes" {
  let closed = [0]
  let experiment = @runner.AsyncExperiment::new(
    @runner.AsyncSystem::new(
      reset=() => @async.pause(),
      step=_ => {
        @async.sleep(200)
        "late"
      },
      close=() => {
        @async.pause()
        closed[0] += 1
      },
    ),
    ["x"],
    step_timeout_ms=5,
  )
  try experiment.query(["x"]) catch {
    @runner.TimedOut("step") => ()
    error => raise error
  } noraise {
    _ => fail("expected step timeout")
  }
  assert_eq(closed[0], 1)
  assert_eq(experiment.statistics().cache_nodes, 1)
  assert_eq(experiment.statistics().completed_queries, 0)
}

///|
async test "cancellation attempts cleanup and leaves the session usable" {
  let slow = [true]
  let closed = [0]
  let experiment = @runner.AsyncExperiment::new(
    @runner.AsyncSystem::new(
      reset=() => @async.pause(),
      step=_ => {
        if slow[0] {
          @async.sleep(200)
        } else {
          @async.pause()
        }
        "ok"
      },
      close=() => {
        @async.pause()
        closed[0] += 1
      },
    ),
    ["x"],
  )
  let cancelled = @async.with_timeout_opt(5, () => experiment.query(["x"]))
  assert_true(cancelled is None)
  assert_eq(closed[0], 1)
  slow[0] = false
  assert_eq(experiment.query(["x"]), ["ok"])
  assert_eq(closed[0], 2)
}
