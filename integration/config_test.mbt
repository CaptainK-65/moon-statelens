///|
fn model_config(
  output : String,
  evidence~ : String = "conditional-state-bound",
) -> Json raise {
  Json::object({
    "format": Json("moonstatelens.experiment"),
    "version": Json(1),
    "identity": Json("controlled-" + output),
    "abstraction": Json("one-symbol-v1"),
    "alphabet": Json(["x"]),
    "learner": Json("kv"),
    "target": Json::object({
      "kind": Json("model"),
      "model": Json(@lens.Machine::new(["x"], [[{ target: 0, output, }]])),
    }),
    "verification": Json::object({ "kind": Json("wp"), "state_bound": Json(1) }),
    "expectations": Json::object({ "evidence": Json(evidence) }),
  })
}

///|
async test "configured run and comparison enforce evidence scope and confirm actual output differences" {
  let left = @integration.Config::from_json(model_config("yes"))
  let right = @integration.Config::from_json(model_config("no"))
  let learned = @integration.run(left)
  assert_eq(learned.exit_code, 0)
  let different = @integration.compare(left, right)
  assert_eq(different.exit_code, 2)
  guard different.report
    is { "status": { "kind": "confirmed-difference", .. }, .. } else {
    fail("missing confirmed evidence")
  }
  assert_eq(@integration.compare(left, left).exit_code, 0)
  let replay = @integration.replay(left, [["x", "x"]])
  guard replay is { "traces": [{ "outputs": ["yes", "yes"], .. }], .. } else {
    fail("missing actual replay")
  }
  let strict = @integration.Config::from_json(
    model_config("yes", evidence="exact-reference"),
  )
  assert_eq(@integration.run(strict).exit_code, 3)
}

///|
test "configuration rejects typos fractional budgets unknown learners and external exact certification" {
  let invalid = model_config("yes")
  guard invalid is Object(object) else { fail("object") }
  object["typo"] = Json(true)
  try @integration.Config::from_json(invalid) catch {
    @runner.Configuration(_) => ()
    error => raise error
  } noraise {
    _ => fail("accepted unknown field")
  }
  object.remove("typo") |> ignore
  object["budgets"] = Json::object({ "states": Json(1.5) })
  try @integration.Config::from_json(invalid) catch {
    @runner.Configuration(_) => ()
    error => raise error
  } noraise {
    _ => fail("accepted fractional budget")
  }
  object.remove("budgets") |> ignore
  object["learner"] = Json("ttt")
  try @integration.Config::from_json(invalid) catch {
    @runner.Configuration(_) => ()
    error => raise error
  } noraise {
    _ => fail("accepted unsupported learner")
  }
  object["learner"] = Json("kv")
  object["target"] = Json::object({
    "kind": Json("sqlite"),
    "program": Json("sqlite3"),
  })
  object["expectations"] = Json::object({ "evidence": Json("exact-reference") })
  try @integration.Config::from_json(invalid) catch {
    @runner.Configuration(_) => ()
    error => raise error
  } noraise {
    _ => fail("certified external target using only explicit reference")
  }
}
