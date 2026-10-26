///|
extern "C" fn status_exit(code : Int32) = "exit"

///|
fn config(mutant : Bool) -> @integration.Config raise {
  @integration.Config::from_json(Json::object({
    "format": Json("moonstatelens.experiment"), "version": Json(1),
    "identity": Json(if mutant { "CONTROLLED-rollback-as-commit" } else { "sqlite-normal" }),
    "abstraction": Json("single-row-sqlite-transactions-v1"),
    "alphabet": Json(["begin", "put", "delete", "commit", "rollback", "read"]),
    "learner": Json("kv"),
    "target": Json::object({
      "kind": Json("sqlite"), "program": Json("sqlite3"),
      "rollback_as_commit": Json(mutant),
    }),
    "verification": Json::object({
      "kind": Json("wp"), "state_bound": Json(6), "max_tests": Json(10000),
    }),
    "expectations": Json::object({ "evidence": Json("conditional-state-bound") }),
  }))
}

///|
/// A six-state bound is a premise for this documented finite abstraction.
async fn gate(directory : String, mutant : Bool) -> Int32 {
  @fs.mkdir(directory, recursive=true)
  let left = config(false)
  let right = config(mutant)
  let result = @integration.compare(left, right)
  @fs.write_file(directory + "/comparison.json", result.report.stringify(indent=2) + "\n",
    create_mode=CreateNew)
  let words = match result.report {
    { "status": { "kind": "confirmed-difference",
        "difference": { "inputs": Array(inputs), .. }, .. }, .. } => {
      let inputs : Array[String] = inputs.map(input => match input {
        String(value) => value
        _ => fail("invalid input symbol")
      })
      [inputs]
    }
    _ => [["begin", "put", "rollback", "read"]]
  }
  @fs.write_file(directory + "/counterexample-words.json", Json(words).stringify(indent=2) + "\n",
    create_mode=CreateNew)
  let replayed_left = @integration.replay(left, words)
  let replayed_right = @integration.replay(right, words)
  @fs.write_file(directory + "/left-replay.json", replayed_left.stringify(indent=2) + "\n",
    create_mode=CreateNew)
  @fs.write_file(directory + "/right-replay.json", replayed_right.stringify(indent=2) + "\n",
    create_mode=CreateNew)
  let verdict = match result.exit_code {
    0 => "Evidence policy met; learned models agree under the stated assumptions"
    2 => "Difference confirmed by fresh execution on both targets"
    _ => "Insufficient evidence; manual investigation required"
  }
  let summary = "# SQLite behavioral gate\n\n" + verdict + "\n\n" +
    "- Exit code: " + result.exit_code.to_string() + "\n" +
    "- Scope: deterministic single-row transaction abstraction, state bound 6.\n" +
    "- Mutation is deliberately injected in the adapter; this is not a SQLite defect claim.\n" +
    "- Reports, replay inputs and actual replay outputs are saved beside this file.\n"
  @fs.write_file(directory + "/SUMMARY.md", summary, create_mode=CreateNew)
  if @env.get_env_var("GITHUB_STEP_SUMMARY") is Some(path) {
    @fs.write_file(path, summary, append=true)
  }
  println(result.report.stringify(indent=2))
  result.exit_code
}

///|
async fn main {
  let args = @env.args()
  let (directory, mutant) = match args {
    [_, directory] => (directory, false)
    [_, directory, "--controlled-mutation"] => (directory, true)
    _ => fail("usage: moon run . -- EVIDENCE_DIRECTORY [--controlled-mutation]")
  }
  let code = try gate(directory, mutant) catch {
    _ => {
      println("{\"kind\":\"execution-error\",\"message\":\"check SQLite, configuration and output directory\"}")
      1
    }
  }
  // compare/replay have completed scoped cleanup before process exit.
  if code != 0 { status_exit(code) }
}
