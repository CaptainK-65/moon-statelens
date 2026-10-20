///|
#cfg(platform="windows")
let fixture_path : String = "_build/native/debug/build/cmd/fixture/fixture.exe"

///|
#cfg(not(platform="windows"))
let fixture_path : String = "_build/native/debug/build/cmd/fixture/fixture.exe"

///|
async test "real JSONL subprocess learns the session target and reaps every query process" {
  @external.with_jsonl(fixture_path, ["session"], system => {
    let report = @runner.infer(
      @runner.AsyncExperiment::new(system, ["login", "logout", "request"]),
      WpMethod(bound=2, max_tests=1000, max_work=10000),
      algorithm=KearnsVazirani,
    )
    assert_true(report.learning.status is Supported(ConditionalStateBound(2)))
    assert_eq(report.learning.model.unwrap().state_count(), 2)
  })
}

///|
async test "JSONL accepts fragmented UTF8 but rejects ids framing extra replies and stderr overflow" {
  @external.with_jsonl(fixture_path, ["fragmented"], system => {
    let experiment = @runner.AsyncExperiment::new(system, ["request"])
    assert_eq(experiment.query(["request"]), ["允许"])
  })
  for
    mode in [
      "wrong-id", "bad-json", "extra-output", "large-frame", "stderr-flood", "bad-reset",
    ] {
    @external.with_jsonl(
      fixture_path,
      [mode],
      system => {
        let experiment = @runner.AsyncExperiment::new(system, ["request"])
        try experiment.query(["request"]) catch {
          _ => ()
        } noraise {
          _ => fail("accepted invalid protocol fixture: " + mode)
        }
        assert_eq(experiment.statistics().cache_nodes, 1)
        assert_eq(experiment.statistics().completed_queries, 0)
      },
      max_frame_bytes=128,
      max_stderr_bytes=16,
    )
  }
}

///|
async test "JSONL timeout and failing exit do not commit traces or leak live children" {
  for mode in ["slow-step", "hang-close", "nonzero-close", "crash"] {
    @external.with_jsonl(fixture_path, [mode], system => {
      let experiment = @runner.AsyncExperiment::new(
        system,
        ["request"],
        step_timeout_ms=500,
        cleanup_timeout_ms=500,
      )
      try experiment.query(["request"]) catch {
        _ => ()
      } noraise {
        _ => fail("expected injected process failure: " + mode)
      }
      assert_eq(experiment.statistics().completed_queries, 0)
    })
  }
}
