///|
pub(all) struct RunBudgets {
  queries : Int32
  steps : Int32
  word_length : Int32
  cache_nodes : Int32
  output_code_units : Int32
  states : Int32
  rounds : Int32
  table_cells : Int32
  table_symbols : Int32
  prefixes : Int32
  query_timeout_ms : Int32
  step_timeout_ms : Int32
  cleanup_timeout_ms : Int32
  run_timeout_ms : Int32
} derive(Debug, ToJson)

///|
pub extend RunBudgets with @debug.Debug::{to_repr}

///|
pub extend RunBudgets with ToJson::{to_json}

///|
/// Validated versioned experiment definition. Original target settings may
/// contain credentials and are deliberately excluded from public manifests.
pub struct Config {
  priv identity : String
  priv abstraction : String
  priv alphabet : Array[String]
  priv algorithm : @lens.Algorithm
  priv plan : @lens.VerificationPlan
  priv verification_json : Json
  priv target : TargetConfig
  priv kind : String
  priv budgets : RunBudgets
  priv expected_evidence : String
  priv artifacts : Map[String, String]
}

///|
fn fields(value : Json, allowed : Array[String]) -> Map[String, Json] raise {
  guard value is Object(object) else {
    raise @runner.Configuration("expected JSON object")
  }
  for (key, _) in object {
    if !allowed.contains(key) {
      raise @runner.Configuration("unknown configuration field: " + key)
    }
  }
  object
}

///|
fn required(object : Map[String, Json], key : String) -> Json raise {
  match object.get(key) {
    Some(value) => value
    None => raise @runner.Configuration("missing field: " + key)
  }
}

///|
fn text(
  object : Map[String, Json],
  key : String,
  default~ : String = "",
) -> String raise {
  match object.get(key) {
    None => default
    Some(String(value)) => value
    _ => raise @runner.Configuration("expected string: " + key)
  }
}

///|
fn integer(
  object : Map[String, Json],
  key : String,
  default : Int32,
  min~ : Int32 = 0,
  max~ : Int32 = 2147483647,
) -> Int32 raise {
  match object.get(key) {
    None => default
    Some(Number(value, ..)) => {
      if value < min.to_double() || value > max.to_double() {
        raise @runner.Configuration("out-of-range: " + key)
      }
      let number = value.to_int()
      if number.to_double() != value {
        raise @runner.Configuration("expected integer: " + key)
      }
      number
    }
    _ => raise @runner.Configuration("expected number: " + key)
  }
}

///|
fn array_strings(value : Json) -> Array[String] raise {
  @json.from_json(value) catch {
    _ => raise @runner.Configuration("expected array of strings")
  }
}

///|
fn parse_plan(value : Json, depth : Int32) -> @lens.VerificationPlan raise {
  if depth > 16 {
    raise @runner.Configuration("verification nesting too deep")
  }
  guard value is Object(object) else {
    raise @runner.Configuration("expected verification object")
  }
  let kind = text(object, "kind")
  match kind {
    "chain" => {
      ignore(fields(value, ["kind", "stages"]))
      guard required(object, "stages") is Array(stages) &&
        stages.length() > 0 &&
        stages.length() <= 64 else {
        raise @runner.Configuration("invalid verification stages")
      }
      Chain(stages.map(stage => parse_plan(stage, depth + 1)))
    }
    "exact" => {
      ignore(fields(value, ["kind", "reference"]))
      Exact(@lens.Machine::from_json(required(object, "reference")))
    }
    "replay" => {
      ignore(fields(value, ["kind", "words"]))
      guard required(object, "words") is Array(words) &&
        words.length() <= 100000 else {
        raise @runner.Configuration("invalid replay words")
      }
      Replay(words.map(word => array_strings(word)))
    }
    "random" => {
      ignore(fields(value, ["kind", "seed", "max_length", "tests"]))
      RandomWords(
        seed=integer(object, "seed", 42).reinterpret_as_uint(),
        max_length=integer(object, "max_length", 16, max=4096),
        tests=integer(object, "tests", 1000, min=1),
      )
    }
    "exhaustive" => {
      ignore(fields(value, ["kind", "depth", "max_tests"]))
      Exhaustive(
        depth=integer(object, "depth", 3, max=4096),
        max_tests=integer(object, "max_tests", 10000, min=1),
      )
    }
    "w" | "wp" => {
      ignore(fields(value, ["kind", "state_bound", "max_tests", "max_work"]))
      ignore(required(object, "state_bound"))
      let bound = integer(object, "state_bound", 0, min=1, max=4096)
      let max_tests = integer(object, "max_tests", 100000, min=1)
      let max_work = integer(object, "max_work", 1000000, min=1)
      if kind == "w" {
        WMethod(bound~, max_tests~, max_work~)
      } else {
        WpMethod(bound~, max_tests~, max_work~)
      }
    }
    _ => raise @runner.Configuration("unknown verification strategy")
  }
}

