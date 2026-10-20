///|
test "detached session validates lifecycle and never commits partial output" {
  let session = @lens.QuerySession::new(["x"])
  let request = match session.start(["x"]) {
    Execute(request) => request
    _ => fail("missing request")
  }
  expect_invalid(() => ignore(session.commit(request.id)))
  expect_invalid(() => ignore(session.accept_output(request.id, "bad")))
  session.reset_started(request.id)
  session.step_started(request.id)
  session.accept_output(request.id, "ok")
  expect_invalid(() => ignore(session.commit(request.id + 1)))
  session.abort(request.id)
  assert_eq(session.statistics().completed_queries, 0)
  assert_eq(session.statistics().cache_nodes, 1)
}

///|
test "detached requests copy inputs and old ids cannot abort newer work" {
  let session = @lens.QuerySession::new(["x"])
  let first = match session.start(["x"]) {
    Execute(r) => r
    _ => fail("request")
  }
  first.inputs.clear()
  session.abort(first.id)
  let second = match session.start(["x"]) {
    Execute(r) => r
    _ => fail("request")
  }
  session.abort(first.id)
  session.reset_started(second.id)
  session.step_started(second.id)
  session.accept_output(second.id, "ok")
  assert_eq(session.commit(second.id), ["ok"])
  assert_true(session.start(["x"]) is Cached(["ok"]))
}
