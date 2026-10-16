///|
priv struct ModelDocument {
  format : String
  version : Int32
  alphabet : Array[String]
  initial : Int32
  transitions : Array[Array[Transition]]
} derive(@json.FromJson)

///|
pub impl ToJson for Machine with fn to_json(self) {
  Json::object({
    "format": Json("moonstatelens.mealy"),
    "version": Json(1),
    "alphabet": Json(self.alphabet),
    "initial": Json(self.initial),
    "transitions": Json(self.transitions),
  })
}

///|
pub extend Machine with ToJson::{to_json}

///|
/// Decode a versioned complete model, then apply all constructor invariants.
pub fn Machine::from_json(value : Json) -> Machine raise {
  let document : ModelDocument = @json.from_json(value)
  if document.format != "moonstatelens.mealy" || document.version != 1 {
    raise InvalidArgument("unsupported model format or version")
  }
  Machine::new(
    document.alphabet,
    document.transitions,
    initial=document.initial,
  )
}

///|
/// Parse a bounded JSON document (limit counts UTF-16 code units, not bytes).
pub fn decode_model(
  text : String,
  max_code_units~ : Int32 = 16777216,
) -> Machine raise {
  if max_code_units < 1 {
    raise InvalidArgument("JSON text limit must be positive")
  }
  if text.length() > max_code_units {
    raise LimitExceeded("model-json-length")
  }
  Machine::from_json(@json.parse(text))
}

///|
/// Encode a model in the versioned interchange format.
pub fn Machine::encode(self : Machine) -> String {
  Json(self).stringify(indent=2)
}

///|
pub impl ToJson for LearningResult with fn to_json(self) {
  Json::object({
    "format": Json("moonstatelens.learning"),
    "version": Json(1),
    "model": Json(self.model),
    "status": Json(self.status),
    "statistics": Json(self.statistics),
    "rounds": Json(self.rounds),
    "counterexamples": Json(self.counterexamples),
  })
}

///|
pub extend LearningResult with ToJson::{to_json}

///|
/// DOT uses quoted JSON string escapes for textual labels, so quotes,
/// backslashes and line breaks cannot escape into graph statements.
pub fn Machine::to_dot(self : Machine) -> String {
  let lines = [
    "digraph Mealy {",
    "  rankdir=LR;",
    "  start [shape=point];",
    "  start -> s" + self.initial.to_string() + ";",
  ]
  for state, row in self.transitions {
    lines.push(
      "  s" +
      state.to_string() +
      " [label=" +
      Json("q" + state.to_string()).stringify() +
      "];",
    )
    for column, edge in row {
      let label = self.alphabet[column] + " / " + edge.output
      lines.push(
        "  s" +
        state.to_string() +
        " -> s" +
        edge.target.to_string() +
        " [label=" +
        Json(label).stringify() +
        "];",
      )
    }
  }
  lines.push("}")
  lines.join("\n") + "\n"
}
