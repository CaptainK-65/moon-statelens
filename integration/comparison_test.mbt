///|
async test "different approximate hypotheses cannot become a confirmed component difference" {
  let model = @lens.Machine::new(["x"], [
    [{ target: 1, output: "a", }],
    [{ target: 0, output: "b", }],
  ])
  fn config(learner) -> @integration.Config raise {
    @integration.Config::from_json(
      Json::object({
        "format": Json("moonstatelens.experiment"),
        "version": Json(1),
        "identity": Json("same-target-" + learner),
        "abstraction": Json("alternating-v1"),
        "alphabet": Json(["x"]),
        "learner": Json(learner),
        "target": Json::object({ "kind": Json("model"), "model": Json(model) }),
        "verification": Json::object({
          "kind": Json("exhaustive"),
          "depth": Json(0),
        }),
        "expectations": Json::object({ "evidence": Json("budgeted") }),
      }),
    )
  }
  let limited = @integration.compare(
    config("lstar"),
    config("kv"),
    max_refinements=0,
  )
  assert_eq(limited.exit_code, 3)
  let refined = @integration.compare(config("lstar"), config("kv"))
  assert_eq(refined.exit_code, 0)
  guard refined.report is { "spurious_inputs": Array(words), .. } else {
    fail("report")
  }
  assert_true(words.length() > 0)
}
