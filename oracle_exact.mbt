///|
/// Exact equivalence to a supplied explicit model. Intended for fixtures and
/// independent algorithm tests. The caller must establish that the adapter
/// implements that reference; this oracle cannot establish it for an unknown SUL.
pub fn Oracle::exact(
  reference : Machine,
  max_pairs~ : Int32 = 1000000,
) -> Oracle raise LensError {
  if max_pairs < 1 {
    raise InvalidArgument("max_pairs must be positive")
  }
  Oracle::new((hypothesis, _) => {
    match distinguish(hypothesis, reference, max_pairs~) {
      Some(difference) => Counterexample(difference.inputs)
      None => NoCounterexample(ExactReference)
    }
  })
}
