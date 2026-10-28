///|
fn v03_config(
  model : @lens.Machine,
  queries~ : Int32 = 100000,
) -> @integration.Config raise {
  @integration.Config::from_json(
    Json::object({
      "format": Json("moonstatelens.experiment"),
      "version": Json(1),
      "identity": Json("v03-test"),
      "abstraction": Json("test-v1"),
      "alphabet": Json(model.alphabet()),
      "target": Json::object({ "kind": Json("model"), "model": Json(model) }),
      "budgets": Json::object({ "queries": Json(queries) }),
      "verification": Json::object({
        "kind": Json("wp"),
        "state_bound": Json(model.state_count()),
      }),
    }),
  )
}

///|
async test "saved suites run independently of inference and preserve output artifacts" {
  let model = @lens.Machine::new(["x"], [[{ target: 0, output: "ok", }]])
  let suite = model.regression_suite()
  assert_eq(@integration.regress(v03_config(model), suite).exit_code, 0)
  let mutant = @lens.Machine::new(["x"], [[{ target: 0, output: "changed", }]])
  assert_eq(@integration.regress(v03_config(mutant), suite).exit_code, 2)
  assert_eq(
    @integration.regress(v03_config(model, queries=0), suite).exit_code,
    3,
  )
  let dir = @fs.tmpdir(prefix="statelens-v03-")
  defer @fs.rmdir(dir, recursive=true)
  let value = Json::object({
    "format": Json("moonstatelens.experiment"),
    "version": Json(1),
    "identity": Json("v03-artifacts"),
    "abstraction": Json("test-v1"),
    "alphabet": Json(["x"]),
    "target": Json::object({ "kind": Json("model"), "model": Json(model) }),
    "verification": Json::object({ "kind": Json("wp"), "state_bound": Json(1) }),
    "artifacts": Json::object({
      "report": Json(dir + "/report.json"),
      "traces": Json(dir + "/traces.json"),
    }),
  })
  let result = @integration.regress(
    @integration.Config::from_json(value),
    suite,
  )
  assert_eq(@fs.read_file(dir + "/report.json").json(), result.report)
  guard @fs.read_file(dir + "/traces.json").json()
    is { "entries": Array(entries), .. } &&
    entries.length() > 0 else {
    fail("fresh traces missing")
  }
}

///|
async test "rule integration confirms shared defects and diagnosis confirms multiple contexts" {
  let model = @lens.Machine::new(["a", "b"], [
    [{ target: 0, output: "allowed", }, { target: 0, output: "allowed", }],
  ])
  let rule = @lens.BehaviorRule::new("deny-a", {
    input: "a",
    output: "allowed",
  })
  assert_eq(@integration.check_rules(v03_config(model), [rule]).exit_code, 2)
  let changed = @lens.Machine::new(["a", "b"], [
    [{ target: 0, output: "denied", }, { target: 0, output: "denied", }],
  ])
  assert_eq(@integration.check_rules(v03_config(changed), [rule]).exit_code, 0)
  let report = @integration.diagnose(v03_config(model), v03_config(changed))
  assert_eq(report.exit_code, 2)
  guard report.report
    is {
      "complete": True,
      "confirmed_contexts": 2,
      "findings": Array(findings),
      ..
    } &&
    findings.length() == 2 else {
    fail("expected two freshly confirmed contexts")
  }
  assert_eq(
    @integration.diagnose(v03_config(model), v03_config(model)).exit_code,
    0,
  )
}
