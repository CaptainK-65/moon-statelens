///|
/// Rules match successful observable input/output events, not input names alone.
pub(all) struct RuleEvent {
  input : String
  output : String
} derive(Debug, Eq, ToJson, @json.FromJson)

///|
pub extend RuleEvent with ToJson::{to_json}

///|
pub extend RuleEvent with @debug.Debug::{to_repr}

///|
pub extend RuleEvent with Eq::{equal, not_equal}

///|
pub extend RuleEvent with @json.FromJson::{from_json}

///|
/// A two-state safety monitor. On one step: release, trigger, then prohibition.
/// Thus a successful release cancels a prohibition on that same step unless the
/// step also matches the trigger. These are finite safety rules, not full LTL.
pub struct BehaviorRule {
  priv id : String
  priv kind : String
  priv forbidden : RuleEvent
  priv trigger : RuleEvent?
  priv release : RuleEvent?
}

///|
/// kind is forbidden, after, or until. after/until require trigger; until also
/// requires release. after/until start inactive after reset.
pub fn BehaviorRule::new(
  id : String,
  forbidden : RuleEvent,
  kind~ : String = "forbidden",
  trigger? : RuleEvent,
  release? : RuleEvent,
) -> BehaviorRule raise LensError {
  if id.is_empty() ||
    !["forbidden", "after", "until"].contains(kind) ||
    (kind == "forbidden" && (trigger is Some(_) || release is Some(_))) ||
    (kind != "forbidden" && trigger is None) ||
    (kind == "after" && release is Some(_)) ||
    (kind == "until" && release is None) {
    raise InvalidArgument("invalid finite behavior rule")
  }
  { id, kind, forbidden, trigger, release, }
}

///|
priv struct RuleDocument {
  id : String
  kind : String
  forbidden : RuleEvent
  trigger : RuleEvent?
  release : RuleEvent?
} derive(@json.FromJson)

///|
pub fn BehaviorRule::from_json(value : Json) -> BehaviorRule raise {
  guard value is Object(fields) else {
    raise InvalidArgument("rule must be an object")
  }
  for (key, _) in fields {
    if !["id", "kind", "forbidden", "trigger", "release"].contains(key) {
      raise InvalidArgument("unknown rule field: " + key)
    }
  }
  let d : RuleDocument = @json.from_json(value)
  BehaviorRule::new(
    d.id,
    d.forbidden,
    kind=d.kind,
    trigger?=d.trigger,
    release?=d.release,
  )
}

///|
pub impl ToJson for BehaviorRule with fn to_json(self) {
  Json::object({
    "id": Json(self.id),
    "kind": Json(self.kind),
    "forbidden": Json(self.forbidden),
    "trigger": self.trigger.map(e => Json(e)).unwrap_or(Json::null()),
    "release": self.release.map(e => Json(e)).unwrap_or(Json::null()),
  })
}

///|
pub extend BehaviorRule with ToJson::{to_json}

///|
fn BehaviorRule::advance(
  self : BehaviorRule,
  active : Bool,
  event : RuleEvent,
) -> (Bool, Bool) {
  let mut enabled = active
  if self.release == Some(event) {
    enabled = false
  }
  if self.trigger == Some(event) {
    enabled = true
  }
  (enabled, enabled && event == self.forbidden)
}

///|
/// First violating output position in a complete actual trace, starting at reset.
pub fn BehaviorRule::check_trace(
  self : BehaviorRule,
  inputs : Array[String],
  outputs : Array[String],
) -> Int32? raise LensError {
  if inputs.length() != outputs.length() {
    raise InvalidArgument("rule trace length mismatch")
  }
  let mut active = self.kind == "forbidden"
  for i, input in inputs {
    let (next, violated) = self.advance(active, { input, output: outputs[i], })
    if violated {
      return Some(i)
    }
    active = next
  }
  None
}

///|
pub(all) struct RuleSearch {
  witness : Array[String]?
  search_complete : Bool
  visited_pairs : Int32
  reason : String?
} derive(Debug, ToJson)

///|
pub extend RuleSearch with ToJson::{to_json}

///|
pub extend RuleSearch with @debug.Debug::{to_repr}

///|
/// BFS over model × finite monitor. A witness is only a model prediction.
pub fn BehaviorRule::search(
  self : BehaviorRule,
  model : Machine,
  max_pairs~ : Int32 = 100000,
) -> RuleSearch raise LensError {
  if max_pairs < 1 || max_pairs > 1000000 {
    raise InvalidArgument("invalid rule search budget")
  }
  for event in [Some(self.forbidden), self.trigger, self.release] {
    if event is Some(e) && !model.alphabet.contains(e.input) {
      raise UnknownInput(e.input)
    }
  }
  let initial = self.kind == "forbidden"
  let seen : Map[(Int32, Bool), Unit] = Map([((model.initial, initial), ())])
  let queue = [(model.initial, initial, -1, -1)]
  let mut truncated = false
  for head = 0; head < queue.length(); head = head + 1 {
    let (state, active, _, _) = queue[head]
    for column, edge in model.transitions[state] {
      let input = model.alphabet[column]
      let (next, violation) = self.advance(active, {
        input,
        output: edge.output,
      })
      if violation {
        let reversed = [input]
        let mut cursor = head
        for ;; {
          let (_, _, parent, action) = queue[cursor]
          if parent < 0 {
            break
          }
          reversed.push(model.alphabet[action])
          cursor = parent
        }
        if reversed.length() > 4096 {
          return {
            witness: None,
            search_complete: false,
            visited_pairs: queue.length(),
            reason: Some("rule-word-length"),
          }
        }
        return {
          witness: Some(reversed.rev()),
          search_complete: true,
          visited_pairs: queue.length(),
          reason: None,
        }
      }
      let pair = (edge.target, next)
      if !seen.contains(pair) {
        if queue.length() == max_pairs {
          truncated = true
        } else {
          seen[pair] = ()
          queue.push((edge.target, next, head, column))
        }
      }
    }
  }
  {
    witness: None,
    search_complete: !truncated,
    visited_pairs: queue.length(),
    reason: if truncated {
      Some("rule-product-pairs")
    } else {
      None
    },
  }
}

///|
/// No model witness means no fresh target confirmation, even after full search.
pub fn BehaviorRule::verify(
  self : BehaviorRule,
  model : Machine,
  experiment : Experiment,
  max_pairs~ : Int32 = 100000,
) -> Json raise {
  let search = self.search(model, max_pairs~)
  let actual = match search.witness {
    Some(word) => Some(experiment.query(word, bypass_cache=true))
    None => None
  }
  self.finding(search, actual)
}

///|
/// Assemble evidence from a complete reset-based replay; callers own its IO provenance.
pub fn BehaviorRule::finding(
  self : BehaviorRule,
  search : RuleSearch,
  actual : Array[String]?,
) -> Json raise {
  let violation = match (search.witness, actual) {
    (Some(word), Some(outputs)) => self.check_trace(word, outputs)
    _ => None
  }
  Json::object({
    "rule": Json(self),
    "prediction": Json(search),
    "status": Json(
      if violation is Some(_) {
        "confirmed-violation"
      } else if actual is Some(_) {
        "not-reproduced"
      } else if search.witness is Some(_) {
        "predicted-only"
      } else if search.search_complete {
        "no-model-violation"
      } else {
        "inconclusive"
      },
    ),
    "actual_outputs": actual.map(o => Json(o)).unwrap_or(Json::null()),
    "violation_position": violation.map(i => Json(i)).unwrap_or(Json::null()),
    "scope": Json(
      "finite safety monitor; no-model-violation is about the supplied model only",
    ),
  })
}
