///|
/// Execute model-derived assertions through any existing async adapter. Every
/// physical word and stability recheck bypasses the observation cache.
pub async fn run_regression(
  experiment : AsyncExperiment,
  plan : @lens.RegressionPlan,
  stability_rechecks~ : Int32 = 1,
) -> Json {
  if experiment.alphabet() != plan.alphabet() {
    raise Configuration("regression alphabet order mismatch")
  }
  let execution = plan.execution(stability_rechecks~)
  try {
    for ;; {
      guard execution.next_word() is Some(word) else { break }
      execution.observe(experiment.query(word, bypass_cache=true))
    }
  } catch {
    @lens.LimitExceeded(reason) => execution.abort(reason)
    @lens.InconsistentObservation(..) =>
      execution.abort("inconsistent target observation", unstable=true)
    TimedOut(reason) => execution.abort("timeout: " + reason)
    error => raise error
  }
  execution.report()
}

///|
/// Confirm a finite safety-rule prediction using a fresh complete actual trace.
pub async fn verify_rule(
  experiment : AsyncExperiment,
  model : @lens.Machine,
  rule : @lens.BehaviorRule,
) -> Json {
  let search = rule.search(model)
  let outputs = match search.witness {
    Some(word) => Some(experiment.query(word, bypass_cache=true))
    None => None
  }
  rule.finding(search, outputs)
}
