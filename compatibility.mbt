///|
pub(all) enum CompatibilityStatus {
  ConfirmedDifference(Difference)
  NoDifferenceBetweenHypotheses
  Inconclusive(String)
  ReplayUnstable(
    side~ : String,
    word~ : Array[String],
    expected~ : Array[String],
    actual~ : Array[String]
  )
} derive(Debug)

///|
pub extend CompatibilityStatus with @debug.Debug::{to_repr}

///|
pub extend CompatibilityStatus with ToJson::{to_json}

///|
pub(all) struct CompatibilityResult {
  status : CompatibilityStatus
  left : LearningResult
  right : LearningResult
  left_statistics : Statistics
  right_statistics : Statistics
  refinements : Int32
  spurious_inputs : Array[Array[String]]
} derive(Debug)

///|
pub extend CompatibilityResult with @debug.Debug::{to_repr}

///|
pub extend CompatibilityResult with ToJson::{to_json}

///|
fn compatibility_result(
  status : CompatibilityStatus,
  lr : LearningResult,
  rr : LearningResult,
  left : Experiment,
  right : Experiment,
  refinements : Int32,
  spurious : Array[Array[String]],
) -> CompatibilityResult {
  {
    status,
    left: lr,
    right: rr,
    left_statistics: left.statistics(),
    right_statistics: right.statistics(),
    refinements,
    spurious_inputs: spurious,
  }
}

///|
/// Replay supplied regression words before delegating to this oracle. Words
/// are copied; observations bypass the cache and can refine a stale hypothesis.
pub fn Oracle::with_regressions(
  self : Oracle,
  words : Array[Array[String]],
) -> Oracle {
  let saved = words.map(word => word.copy())
  Oracle::new((hypothesis, experiment) => {
    for word in saved {
      if oracle_mismatch(hypothesis, experiment, word) {
        return Counterexample(word.copy())
      }
    }
    (self.check)(hypothesis, experiment)
  })
}

///|
/// Infer both behaviors and replay model differences on the real adapters.
/// Spurious hypothesis disagreements refine later experiments. Equal hypotheses
/// remain qualified by each learning result's evidence. Final statistics include
/// the real confirmation calls, even when those calls exhaust a budget.
pub fn compare(
  left : Experiment,
  right : Experiment,
  left_oracle : Oracle,
  right_oracle : Oracle,
  max_states~ : Int32 = 256,
  max_refinements~ : Int32 = 4,
) -> CompatibilityResult raise {
  if max_refinements < 0 || max_refinements > 64 {
    raise InvalidArgument("max_refinements must be 0..64")
  }
  if left.alphabet.length() != right.alphabet.length() ||
    !left.alphabet.all(input => right.alphabet.contains(input)) {
    raise InvalidArgument("experiments must have the same input symbols")
  }
  let spurious = []
  for refinements in 0..<=max_refinements {
    let lr = learn(left, left_oracle.with_regressions(spurious), max_states~)
    let rr = learn(right, right_oracle.with_regressions(spurious), max_states~)
    if lr.status is Unstable(..) || rr.status is Unstable(..) {
      return compatibility_result(
        Inconclusive("unstable-observations"),
        lr,
        rr,
        left,
        right,
        refinements,
        spurious,
      )
    }
    guard lr.model is Some(lm) && rr.model is Some(rm) else {
      return compatibility_result(
        Inconclusive("missing-hypothesis"),
        lr,
        rr,
        left,
        right,
        refinements,
        spurious,
      )
    }
    try {
      match distinguish(lm, rm) {
        None => {
          let status = if lr.status is Supported(_) && rr.status is Supported(_) {
            NoDifferenceBetweenHypotheses
          } else {
            Inconclusive("learning-incomplete")
          }
          return compatibility_result(
            status, lr, rr, left, right, refinements, spurious,
          )
        }
        Some(candidate) =>
          match confirm_difference(left, right, candidate.inputs) {
            Some(actual) =>
              return compatibility_result(
                ConfirmedDifference(actual),
                lr,
                rr,
                left,
                right,
                refinements,
                spurious,
              )
            None => {
              spurious.push(candidate.inputs.copy())
              if refinements == max_refinements {
                return compatibility_result(
                  Inconclusive("compatibility-refinements"),
                  lr,
                  rr,
                  left,
                  right,
                  refinements,
                  spurious,
                )
              }
            }
          }
      }
    } catch {
      LimitExceeded(reason) =>
        return compatibility_result(
          Inconclusive("comparison:" + reason),
          lr,
          rr,
          left,
          right,
          refinements,
          spurious,
        )
      InconsistentObservation(word~, expected~, actual~) => {
        let side = if left.conflict is Some(_) { "left" } else { "right" }
        return compatibility_result(
          ReplayUnstable(side~, word~, expected~, actual~),
          lr,
          rr,
          left,
          right,
          refinements,
          spurious,
        )
      }
      error => raise error
    }
  }
  abort("unreachable compatibility loop")
}
