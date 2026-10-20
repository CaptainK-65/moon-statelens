///|
/// Finite literal request mapping; dynamic sessions are carried in one header.
/// Output abstraction selects one top-level JSON scalar or the HTTP status.
pub(all) struct HttpAction {
  path : String
  verb : String
  body : Json
  output_field : String
  expect_status : Int32
}

///|
fn http_verb(verb : String) -> @http.RequestMethod raise {
  match verb {
    "GET" => Get
    "POST" => Post
    "PUT" => Put
    "DELETE" => Delete
    "PATCH" => Patch
    _ => raise @runner.Configuration("unsupported HTTP verb")
  }
}

///|
async fn send_http(
  base_url : String,
  action : HttpAction,
  headers : @http.Headers,
  max_response_bytes : Int32,
) -> (String, Json) {
  if !action.path.has_prefix("/") ||
    action.path.contains("\r") ||
    action.path.contains("\n") {
    raise @runner.Configuration(
      "HTTP paths must be absolute and contain no newlines",
    )
  }
  let verb = http_verb(action.verb)
  let client = @http.Client::Client(base_url)
  defer client.close()
  client.request(verb, action.path, extra_headers=headers)
  if action.body != Json::null() {
    client.write(action.body)
  }
  let response = client.end_request()
  if response.code != action.expect_status {
    raise @runner.Target("unexpected HTTP status " + response.code.to_string())
  }
  let bytes : Array[Byte] = []
  while client.read_some(max_len=4096) is Some(chunk) {
    if chunk.length() > max_response_bytes - bytes.length() {
      raise @runner.Protocol("HTTP response limit exceeded")
    }
    for byte in chunk {
      bytes.push(byte)
    }
  }
  let body = if bytes.is_empty() {
    Json::null()
  } else {
    @json.parse(@utf8.decode(Bytes::from_array(bytes)[:]))
  }
  if action.output_field.is_empty() {
    return ("status:" + response.code.to_string(), body)
  }
  guard body is Object(fields) && fields.get(action.output_field) is Some(value) else {
    raise @runner.Protocol("missing HTTP output field")
  }
  let output = match value {
    String(s) => s
    Number(_, ..) | True | False | Null => value.stringify()
    _ => raise @runner.Protocol("HTTP output must be a scalar")
  }
  (output, body)
}

///|
/// No automatic retry of state-changing requests. Reset must create the same
/// observable initial state. A session token is opaque transport state only.
pub fn http_system(
  base_url : String,
  reset : HttpAction,
  actions : Map[String, HttpAction],
  close : HttpAction,
  session_field~ : String = "",
  session_header~ : String = "X-MoonStateLens-Session",
  max_response_bytes~ : Int32 = 1048576,
) -> @runner.AsyncSystem raise {
  if max_response_bytes < 1 ||
    max_response_bytes > 16777216 ||
    actions.is_empty() {
    raise @runner.Configuration("invalid HTTP limits or actions")
  }
  let mappings = Map::from_iter(actions.iter())
  let token : Array[String?] = [None]
  fn headers() {
    let headers : @http.Headers = Map([
      (@http.CaseInsensitiveString("Content-Type"), "application/json"),
    ])
    if token[0] is Some(value) {
      headers[@http.CaseInsensitiveString(session_header)] = value
    }
    headers
  }
  @runner.AsyncSystem::new(
    reset=() => {
      token[0] = None
      let (output, body) = send_http(
        base_url,
        reset,
        headers(),
        max_response_bytes,
      )
      if output != "ok" {
        raise @runner.Protocol("HTTP reset rejected")
      }
      if !session_field.is_empty() {
        guard body is Object(fields) &&
          fields.get(session_field) is Some(String(value)) else {
          raise @runner.Protocol("missing HTTP session token")
        }
        token[0] = Some(value)
      }
    },
    step=input => {
      guard mappings.get(input) is Some(action) else {
        raise @lens.UnknownInput(input)
      }
      send_http(base_url, action, headers(), max_response_bytes).0
    },
    close=() => {
      let (output, _) = send_http(
        base_url,
        close,
        headers(),
        max_response_bytes,
      )
      token[0] = None
      if output != "ok" {
        raise @runner.Protocol("HTTP cleanup rejected")
      }
    },
  )
}
