///|
/// IO-independent execution cursor shared by synchronous and asynchronous runners.
pub struct RegressionExecution {
  priv plan : RegressionPlan
  priv repeats : Int32
  priv observations : Array[Array[String]?]
  priv mut index : Int32
  priv mut repeat : Int32
  priv mut physical : Int32
  priv mut steps : Int32
  priv mut reason : String?
  priv mut unstable : Bool
}

///|
pub fn RegressionPlan::execution(
  self : RegressionPlan,
  stability_rechecks~ : Int32 = 1,
) -> RegressionExecution raise {
  if stability_rechecks < 0 || stability_rechecks > 16 || !self.validate() {
    raise InvalidArgument("invalid suite certificate or recheck count")
  }
  {
    plan: self,
    repeats: stability_rechecks,
    observations: Array::make(self.words.length(), None),
    index: 0,
    repeat: 0,
    physical: 0,
    steps: 0,
    reason: None,
    unstable: false,
  }
}

///|
/// Callers must execute every requested word with a fresh physical reset.
pub fn RegressionExecution::next_word(
  self : RegressionExecution,
) -> Array[String]? {
  if self.reason is Some(_) {
    None
  } else {
    self.plan.words.get(self.index).map(w => w.copy())
  }
}

///|
pub fn RegressionExecution::observe(
  self : RegressionExecution,
  outputs : Array[String],
) -> Unit raise {
  guard self.next_word() is Some(word) else {
    raise InvalidArgument("no pending regression query")
  }
  if outputs.length() != word.length() {
    raise InvalidArgument("regression output length mismatch")
  }
  self.physical += 1
  self.steps += word.length()
  match self.observations[self.index] {
    None => self.observations[self.index] = Some(outputs.copy())
    Some(previous) =>
      if previous != outputs {
        self.unstable = true
        self.reason = Some("fresh stability recheck disagreed")
        return
      }
  }
  if self.repeat == self.repeats {
    self.index += 1
    self.repeat = 0
  } else {
    self.repeat += 1
  }
}

///|
pub fn RegressionExecution::abort(
  self : RegressionExecution,
  reason : String,
  unstable~ : Bool = false,
) -> Unit {
  self.reason = Some(reason)
  self.unstable = self.unstable || unstable
}

///|
pub fn RegressionExecution::report(self : RegressionExecution) -> Json {
  let results = []
  let mut failed = 0
  let mut pending = 0
  for i, c in self.plan.suite.cases {
    // A case is complete only after its physical word AND independent rechecks.
    let owner = self.plan.mapping[i]
    let actual = if owner < self.index {
      self.observations[owner]
    } else {
      None
    }
    let prefix = actual.map(outputs => outputs[:c.inputs.length()].to_owned())
    let mut mismatch : Int32? = None
    if prefix is Some(outputs) {
      for j, output in outputs {
        if output != c.expected[j] {
          mismatch = Some(j)
          break
        }
      }
    }
    if prefix is None {
      pending += 1
    }
    if mismatch is Some(_) {
      failed += 1
    }
    results.push(
      Json::object({
        "case": Json(i),
        "inputs": Json(c.inputs),
        "expected": Json(c.expected),
        "actual": prefix.map(o => Json(o)).unwrap_or(Json::null()),
        "status": Json(
          if prefix is None {
            "not-run"
          } else if mismatch is Some(_) {
            "failed"
          } else {
            "passed"
          },
        ),
        "first_mismatch": mismatch.map(i => Json(i)).unwrap_or(Json::null()),
        "physical_word": Json(owner),
      }),
    )
  }
  let complete = self.index == self.plan.words.length() && self.reason is None
  Json::object({
    "format": Json("moonstatelens.regression-run"),
    "version": Json(1),
    "execution_complete": Json(complete),
    "passed": Json(complete && failed == 0 && self.plan.suite.complete),
    "unstable": Json(self.unstable),
    "reason": self.reason.map(r => Json(r)).unwrap_or(Json::null()),
    "failed_cases": Json(failed),
    "pending_cases": Json(pending),
    "completed_physical_queries": Json(self.physical),
    "completed_physical_steps": Json(self.steps),
    "stability_rechecks_per_word": Json(self.repeats),
    "suite_evidence": self.plan.suite.evidence(),
    "model": Json(self.plan.suite.model),
    "certificate": self.plan.certificate(),
    "cases": Json(results),
  })
}

///|
/// Independent model mismatch is a regression, not proof of old/new real-target difference.
pub fn RegressionPlan::run(
  self : RegressionPlan,
  experiment : Experiment,
  stability_rechecks~ : Int32 = 1,
) -> Json raise {
  if self.suite.model.alphabet != experiment.alphabet() {
    raise InvalidArgument("suite and experiment alphabet order must match")
  }
  let execution = self.execution(stability_rechecks~)
  try {
    for ;; {
      guard execution.next_word() is Some(word) else { break }
      execution.observe(experiment.query(word, bypass_cache=true))
    }
  } catch {
    LimitExceeded(reason) => execution.abort(reason)
    InconsistentObservation(..) =>
      execution.abort("inconsistent target observation", unstable=true)
    error => raise error
  }
  execution.report()
}
