///|
async test "native configuration uses history without copying old outputs" {
  let old = @lens.Machine::new(["x"], [[{ target: 0, output: "old", }]])
  let current = @lens.Machine::new(["x"], [[{ target: 0, output: "new", }]])
  let value = Json::object({
    "format": Json("moonstatelens.experiment"),
    "version": Json(1),
    "identity": Json("evolution-native"),
    "abstraction": Json("one-state-v1"),
    "alphabet": Json(["x"]),
    "learner": Json("lstar"),
    "target": Json::object({ "kind": Json("model"), "model": Json(current) }),
    "history": Json::object({
      "abstraction": Json("one-state-v1"),
      "model": Json(old),
    }),
    "verification": Json::object({ "kind": Json("wp"), "state_bound": Json(1) }),
  })
  let result = @integration.run(@integration.Config::from_json(value))
  assert_eq(result.exit_code, 0)
  guard result.report
    is { "inference": { "learning": { "model": model, .. }, .. }, .. } else {
    fail("model")
  }
  assert_eq(@lens.Machine::from_json(model).trace(["x"]), ["new"])
  guard value is Object(fields) else { fail("config") }
  fields["history"] = Json::object({
    "abstraction": Json("different"),
    "model": Json(old),
  })
  try @integration.Config::from_json(value) catch {
    @runner.Configuration(_) => ()
    error => raise error
  } noraise {
    _ => fail("accepted incompatible abstraction")
  }
}
