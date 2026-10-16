///|
/// Run a conformance oracle directly. Unlike learn, this propagates resource
/// limits to the caller. Hypothesis and experiment alphabets must agree.
pub fn Oracle::evaluate(
  self : Oracle,
  hypothesis : Machine,
  experiment : Experiment,
) -> CheckResult raise {
  if hypothesis.alphabet.length() != experiment.alphabet.length() ||
    !hypothesis.alphabet.all(input => experiment.alphabet.contains(input)) {
    raise InvalidArgument("oracle and experiment alphabets differ")
  }
  (self.check)(hypothesis, experiment)
}
