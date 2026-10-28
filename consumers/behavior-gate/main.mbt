///|
fn config(output : String) -> @integration.Config raise {
  let model = @lens.Machine::new(["x"], [[{ target: 0, output, }]])
  @integration.Config::from_json(
    Json::object({
      "format": Json("moonstatelens.experiment"),
      "version": Json(1),
      "identity": Json(output),
      "abstraction": Json("one-state-v1"),
      "alphabet": Json(["x"]),
      "target": Json::object({ "kind": Json("model"), "model": Json(model) }),
      "verification": Json::object({
        "kind": Json("wp"),
        "state_bound": Json(1),
      }),
    }),
  )
}

///|
async fn main {
  verify_core()
  let baseline = @lens.Machine::new(["x"], [[{ target: 0, output: "ok", }]])
  let suite = baseline.regression_suite()
  assert_eq(@integration.regress(config("ok"), suite).exit_code, 0)
  assert_eq(@integration.regress(config("bad"), suite).exit_code, 2)
  assert_eq(
    @integration.check_rules(config("bad"), [
      @lens.BehaviorRule::new("no-bad", { input: "x", output: "bad", }),
    ]).exit_code,
    2,
  )
  assert_eq(@integration.diagnose(config("ok"), config("bad")).exit_code, 2)
  println("v0.3 native consumer ok")
}
