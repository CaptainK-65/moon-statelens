///|
fn usage() -> String {
  let text =
    #|MoonStateLens 0.2.1
    #|Usage: moon run cmd/statelens --target native -- COMMAND
    #|  demo session|regression|lru       Learn actual adapters and print evidence
    #|  learn MODEL.json STATE_BOUND     Learn a model-backed black box using W-method
    #|  compat LEFT.json RIGHT.json BOUND Infer both behaviors and confirm differences
    #|  compare LEFT.json RIGHT.json     Exact comparison of supplied complete models
    #|  replay MODEL.json INPUTS.json    Execute a JSON array of input symbols
    #|  minimize MODEL.json              Print a minimal reachable model
    #|  dot MODEL.json                   Print a Graphviz state diagram
    #|  export session|lru OUT.json      Learn and save a model; refuses overwrite
    #|  benchmark [OUT.json]             Query-cost reference study; refuses overwrite
    #|  benchmark-algorithms             L* / KV costs under identical Wp plans
    #|  run-config CONFIG.json           Learn an actual configured component
    #|  compare-config LEFT.json RIGHT.json  Infer and freshly confirm differences
    #|  replay-config CONFIG.json WORDS.json  Freshly replay arrays of input words
    #|  validate-config CONFIG.json [run|compare|replay]  Validate without target IO
    #|  --version | --help
    #|
    #|Black-box evidence is conditional or budgeted. Equal learned models are not
    #|an unconditional equivalence proof for arbitrary implementations.
  text
}

///|
async fn main {
  let args = @env.args()
  match args {
    [_] | [_, "--help"] | [_, "help"] => println(usage())
    [_, "--version"] => println("0.2.1")
    [_, "validate-config", path] => validate_configuration(path, "run")
    [_, "validate-config", path, operation] =>
      validate_configuration(path, operation)
    [_, "run-config", path] => configuration_command("run", path, "")
    [_, "compare-config", left, right] =>
      configuration_command("compare", left, right)
    [_, "replay-config", config, words] =>
      configuration_command("replay", config, words)
    [_, "demo", "session"] =>
      println(Json(session_result()).stringify(indent=2))
    [_, "demo", "lru"] => println(Json(lru_result()).stringify(indent=2))
    [_, "demo", "regression"] =>
      println(Json(regression_result()).stringify(indent=2))
    [_, "learn", path, bound] => {
      let model = read_model(path)
      let experiment = @lens.Experiment::new(model.system(), model.alphabet())
      let result = @lens.learn(
        experiment,
        @lens.Oracle::w_method(@string.parse_int(bound)),
      )
      println(Json(result).stringify(indent=2))
    }
    [_, "compat", left_path, right_path, bound] => {
      let left = read_model(left_path)
      let right = read_model(right_path)
      let upper_bound = @string.parse_int(bound)
      let result = @lens.compare(
        @lens.Experiment::new(left.system(), left.alphabet()),
        @lens.Experiment::new(right.system(), right.alphabet()),
        @lens.Oracle::w_method(upper_bound),
        @lens.Oracle::w_method(upper_bound),
      )
      println(Json(result).stringify(indent=2))
    }
    [_, "compare", left_path, right_path] => {
      let difference = @lens.distinguish(
        read_model(left_path),
        read_model(right_path),
      )
      println(
        Json::object({
          "scope": Json("complete explicit models"),
          "difference": difference
          .map(diff => Json(diff))
          .unwrap_or(Json::null()),
        }).stringify(indent=2),
      )
    }
    [_, "replay", model_path, inputs_path] => {
      let model = read_model(model_path)
      let inputs : Array[String] = @json.from_json(
        @json.parse(read_text(inputs_path)),
      )
      if inputs.length() > 4096 {
        raise @lens.LimitExceeded("replay-word-length")
      }
      println(Json(model.trace(inputs)).stringify(indent=2))
    }
    [_, "minimize", path] => println(read_model(path).minimize().encode())
    [_, "dot", path] => println(read_model(path).to_dot())
    [_, "export", "session", path] =>
      write_new(path, session_result().model.unwrap().encode() + "\n")
    [_, "export", "lru", path] =>
      write_new(path, lru_result().model.unwrap().encode() + "\n")
    [_, "benchmark"] => println(@study.query_study().stringify(indent=2))
    [_, "benchmark-algorithms"] =>
      println(@study.algorithm_study().stringify(indent=2))
    [_, "benchmark", path] =>
      write_new(path, @study.query_study().stringify(indent=2) + "\n")
    _ => raise @lens.InvalidArgument(usage())
  }
}
