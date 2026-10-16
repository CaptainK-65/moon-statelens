///|
/// Scope of the experiment that supported a hypothesis. ExactReference refers
/// to a supplied explicit reference model; it does not certify an arbitrary adapter.
pub(all) enum Evidence {
  ExactReference
  ConditionalStateBound(Int)
  Budgeted(String)
} derive(Debug, ToJson)

///|
pub extend Evidence with @debug.Debug::{to_repr}

///|
pub extend Evidence with ToJson::{to_json}

///|
/// Custom oracle contract: returned counterexamples must actually distinguish
/// the supplied hypothesis from the experiment's target.
pub(all) enum CheckResult {
  Counterexample(Array[String])
  NoCounterexample(Evidence)
  Inconclusive(String)
} derive(Debug)

///|
pub extend CheckResult with @debug.Debug::{to_repr}

///|
pub struct Oracle {
  priv check : (Machine, Experiment) -> CheckResult raise
}

///|
pub fn Oracle::new(
  check : (Machine, Experiment) -> CheckResult raise,
) -> Oracle {
  { check, }
}

///|
pub(all) enum LearningStatus {
  Supported(Evidence)
  Inconclusive(String)
  Unstable(
    word~ : Array[String],
    expected~ : Array[String],
    actual~ : Array[String]
  )
} derive(Debug, ToJson)

///|
pub extend LearningStatus with @debug.Debug::{to_repr}

///|
pub extend LearningStatus with ToJson::{to_json}

///|
pub(all) struct LearningRound {
  index : Int
  states : Int
  prefixes : Int
  suffixes : Int
  table_cells : Int
  queries : Int
  counterexample_length : Int?
} derive(Debug, ToJson)

///|
pub extend LearningRound with @debug.Debug::{to_repr}

///|
pub extend LearningRound with ToJson::{to_json}

///|
pub(all) struct LearningResult {
  model : Machine?
  status : LearningStatus
  statistics : Statistics
  rounds : Array[LearningRound]
  counterexamples : Array[Difference]
} derive(Debug)

///|
pub extend LearningResult with @debug.Debug::{to_repr}
