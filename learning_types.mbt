///|
/// Scope of the experiment that supported a hypothesis. ExactReference refers
/// to a supplied explicit reference model; it does not certify an arbitrary adapter.
pub(all) enum Evidence {
  ExactReference
  ConditionalStateBound(Int32)
  Budgeted(String)
} derive(Debug)

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
} derive(Debug)

///|
pub extend LearningStatus with @debug.Debug::{to_repr}

///|
pub extend LearningStatus with ToJson::{to_json}

///|
pub(all) struct LearningRound {
  index : Int32
  states : Int32
  prefixes : Int32
  suffixes : Int32
  table_cells : Int32
  table_symbols : Int32
  queries : Int32
  counterexample_length : Int32?
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
