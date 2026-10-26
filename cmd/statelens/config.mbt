///|
/// Only invoked after all scoped async target cleanup has completed.
extern "C" fn status_exit(code : Int32) = "exit"

///|
async fn configuration(path : String) -> @integration.Config {
  let contents = read_text(path)
  let value = @json.parse(contents) catch {
    _ => raise @runner.Configuration("invalid experiment JSON")
  }
  @integration.Config::from_json(value)
}

///|
fn configuration_error(error : Error) -> Json {
  let (kind, message) = match error {
    @runner.Configuration(message) => ("configuration-error", message)
    @runner.Protocol(message) => ("protocol-error", message)
    @runner.Target(message) => ("target-error", message)
    @runner.TimedOut(message) => ("timeout", message)
    @runner.Transport(message) => ("transport-error", message)
    @lens.InvalidArgument(message) => ("configuration-error", message)
    @lens.UnknownInput(message) =>
      ("configuration-error", "unknown input: " + message)
    @lens.LimitExceeded(message) => ("resource-limit", message)
    _ =>
      (
        "execution-error", "IO or runtime failure; check component availability and configuration",
      )
  }
  Json::object({
    "format": Json("moonstatelens.failure"),
    "version": Json(2),
    "kind": Json(kind),
    "message": Json(message),
  })
}

///|
async fn validate_configuration(path : String, operation : String) -> Unit {
  let report = configuration(path).validate(operation~) catch {
    error => {
      println(configuration_error(error).stringify(indent=2))
      status_exit(1)
      return
    }
  }
  println(report.stringify(indent=2))
}

///|
async fn configuration_command(
  operation : String,
  first : String,
  second : String,
) -> Unit {
  let result : @integration.RunResult = try {
    let config = configuration(first)
    match operation {
      "run" => @integration.run(config)
      "compare" => @integration.compare(config, configuration(second))
      "replay" => {
        let words : Array[Array[String]] = @json.from_json(
          @json.parse(read_text(second)),
        )
        { report: @integration.replay(config, words), exit_code: 0, }
      }
      _ => raise @runner.Configuration("unknown configuration operation")
    }
  } catch {
    error => {
      println(configuration_error(error).stringify(indent=2))
      status_exit(1)
      return
    }
  }
  println(result.report.stringify(indent=2))
  if result.exit_code != 0 {
    status_exit(result.exit_code)
  }
}
