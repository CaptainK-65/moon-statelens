///|
/// Parsed without IO; execution never has to reinterpret unvalidated JSON.
enum TargetConfig {
  Model(@lens.Machine)
  Jsonl(String, Array[String], Int32, Int32)
  Sqlite(String, Bool)
  Http(
    String,
    @external.HttpAction,
    Map[String, @external.HttpAction],
    @external.HttpAction,
    String,
    String,
    Int32
  )
}

///|
fn program(object : Map[String, Json], default~ : String = "") -> String raise {
  let value = text(object, "program", default~)
  if value.trim().is_empty() || value.contains("\u0000") {
    raise @runner.Configuration("program must be a nonempty executable path")
  }
  value
}

///|
fn parse_http_action(
  value : Json,
  context : String,
) -> @external.HttpAction raise {
  try {
    let object = fields(value, [
      "path", "verb", "body", "output_field", "expect_status",
    ])
    let path = text(object, "path")
    let verb = text(object, "verb", default="POST")
    if !path.has_prefix("/") || path.contains("\r") || path.contains("\n") {
      raise @runner.Configuration(
        "path must start with / and contain no newlines",
      )
    }
    if !["GET", "POST", "PUT", "DELETE", "PATCH"].contains(verb) {
      raise @runner.Configuration("unsupported verb")
    }
    let status = integer(object, "expect_status", 200, max=599)
    if status > 0 && status < 100 {
      raise @runner.Configuration("expect_status must be 0 or 100..599")
    }
    {
      path,
      verb,
      body: object.get("body").unwrap_or(Json::null()),
      output_field: text(object, "output_field", default="output"),
      expect_status: status,
    }
  } catch {
    @runner.Configuration(message) =>
      raise @runner.Configuration(context + ": " + message)
    error => raise error
  }
}

///|
fn parse_target(
  value : Json,
  alphabet : Array[String],
) -> (String, TargetConfig) raise {
  guard value is Object(object) else {
    raise @runner.Configuration("expected object")
  }
  let kind = text(object, "kind")
  let target = match kind {
    "model" => {
      ignore(fields(value, ["kind", "model"]))
      let model = @lens.Machine::from_json(required(object, "model"))
      if model.alphabet() != alphabet {
        raise @runner.Configuration("model alphabet order mismatch")
      }
      Model(model)
    }
    "jsonl" => {
      ignore(
        fields(value, [
          "kind", "program", "args", "max_frame_bytes", "max_stderr_bytes",
        ]),
      )
      Jsonl(
        program(object),
        array_strings(object.get("args").unwrap_or(Json::array([]))) catch {
          _ => raise @runner.Configuration("args must be an array of strings")
        },
        integer(object, "max_frame_bytes", 1048576, min=64, max=16777216),
        integer(object, "max_stderr_bytes", 65536, max=16777216),
      )
    }
    "sqlite" => {
      ignore(fields(value, ["kind", "program", "rollback_as_commit"]))
      let mutant = match object.get("rollback_as_commit") {
        None | Some(False) => false
        Some(True) => true
        _ => raise @runner.Configuration("rollback_as_commit must be boolean")
      }
      Sqlite(program(object, default="sqlite3"), mutant)
    }
    "http" => {
      ignore(
        fields(value, [
          "kind", "base_url", "reset", "actions", "close", "session_field", "session_header",
          "max_response_bytes",
        ]),
      )
      let url = text(object, "base_url")
      let authority = match url.strip_prefix("http://") {
        Some(value) => value
        None =>
          match url.strip_prefix("https://") {
            Some(value) => value
            None =>
              raise @runner.Configuration(
                "base_url must use http:// or https://",
              )
          }
      }
      if authority.is_empty() ||
        authority.has_prefix("/") ||
        url.contains("\r") ||
        url.contains("\n") ||
        url.contains(" ") {
        raise @runner.Configuration(
          "base_url must have a nonempty authority and no whitespace",
        )
      }
      guard required(object, "actions") is Object(entries) else {
        raise @runner.Configuration("actions must be an object")
      }
      let mappings = Map([])
      for (input, action) in entries {
        if !alphabet.contains(input) {
          raise @runner.Configuration(
            "actions contains a symbol outside alphabet",
          )
        }
        mappings[input] = parse_http_action(action, "actions." + input)
      }
      if mappings.length() != alphabet.length() {
        raise @runner.Configuration("actions must cover every alphabet symbol")
      }
      let header = text(
        object,
        "session_header",
        default="X-MoonStateLens-Session",
      )
      if header.is_empty() ||
        header.contains("\r") ||
        header.contains("\n") ||
        header.contains(":") ||
        header.contains(" ") {
        raise @runner.Configuration("session_header must be an HTTP field name")
      }
      Http(
        url,
        parse_http_action(required(object, "reset"), "reset"),
        mappings,
        parse_http_action(required(object, "close"), "close"),
        text(object, "session_field"),
        header,
        integer(object, "max_response_bytes", 1048576, min=1, max=16777216),
      )
    }
    _ => raise @runner.Configuration("unknown kind")
  }
  (kind, target)
}

///|
/// Resolve lexical aliases before IO; filesystem aliases are checked in preflight.
fn artifact_path(value : String) -> String raise {
  if value.is_empty() || value.contains("\u0000") {
    raise @runner.Configuration(
      "artifacts: path must be nonempty and contain no NUL",
    )
  }
  @path.Path(value).resolve().to_string()
}

///|
/// Offline validation. It does not establish executable availability, writable
/// destinations, network reachability, reliable reset or a correct state bound.
pub fn Config::validate(
  self : Config,
  operation~ : String = "run",
) -> Json raise {
  if !["run", "compare", "replay"].contains(operation) {
    raise @runner.Configuration("operation must be run, compare or replay")
  }
  if operation == "replay" &&
    (self.artifacts.contains("model") || self.artifacts.contains("dot")) {
    raise @runner.Configuration(
      "replay artifacts support report and traces only",
    )
  }
  Json::object({
    "format": Json("moonstatelens.validation"),
    "version": Json(1),
    "valid": Json(true),
    "operation": Json(operation),
    "configuration": self.manifest(),
    "scope": Json(
      "offline structure and semantics; no target IO or filesystem permission checks",
    ),
  })
}
