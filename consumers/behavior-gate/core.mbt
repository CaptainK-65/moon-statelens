///|
/// Same committed source runs against the candidate workspace and public package.
fn verify_core() -> Unit raise {
  let alphabet = ["logout", "request"]
  let baseline = @lens.Machine::new(alphabet, [
    [{ target: 0, output: "ok", }, { target: 0, output: "denied", }],
  ])
  let mutant = @lens.Machine::new(alphabet, [
    [{ target: 0, output: "ok", }, { target: 0, output: "allowed", }],
  ])
  let suite = @lens.RegressionSuite::from_json(
    Json(baseline.regression_suite()),
  )
  assert_true(suite.is_complete())
  assert_true(suite.plan().validate())
  guard suite.plan().run(@lens.Experiment::new(baseline.system(), alphabet))
    is { "passed": True, .. } else {
    fail("published regression")
  }
  let failed = suite
    .plan()
    .run(@lens.Experiment::new(mutant.system(), alphabet))
  guard failed is { "passed": False, "execution_complete": True, .. } else {
    fail("published mutation")
  }
  assert_true(@lens.regression_junit(failed).contains("<failure"))
  assert_true(@lens.evidence_html(failed).contains("Observatory"))
  let rule = @lens.BehaviorRule::from_json(
    Json(
      @lens.BehaviorRule::new(
        "logout-denial",
        { input: "request", output: "allowed", },
        kind="after",
        trigger={ input: "logout", output: "ok", },
      ),
    ),
  )
  guard rule.verify(mutant, @lens.Experiment::new(mutant.system(), alphabet))
    is { "status": "confirmed-violation", .. } else {
    fail("published rule")
  }
  assert_eq(@lens.diagnose_models(baseline, mutant).differences.length(), 1)
  println("v0.3 core consumer ok")
}
