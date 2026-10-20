///|
async test "actual HTTP socket service supports independent sessions and model learning" {
  let server = @http.Server::Server(@socket.Addr::parse("127.0.0.1:0"))
  defer server.close()
  let base = "http://127.0.0.1:" + server.addr.port().to_string()
  let sessions : Map[String, Bool] = Map([])
  let serial = [0]
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((request, body, connection) => {
        let data = body.read_all().json()
        let token = request.headers.get(
          @http.CaseInsensitiveString("X-MoonStateLens-Session"),
        )
        let reply = match request.path {
          "/reset" => {
            serial[0] += 1
            let value = serial[0].to_string()
            sessions[value] = false
            Json::object({ "output": Json("ok"), "session": Json(value) })
          }
          "/close" => {
            if token is Some(value) {
              sessions.remove(value) |> ignore
            }
            Json::object({ "output": Json("ok") })
          }
          _ => {
            guard token is Some(value) && sessions.get(value) is Some(logged) else {
              fail("missing test session")
            }
            guard data is { "input": String(action), .. } else {
              fail("missing action")
            }
            let output = match action {
              "login" => {
                sessions[value] = true
                "ok"
              }
              "logout" => {
                sessions[value] = false
                "ok"
              }
              _ => if logged { "allowed" } else { "denied" }
            }
            Json::object({ "output": Json(output) })
          }
        }
        connection.send_response(200, "OK")
        connection.write(reply)
        connection.end_response()
      })
    })
    fn action(path, body) -> @external.HttpAction {
      { path, verb: "POST", body, output_field: "output", expect_status: 200, }
    }
    let actions = Map::from_iter(
      ["login", "logout", "request"]
      .iter()
      .map(input => {
        (input, action("/step", Json::object({ "input": Json(input) })))
      }),
    )
    let system = @external.http_system(
      base,
      action("/reset", Json::object({})),
      actions,
      action("/close", Json::object({})),
      session_field="session",
    )
    let experiment = @runner.AsyncExperiment::new(system, [
      "login", "logout", "request",
    ])
    let report = @runner.infer(
      experiment,
      WpMethod(bound=2, max_tests=1000, max_work=10000),
      algorithm=KearnsVazirani,
    )
    assert_true(report.learning.status is Supported(ConditionalStateBound(2)))
    assert_eq(report.learning.model.unwrap().state_count(), 2)
    assert_eq(
      report.learning.model.unwrap().trace(["login", "logout", "request"]),
      ["ok", "ok", "denied"],
    )
    assert_true(sessions.is_empty())
  })
}

///|
async test "HTTP rejects oversized bodies and non-JSON output without learning from transport failures" {
  let server = @http.Server::Server(@socket.Addr::parse("127.0.0.1:0"))
  defer server.close()
  let base = "http://127.0.0.1:" + server.addr.port().to_string()
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((_, body, connection) => {
        ignore(body.read_all())
        connection.send_response(200, "OK")
        connection.write("x".repeat(200))
        connection.end_response()
      })
    })
    let action : @external.HttpAction = {
      path: "/",
      verb: "POST",
      body: Json::object({}),
      output_field: "output",
      expect_status: 200,
    }
    let system = @external.http_system(
      base,
      action,
      Map([("x", action)]),
      action,
      max_response_bytes=32,
    )
    let experiment = @runner.AsyncExperiment::new(system, ["x"])
    try experiment.query(["x"]) catch {
      @runner.Protocol(_) => ()
      error => raise error
    } noraise {
      _ => fail("accepted oversized HTTP response")
    }
    assert_eq(experiment.statistics().completed_queries, 0)
    assert_eq(experiment.statistics().cache_nodes, 1)
  })
}
