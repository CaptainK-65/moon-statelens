///|
/// Artifacts are part of the operation contract, including confirmed differences.
async test "comparison and replay persist their declared artifacts" {
  let dir = @fs.tmpdir(prefix="moonstatelens-artifacts-")
  defer @fs.rmdir(dir, recursive=true)
  let left = model_config("yes")
  let right = model_config("no")
  for (value, side) in [(left, "left"), (right, "right")] {
    guard value is Object(object) else { fail("configuration") }
    object["artifacts"] = Json::object({
      "report": Json(dir + "/" + side + ".json"),
      "model": Json(dir + "/" + side + "-model.json"),
      "dot": Json(dir + "/" + side + ".dot"),
      "traces": Json(dir + "/" + side + "-traces.json"),
    })
  }
  let result = @integration.compare(
    @integration.Config::from_json(left),
    @integration.Config::from_json(right),
  )
  assert_eq(result.exit_code, 2)
  for side in ["left", "right"] {
    assert_eq(@fs.read_file(dir + "/" + side + ".json").json(), result.report)
    let learned = @lens.Machine::from_json(
      @fs.read_file(dir + "/" + side + "-model.json").json(),
    )
    assert_eq(learned.trace(["x"]), [if side == "left" { "yes" } else { "no" }])
    assert_true(
      @fs.read_file(dir + "/" + side + ".dot").text().contains("digraph"),
    )
    guard @fs.read_file(dir + "/" + side + "-traces.json").json()
      is { "entries": Array(entries), .. } &&
      entries.length() > 0 else {
      fail("missing fresh comparison traces")
    }
  }
  let replay = model_config("yes")
  guard replay is Object(object) else { fail("configuration") }
  object["artifacts"] = Json::object({
    "report": Json(dir + "/replay.json"),
    "traces": Json(dir + "/replay-traces.json"),
  })
  let replayed = @integration.replay(@integration.Config::from_json(replay), [
    ["x", "x"],
  ])
  assert_eq(@fs.read_file(dir + "/replay.json").json(), replayed)
  guard @fs.read_file(dir + "/replay-traces.json").json()
    is { "entries": Array(entries), .. } &&
    entries.length() == 1 else {
    fail("missing replay query trace")
  }
}

///|
async test "artifact conflicts and unsupported replay outputs fail before target IO" {
  let dir = @fs.tmpdir(prefix="moonstatelens-conflicts-")
  defer @fs.rmdir(dir, recursive=true)
  let left = model_config("yes")
  let right = model_config("no")
  for (value, name) in [(left, "/shared.json"), (right, "/./shared.json")] {
    guard value is Object(object) else { fail("configuration") }
    object["target"] = Json::object({
      "kind": Json("jsonl"),
      "program": Json("NONEXISTENT-artifact-preflight-target"),
    })
    object["artifacts"] = Json::object({ "report": Json(dir + name) })
  }
  try
    @integration.compare(
      @integration.Config::from_json(left),
      @integration.Config::from_json(right),
    )
  catch {
    @runner.Configuration(message) => assert_true(message.contains("alias"))
    error => raise error
  } noraise {
    _ => fail("accepted conflicting comparison destinations")
  }
  @fs.write_file(dir + "/shared.json", "keep")
  try @integration.run(@integration.Config::from_json(left)) catch {
    @runner.Configuration(message) =>
      assert_true(message.contains("already exists"))
    error => raise error
  } noraise {
    _ => fail("accepted existing output")
  }
  assert_eq(@fs.read_file(dir + "/shared.json").text(), "keep")
  guard right is Object(object) else { fail("configuration") }
  object["artifacts"] = Json::object({
    "model": Json(dir + "/unused-model.json"),
  })
  let unsupported = @integration.Config::from_json(right)
  try @integration.replay(unsupported, [["x"]]) catch {
    @runner.Configuration(message) =>
      assert_true(message.contains("replay artifacts"))
    error => raise error
  } noraise {
    _ => fail("silently ignored replay model artifact")
  }
  object["artifacts"] = Json::object({
    "report": Json(dir + "/missing-directory/out.json"),
  })
  try @integration.run(@integration.Config::from_json(right)) catch {
    @runner.Configuration(message) =>
      assert_true(message.contains("parent directory"))
    error => raise error
  } noraise {
    _ => fail("accepted missing output parent before target IO")
  }
}

///|
test "configuration rejects lexical artifact aliases" {
  let value = model_config("yes")
  guard value is Object(object) else { fail("configuration") }
  object["artifacts"] = Json::object({
    "report": Json("out.json"),
    "traces": Json("./out.json"),
  })
  try @integration.Config::from_json(value) catch {
    @runner.Configuration(_) => ()
    error => raise error
  } noraise {
    _ => fail("accepted lexical aliases")
  }
}
