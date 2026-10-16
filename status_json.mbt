///|
pub impl ToJson for Evidence with fn to_json(self) {
  match self {
    ExactReference => Json::object({ "kind": Json("exact-reference") })
    ConditionalStateBound(bound) =>
      Json::object({
        "kind": Json("conditional-state-bound"),
        "state_bound": Json(bound),
      })
    Budgeted(details) =>
      Json::object({ "kind": Json("budgeted"), "details": Json(details) })
  }
}

///|
pub impl ToJson for LearningStatus with fn to_json(self) {
  match self {
    Supported(evidence) =>
      Json::object({ "kind": Json("supported"), "evidence": Json(evidence) })
    Inconclusive(reason) =>
      Json::object({ "kind": Json("inconclusive"), "reason": Json(reason) })
    Unstable(word~, expected~, actual~) =>
      Json::object({
        "kind": Json("unstable"),
        "inputs": Json(word),
        "expected": Json(expected),
        "actual": Json(actual),
      })
  }
}

///|
pub impl ToJson for CompatibilityStatus with fn to_json(self) {
  match self {
    ReplayUnstable(side~, word~, expected~, actual~) =>
      Json::object({
        "kind": Json("unstable-during-replay"),
        "side": Json(side),
        "inputs": Json(word),
        "expected": Json(expected),
        "actual": Json(actual),
      })
    ConfirmedDifference(difference) =>
      Json::object({
        "kind": Json("confirmed-difference"),
        "difference": Json(difference),
      })
    NoDifferenceBetweenHypotheses =>
      Json::object({ "kind": Json("no-difference-between-hypotheses") })
    Inconclusive(reason) =>
      Json::object({ "kind": Json("inconclusive"), "reason": Json(reason) })
  }
}

///|
pub impl ToJson for CompatibilityResult with fn to_json(self) {
  Json::object({
    "format": Json("moonstatelens.compatibility"),
    "version": Json(1),
    "status": Json(self.status),
    "left": Json(self.left),
    "right": Json(self.right),
    "left_statistics": Json(self.left_statistics),
    "right_statistics": Json(self.right_statistics),
    "refinements": Json(self.refinements),
    "spurious_inputs": Json(self.spurious_inputs),
  })
}
