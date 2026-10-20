///|
/// Real SQLite CLI, fixed data domain and normalized transaction errors.
/// stdout/stderr share a pipe so an operation's completion marker also orders
/// its SQL diagnostics. Each physical query creates a fresh :memory: database.
pub async fn[T] with_sqlite(
  program : String,
  action : async (@runner.AsyncSystem) -> T,
  rollback_as_commit~ : Bool = false,
) -> T {
  @async.with_task_group(group => {
    let active : Array[Channel?] = [None]
    async fn execute(channel : Channel, sql : String) -> Array[String] {
      channel.serial += 1
      let marker = "MOONSTATELENS_SQL_END_" + channel.serial.to_string()
      channel.writer.write(sql + "\n.print " + marker + "\n")
      let lines = []
      let mut bytes = 0
      for ;; {
        let line = channel.line()
        if line == marker {
          return lines
        }
        bytes += line.length()
        if bytes > 1048576 {
          raise @runner.Protocol("SQLite response limit exceeded")
        }
        lines.push(line)
      }
    }
    let system = @runner.AsyncSystem::new(
      reset=() => {
        let channel = open_channel(
          group,
          program,
          ["-batch", ":memory:"],
          65536,
          0,
          merge_errors=true,
        )
        active[0] = Some(channel)
        let result = execute(
          channel, ".echo off\n.headers off\n.mode list\nCREATE TABLE state(k INTEGER PRIMARY KEY, v INTEGER);",
        )
        if !result.is_empty() {
          raise @runner.Protocol("SQLite initialization failed")
        }
      },
      step=input => {
        guard active[0] is Some(channel) else {
          raise @runner.Protocol("SQLite not started")
        }
        let sql = match input {
          "begin" => "BEGIN;"
          "put" => "INSERT OR REPLACE INTO state VALUES(1,1);"
          "delete" => "DELETE FROM state WHERE k=1;"
          "commit" => "COMMIT;"
          "rollback" => if rollback_as_commit { "COMMIT;" } else { "ROLLBACK;" }
          "read" => "SELECT COUNT(*) FROM state WHERE k=1;"
          _ => raise @lens.UnknownInput(input)
        }
        let lines = execute(channel, sql)
        if input == "read" {
          match lines {
            ["0"] => "empty"
            ["1"] => "present"
            _ => raise @runner.Protocol("unexpected SQLite query output")
          }
        } else if lines.is_empty() {
          "ok"
        } else if lines.length() == 1 &&
          (
            lines[0].contains("within a transaction") ||
            lines[0].contains("no transaction is active")
          ) {
          channel.expected_sql_error = true
          "transaction-error"
        } else {
          raise @runner.Protocol("unexpected SQLite diagnostic")
        }
      },
      close=() => {
        if active[0] is Some(channel) {
          active[0] = None
          errdefer channel.kill()
          channel.writer.write(".quit\n")
          // sqlite3 may retain a nonzero process status after an expected SQL
          // error. Operation errors were classified above; process exit remains
          // distinct from a query output.
          channel.writer.close()
          let code = channel.process.wait()
          if code != 0 && !(code == 1 && channel.expected_sql_error) {
            raise @runner.Target(
              "SQLite exited unexpectedly: " + code.to_string(),
            )
          }
          channel.closed = true
          channel.reader.close()
          channel.errors.close()
        }
      },
    )
    errdefer (if active[0] is Some(channel) {
      @async.protect_from_cancel(() => channel.kill())
    })
    action(system)
  })
}
