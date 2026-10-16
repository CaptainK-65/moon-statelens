///|
pub(all) enum CompatibilityStatus {
  ConfirmedDifference(Difference)
  NoDifferenceBetweenHypotheses
  Inconclusive(String)
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
  refinements : Int32
  spurious_inputs : Array[Array[String]]
} derive(Debug)

///|
pub extend CompatibilityResult with @debug.Debug::{to_repr}

///|
pub extend CompatibilityResult with ToJson::{to_json}

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
/// Spurious hypothesis disagreements become regression experiments for a new
/// learning pass. Equal hypotheses remain qualified by each result's evidence.
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
      return {
        status: Inconclusive("unstable-observations"),
        left: lr,
        right: rr,
        refinements,
        spurious_inputs: spurious,
      }
    }
    guard lr.model is Some(lm) && rr.model is Some(rm) else {
      return {
        status: Inconclusive("missing-hypothesis"),
        left: lr,
        right: rr,
        refinements,
        spurious_inputs: spurious,
      }
    }
    match distinguish(lm, rm) {
      None => {
        let status = if lr.status is Supported(_) && rr.status is Supported(_) {
          NoDifferenceBetweenHypotheses
        } else {
          Inconclusive("learning-incomplete")
        }
        return {
          status,
          left: lr,
          right: rr,
          refinements,
          spurious_inputs: spurious,
        }
      }
      Some(candidate) =>
        match confirm_difference(left, right, candidate.inputs) {
          Some(actual) =>
            return {
              status: ConfirmedDifference(actual),
              left: lr,
              right: rr,
              refinements,
              spurious_inputs: spurious,
            }
          None => {
            spurious.push(candidate.inputs.copy())
            if refinements == max_refinements {
              return {
                status: Inconclusive("compatibility-refinements"),
                left: lr,
                right: rr,
                refinements,
                spurious_inputs: spurious,
              }
            }
          }
        }
    }
  }
  // The inclusive loop always returns in its final iteration.
  abort("unreachable compatibility loop")
}
