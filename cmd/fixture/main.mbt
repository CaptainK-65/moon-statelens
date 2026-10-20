///|
/// Controlled protocol fixture. Deliberate defects are not third-party bugs.
async fn main {
  let args = @env.args()
  let mode = if args.length() > 1 { args[1] } else { "session" }
  let mut logged_in = false
  while @stdio.stdin.read_until("\n") is Some(line) {
    guard @json.parse(line)
      is {
        "id": Number(id, ..),
        "method": String(operation),
        "input": String(input),
        ..
      } else {
      fail("invalid fixture request")
    }
    if mode == "crash" {
      fail("injected fixture failure")
    }
    if mode == "slow-reset" && operation == "reset" {
      @async.sleep(5000)
    }
    if mode == "slow-step" && operation == "step" {
      @async.sleep(5000)
    }
    if mode == "hang-close" && operation == "close" {
      @async.sleep(5000)
    }
    let output = match operation {
      "reset" => {
        logged_in = false
        if mode == "bad-reset" {
          "rejected"
        } else {
          "ok"
        }
      }
      "close" => "ok"
      "step" =>
        match input {
          "login" => {
            logged_in = true
            "ok"
          }
          "logout" => {
            if mode != "regression" {
              logged_in = false
            }
            "ok"
          }
          _ =>
            if mode == "fragmented" {
              "允许"
            } else if logged_in {
              "allowed"
            } else {
              "denied"
            }
        }
      _ => fail("unknown fixture method")
    }
    if mode == "stderr-flood" {
      @stdio.stderr.write("diagnostic".repeat(1024))
    }
    let reply = Json::object({
        "version": Json(1),
        "id": Json(if mode == "wrong-id" { id + 1 } else { id }),
        "ok": Json(true),
        "output": Json(output),
      }).stringify() +
      "\n"
    match mode {
      "bad-json" => @stdio.stdout.write("{invalid}\n")
      "large-frame" => @stdio.stdout.write("x".repeat(4096) + "\n")
      "fragmented" => {
        let bytes = @utf8.encode(reply[:])
        let mid = bytes.length() - 4
        @stdio.stdout.write(bytes[:mid])
        @async.pause()
        @stdio.stdout.write(bytes[mid:])
      }
      _ => @stdio.stdout.write(reply)
    }
    if mode == "extra-output" {
      @stdio.stdout.write(reply)
    }
    if operation == "close" {
      if mode == "nonzero-close" {
        fail("injected exit after ack")
      }
      return
    }
  }
}
