///|
fn expect_target_rejected(target : Json, field : String) -> Unit raise {
  let value = model_config("yes")
  guard value is Object(object) else { fail("configuration") }
  object["target"] = target
  try @integration.Config::from_json(value) catch {
    @runner.Configuration(message) => {
      assert_true(message.contains("target"))
      assert_true(message.contains(field))
    }
    error => raise error
  } noraise {
    _ => fail("accepted invalid target field: " + field)
  }
}

///|
test "offline validation rejects malformed target fields before execution" {
  for
    (target, field) in [
      (Json::object({ "kind": Json("jsonl") }), "program"),
      (
        Json::object({
          "kind": Json("jsonl"),
          "program": Json("missing"),
          "args": Json([42]),
        }),
        "args",
      ),
      (
        Json::object({
          "kind": Json("jsonl"),
          "program": Json("missing"),
          "max_frame_bytes": Json(1),
        }),
        "max_frame_bytes",
      ),
      (
        Json::object({
          "kind": Json("sqlite"),
          "rollback_as_commit": Json("yes"),
        }),
        "rollback_as_commit",
      ),
      (
        Json::object({
          "kind": Json("model"),
          "model": Json(
            @lens.Machine::new(["other"], [[{ target: 0, output: "ok", }]]),
          ),
        }),
        "alphabet",
      ),
    ] {
    expect_target_rejected(target, field)
  }
  let http = Json::object({
    "kind": Json("http"),
    "base_url": Json("http://127.0.0.1:1"),
    "reset": Json::object({ "path": Json("/reset") }),
    "close": Json::object({ "path": Json("/close") }),
    "actions": Json::object({ "x": Json::object({ "path": Json("/step") }) }),
  })
  guard http is Object(object) else { fail("target") }
  object["actions"] = Json::object({})
  expect_target_rejected(http, "actions")
  object["actions"] = Json::object({
    "x": Json::object({ "path": Json("/step"), "verb": Json("EXEC") }),
  })
  expect_target_rejected(http, "actions.x")
  object["actions"] = Json::object({
    "x": Json::object({ "path": Json("/step\r\nInjected: yes") }),
  })
  expect_target_rejected(http, "path")
  object["base_url"] = Json("http:///")
  expect_target_rejected(http, "base_url")
}

///|
test "offline validation neither executes target programs nor exposes settings" {
  let value = model_config("yes")
  guard value is Object(object) else { fail("configuration") }
  object["target"] = Json::object({
    "kind": Json("jsonl"),
    "program": Json("NONEXISTENT-stateless-validation-target"),
    "args": Json(["private-token-not-for-manifests"]),
  })
  let config = @integration.Config::from_json(value)
  let report = config.validate(operation="compare")
  guard report is { "valid": True, "operation": String("compare"), .. } else {
    fail("offline validation report")
  }
  assert_true(!report.stringify().contains("private-token-not-for-manifests"))
  assert_true(!report.stringify().contains("NONEXISTENT"))
  try config.validate(operation="unknown") catch {
    @runner.Configuration(_) => ()
    error => raise error
  } noraise {
    _ => fail("accepted unknown operation")
  }
}
