///|
test "offline HTML keeps hostile target labels inert and JUnit gates incomplete evidence" {
  let hostile = "</pre><script>alert('x')</script>&\""
  let html = @lens.evidence_html(Json::object({ "format": Json(hostile) }))
  assert_false(html.contains(hostile))
  assert_true(html.contains("&lt;/pre&gt;"))
  assert_false(html.contains("innerHTML"))
  let model = @lens.Machine::new(["x"], [[{ target: 0, output: hostile, }]])
  let good = model
    .regression_suite()
    .plan()
    .run(@lens.Experiment::new(model.system(), ["x"]))
  let xml = @lens.regression_junit(good)
  assert_true(xml.contains("failures=\"0\""))
  let pending = model
    .regression_suite()
    .plan()
    .run(@lens.Experiment::new(model.system(), ["x"], max_queries=0))
  let incomplete = @lens.regression_junit(pending)
  assert_true(incomplete.contains("failures=\"1\""))
  assert_true(incomplete.contains("complete-evidence"))
}
