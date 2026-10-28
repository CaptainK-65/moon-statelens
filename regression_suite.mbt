///|
/// One independent reset-based experiment. Every output position is asserted.
pub(all) struct RegressionCase {
  inputs : Array[String]
  expected : Array[String]
} derive(Debug, Eq, ToJson, @json.FromJson)

///|
pub extend RegressionCase with ToJson::{to_json}

///|
pub extend RegressionCase with @debug.Debug::{to_repr}

///|
pub extend RegressionCase with Eq::{equal, not_equal}

///|
pub extend RegressionCase with @json.FromJson::{from_json}

///|
/// Validated, owned suite. Only completed W/Wp generation carries a conditional
/// state-bound claim; state/transition profiles provide model coverage only.
pub struct RegressionSuite {
  priv model : Machine
  priv profile : String
  priv bound : Int32
  priv complete : Bool
  priv cases : Array[RegressionCase]
  priv generated : Int32
  priv max_candidates : Int32
  priv max_symbols : Int32
  priv max_work : Int32
}

///|
/// Generate deterministic suites; truncation is explicit, never a proof.
pub fn Machine::regression_suite(
  self : Machine,
  profile~ : String = "wp",
  state_bound? : Int32,
  max_candidates~ : Int32 = 100000,
  max_symbols~ : Int32 = 2000000,
  max_work~ : Int32 = 1000000,
) -> RegressionSuite raise {
  if !["state", "transition", "w", "wp"].contains(profile) ||
    max_candidates < 1 ||
    max_candidates > 100000 ||
    max_symbols < 1 ||
    max_symbols > 2000000 ||
    max_work < 1 ||
    max_work > 100000000 {
    raise InvalidArgument("invalid regression suite profile or budget")
  }
  let model = self.minimize()
  let bound = state_bound.unwrap_or(model.state_count())
  if bound < model.state_count() || bound > 4096 {
    raise InvalidArgument("suite state bound below minimal model or above 4096")
  }
  let basic = []
  for (_, word) in model.access_sequences() {
    basic.push(word)
    if profile == "transition" {
      for input in model.alphabet {
        basic.push(word + [input])
      }
    }
  }
  let cursor = if profile == "w" || profile == "wp" {
    Some(
      ConformanceWords::new(
        model,
        bound,
        use_identifiers=profile == "wp",
        max_work~,
      ),
    )
  } else {
    None
  }
  let seen : Map[Array[String], Unit] = Map([])
  let cases = []
  let mut generated = 0
  let mut symbols = 0
  let mut complete = true
  for ;; {
    let next = match cursor {
      Some(cursor) => cursor.next()
      None => basic.get(generated)
    }
    guard next is Some(word) else { break }
    if generated >= max_candidates ||
      word.length() > 4096 ||
      word.length() > max_symbols - symbols {
      complete = false
      break
    }
    generated += 1
    // Count generated symbols even for duplicates, bounding generation work.
    symbols += word.length()
    if !seen.contains(word) {
      seen[word] = ()
      cases.push({ inputs: word.copy(), expected: model.trace(word), })
    }
  }
  {
    model,
    profile,
    bound,
    complete,
    cases,
    generated,
    max_candidates,
    max_symbols,
    max_work,
  }
}

///|
pub fn RegressionSuite::cases(self : RegressionSuite) -> Array[RegressionCase] {
  self.cases.map(c => { inputs: c.inputs.copy(), expected: c.expected.copy(), })
}

///|
pub fn RegressionSuite::is_complete(self : RegressionSuite) -> Bool {
  self.complete
}

///|
/// Coverage counts reachable model states/edges visited by the original suite.
pub fn RegressionSuite::coverage(self : RegressionSuite) -> Json {
  let states : Map[Int32, Unit] = Map([])
  let edges : Map[(Int32, Int32), Unit] = Map([])
  for c in self.cases {
    let mut state = self.model.initial
    states[state] = ()
    for input in c.inputs {
      let column = self.model.alphabet.search(input).unwrap()
      edges[(state, column)] = ()
      state = self.model.transitions[state][column].target
      states[state] = ()
    }
  }
  Json::object({
    "scope": Json("reachable model coverage, not implementation code coverage"),
    "states_visited": Json(states.length()),
    "states_total": Json(self.model.state_count()),
    "transitions_visited": Json(edges.length()),
    "transitions_total": Json(
      self.model.state_count() * self.model.alphabet.length(),
    ),
  })
}

///|
pub fn RegressionSuite::evidence(self : RegressionSuite) -> Json {
  Json::object({
    "generation_complete": Json(self.complete),
    "profile": Json(self.profile),
    "state_bound": Json(self.bound),
    "conditional_conformance": Json(
      self.complete && ["w", "wp"].contains(self.profile),
    ),
    "assumptions": Json(
      "deterministic total resettable Mealy target, same alphabet, actual states <= bound; suite must pass completely",
    ),
    "coverage": self.coverage(),
  })
}

///|
pub impl ToJson for RegressionSuite with fn to_json(self) {
  Json::object({
    "format": Json("moonstatelens.regression-suite"),
    "version": Json(1),
    "model": Json(self.model),
    "profile": Json(self.profile),
    "state_bound": Json(self.bound),
    "max_candidates": Json(self.max_candidates),
    "max_symbols": Json(self.max_symbols),
    "max_work": Json(self.max_work),
    "cases": Json(self.cases),
    "generated_candidates": Json(self.generated),
    "evidence": self.evidence(),
  })
}

///|
pub extend RegressionSuite with ToJson::{to_json}

///|
priv struct SuiteDocument {
  format : String
  version : Int32
  model : Json
  profile : String
  state_bound : Int32
  max_candidates : Int32
  max_symbols : Int32
  max_work : Int32
  cases : Array[RegressionCase]
  generated_candidates : Int32
  evidence : Json
} derive(@json.FromJson)

///|
/// Recompute the generator and evidence instead of trusting imported claims.
pub fn RegressionSuite::from_json(value : Json) -> RegressionSuite raise {
  if value.stringify().length() > 16777216 {
    raise LimitExceeded("suite-json-length")
  }
  let d : SuiteDocument = @json.from_json(value)
  if d.format != "moonstatelens.regression-suite" || d.version != 1 {
    raise InvalidArgument("unsupported regression suite")
  }
  let suite = Machine::from_json(d.model).regression_suite(
    profile=d.profile,
    state_bound=d.state_bound,
    max_candidates=d.max_candidates,
    max_symbols=d.max_symbols,
    max_work=d.max_work,
  )
  if suite.cases != d.cases ||
    suite.generated != d.generated_candidates ||
    suite.evidence() != d.evidence {
    raise InvalidArgument("suite assertions or evidence do not match generator")
  }
  suite
}