///|
pub fn Config::from_json(value : Json) -> Config raise {
  let owned = @json.parse(value.stringify())
  let object = fields(owned, [
    "format", "version", "identity", "abstraction", "alphabet", "learner", "target",
    "verification", "budgets", "expectations", "artifacts",
  ])
  if text(object, "format") != "moonstatelens.experiment" ||
    integer(object, "version", 0) != 1 {
    raise @runner.Configuration("unsupported experiment format or version")
  }
  let identity = text(object, "identity")
  let abstraction = text(object, "abstraction")
  if identity.is_empty() || abstraction.is_empty() {
    raise @runner.Configuration("identity and abstraction are required")
  }
  let alphabet = array_strings(required(object, "alphabet"))
  // Reuse core validation, without constructing a target or executing IO.
  ignore(@lens.QuerySession::new(alphabet))
  let algorithm = match text(object, "learner", default="kv") {
    "lstar" => @lens.Algorithm::LStar
    "kv" => @lens.Algorithm::KearnsVazirani
    _ => raise @runner.Configuration("unknown learner")
  }
  let (kind, target) = parse_target(required(object, "target"), alphabet) catch {
    @runner.Configuration(message) =>
      raise @runner.Configuration("target: " + message)
    @lens.InvalidArgument(message) =>
      raise @runner.Configuration("target.model: " + message)
    error => raise error
  }
  let budgets = fields(object.get("budgets").unwrap_or(Json::object({})), [
    "queries", "steps", "word_length", "cache_nodes", "output_code_units", "states",
    "rounds", "table_cells", "table_symbols", "prefixes", "query_timeout_ms", "step_timeout_ms",
    "cleanup_timeout_ms", "run_timeout_ms",
  ])
  let budget : RunBudgets = {
    queries: integer(budgets, "queries", 100000),
    steps: integer(budgets, "steps", 2000000),
    word_length: integer(budgets, "word_length", 4096, max=4096),
    cache_nodes: integer(budgets, "cache_nodes", 1000000, min=1),
    output_code_units: integer(budgets, "output_code_units", 16777216),
    states: integer(budgets, "states", 256, min=1, max=4096),
    rounds: integer(budgets, "rounds", 64, min=1),
    table_cells: integer(budgets, "table_cells", 1000000, min=1),
    table_symbols: integer(budgets, "table_symbols", 4000000, min=1),
    prefixes: integer(budgets, "prefixes", 20000, min=1),
    query_timeout_ms: integer(budgets, "query_timeout_ms", 30000, min=1),
    step_timeout_ms: integer(budgets, "step_timeout_ms", 3000, min=1),
    cleanup_timeout_ms: integer(budgets, "cleanup_timeout_ms", 1000, min=1),
    run_timeout_ms: integer(budgets, "run_timeout_ms", 120000, min=1),
  }
  let expectations = fields(
    object.get("expectations").unwrap_or(Json::object({})),
    ["evidence"],
  )
  let expected_evidence = text(
    expectations,
    "evidence",
    default="conditional-state-bound",
  )
  if !["budgeted", "conditional-state-bound", "exact-reference"].contains(
      expected_evidence,
    ) {
    raise @runner.Configuration("unknown evidence expectation")
  }
  if expected_evidence == "exact-reference" && kind != "model" {
    raise @runner.Configuration(
      "exact-reference does not certify an arbitrary external target",
    )
  }
  let artifact_fields = fields(
    object.get("artifacts").unwrap_or(Json::object({})),
    ["report", "model", "dot", "traces"],
  )
  let artifacts : Map[String, String] = Map([])
  let paths = []
  for (key, _) in artifact_fields {
    let path = text(artifact_fields, key)
    let normalized = artifact_path(path)
    if path.is_empty() || paths.contains(normalized) {
      raise @runner.Configuration("invalid or duplicate artifact path")
    }
    paths.push(normalized)
    artifacts[key] = normalized
  }
  let verification_json = required(object, "verification")
  {
    identity,
    abstraction,
    alphabet,
    algorithm,
    plan: parse_plan(verification_json, 0),
    verification_json,
    target,
    kind,
    budgets: budget,
    expected_evidence,
    artifacts,
  }
}

///|
pub fn Config::manifest(self : Config) -> Json {
  Json::object({
    "identity": Json(self.identity),
    "abstraction": Json(self.abstraction),
    "target_kind": Json(self.kind),
    "learner": Json(self.algorithm.name()),
    "alphabet": Json(self.alphabet),
    "budgets": Json(self.budgets),
    "verification": self.verification_json,
    "expected_evidence": Json(self.expected_evidence),
  })
}
