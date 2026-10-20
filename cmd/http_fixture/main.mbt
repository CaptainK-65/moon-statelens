///|
/// Independent controlled test service; not evidence of third-party defects.
async fn main {
  let args = @env.args()
  let port = if args.length() > 1 { @string.parse_int(args[1]) } else { 41080 }
  let mode = if args.length() > 2 { args[2] } else { "session" }
  let server = @http.Server::Server(
    @socket.Addr::parse("127.0.0.1:" + port.to_string()),
  )
  defer server.close()
  let sessions : Map[String, Bool] = Map([])
  let serial = [0]
  @stdio.stdout.write(
    "http://127.0.0.1:" + server.addr.port().to_string() + "\n",
  )
  server.run_forever((request, body, connection) => {
    let data = body.read_all().json()
    let token = request.headers.get(
      @http.CaseInsensitiveString("X-MoonStateLens-Session"),
    )
    let reply = match request.path {
      "/reset" => {
        serial[0] += 1
        let session = serial[0].to_string()
        sessions[session] = false
        Json::object({ "output": Json("ok"), "session": Json(session) })
      }
      "/close" => {
        if token is Some(value) {
          sessions.remove(value) |> ignore
        }
        Json::object({ "output": Json("ok") })
      }
      "/step" => {
        guard token is Some(value) && sessions.get(value) is Some(logged) else {
          fail("unknown fixture session")
        }
        guard data is { "input": String(input), .. } else {
          fail("invalid fixture action")
        }
        if mode == "slow" {
          @async.sleep(5000)
        }
        let output = match input {
          "login" => {
            sessions[value] = true
            "ok"
          }
          "logout" => {
            if mode != "regression" {
              sessions[value] = false
            }
            "ok"
          }
          _ => if logged { "allowed" } else { "denied" }
        }
        Json::object({ "output": Json(output) })
      }
      _ => Json::object({ "output": Json("unknown-route") })
    }
    connection.send_response(200, "OK")
    connection.write(reply)
    connection.end_response()
  })
}
