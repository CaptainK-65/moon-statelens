///|
async test "saved suite timeout preserves incomplete evidence and bounded cleanup" {
  let closed = [0]
  let system = @runner.AsyncSystem::new(
    reset=() => @async.pause(),
    step=_ => {
      @async.sleep(100)
      "late"
    },
    close=() => {
      closed[0] += 1
      @async.pause()
    },
  )
  let model = @lens.Machine::new(["x"], [[{ target: 0, output: "ok", }]])
  let experiment = @runner.AsyncExperiment::new(
    system,
    ["x"],
    step_timeout_ms=5,
  )
  let report = @runner.run_regression(
    experiment,
    model.regression_suite().plan(),
  )
  guard report
    is {
      "execution_complete": False,
      "passed": False,
      "failed_cases": 0,
      "reason": String(reason),
      ..
    } &&
    reason.contains("timeout") else {
    fail("timeout became a pass or false regression")
  }
  assert_eq(closed[0], 1)
  assert_eq(experiment.statistics().completed_queries, 0)
}
