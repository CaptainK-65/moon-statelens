///|
pub(all) struct RunResult {
  report : Json
  exit_code : Int32
} derive(Debug)

///|
pub extend RunResult with @debug.Debug::{to_repr}

///|
fn Config::accepts(self : Config, learning : @lens.LearningResult) -> Bool {
  match learning.status {
    Supported(evidence) =>
      match self.expected_evidence {
        "budgeted" => true
        "conditional-state-bound" => evidence is ConditionalStateBound(_)
        "exact-reference" => self.kind == "model" && evidence is ExactReference
        _ => false
      }
    _ => false
  }
}

///|
async fn Config::preflight_artifacts(self : Config) -> Unit {
  for (_, path) in self.artifacts {
    if @fs.exists(path) {
      raise @runner.Configuration("artifact already exists: " + path)
    }
  }
}

///|
async fn Config::write_artifacts(
  self : Config,
  report : Json,
  model : @lens.Machine?,
  traces : Json,
) -> Unit {
  for (kind, path) in self.artifacts {
    let data = match kind {
      "report" => report.stringify(indent=2)
      "traces" => traces.stringify(indent=2)
      "model" =>
        match model {
          Some(model) => model.encode()
          None => continue
        }
      "dot" =>
        match model {
          Some(model) => model.to_dot()
          None => continue
        }
      _ => continue
    }
    @fs.write_file(path, data + "\n", create_mode=CreateNew)
  }
}

///|
/// Execute and judge according to the requested evidence scope. Transport
/// failures raise; completed-but-insufficient evidence returns exit code 3.
pub async fn run(config : Config) -> RunResult {
  config.preflight_artifacts()
  @async.with_timeout(
    config.budgets.run_timeout_ms,
    () => {
      config.with_target(system => {
        let experiment = config.experiment(system)
        let inference = config.infer(experiment, config.plan)
        let accepted = config.accepts(inference.learning)
        let report = Json::object({
          "format": Json("moonstatelens.run"),
          "version": Json(2),
          "configuration": config.manifest(),
          "inference": Json(inference),
          "accepted": Json(accepted),
        })
        config.write_artifacts(
          report,
          inference.learning.model,
          experiment.traces_json(),
        )
        { report, exit_code: if accepted { 0 } else { 3 }, }
      })
    },
    error=@runner.TimedOut("run"),
  )
}

///|
/// Freshly replay arbitrary saved input sequences on the configured real target.
pub async fn replay(config : Config, words : Array[Array[String]]) -> Json {
  if words.length() > 100000 {
    raise @runner.Configuration("too many replay words")
  }
  @async.with_timeout(
    config.budgets.run_timeout_ms,
    () => {
      config.with_target(system => {
        let experiment = config.experiment(system)
        let results = []
        for requested in words {
          let inputs = requested.copy()
          let outputs = experiment.query(inputs, bypass_cache=true)
          results.push(
            Json::object({ "inputs": Json(inputs), "outputs": Json(outputs) }),
          )
        }
        Json::object({
          "format": Json("moonstatelens.replay"),
          "version": Json(2),
          "configuration": config.manifest(),
          "traces": Json(results),
          "statistics": Json(experiment.statistics()),
        })
      })
    },
    error=@runner.TimedOut("replay"),
  )
}

///|
/// Infer both implementations and confirm model differences on fresh real IO.
/// Non-reproducing candidates become regression queries in both relearners.
pub async fn compare(
  left : Config,
  right : Config,
  max_refinements~ : Int32 = 4,
) -> RunResult {
  if left.alphabet != right.alphabet {
    raise @runner.Configuration(
      "comparison alphabets must have identical order",
    )
  }
  if left.abstraction != right.abstraction {
    raise @runner.Configuration("comparison abstractions must match")
  }
  if max_refinements < 0 || max_refinements > 64 {
    raise @runner.Configuration("invalid refinement budget")
  }
  let timeout = if left.budgets.run_timeout_ms < right.budgets.run_timeout_ms {
    left.budgets.run_timeout_ms
  } else {
    right.budgets.run_timeout_ms
  }
  @async.with_timeout(
    timeout,
    () => {
      left.with_target(left_system => {
        right.with_target(right_system => {
          let le = left.experiment(left_system)
          let re = right.experiment(right_system)
          let regressions : Array[Array[String]] = []
          let mut lplan = left.plan
          let mut rplan = right.plan
          for iteration in 0..<=max_refinements {
            let lr = left.infer(le, lplan)
            let rr = right.infer(re, rplan)
            fn finish(
              status : @lens.CompatibilityStatus,
              exit_code : Int32,
            ) -> RunResult {
              {
                exit_code,
                report: Json::object({
                  "format": Json("moonstatelens.comparison"),
                  "version": Json(2),
                  "status": Json(status),
                  "left_configuration": left.manifest(),
                  "right_configuration": right.manifest(),
                  "left": Json(lr),
                  "right": Json(rr),
                  "left_statistics": Json(le.statistics()),
                  "right_statistics": Json(re.statistics()),
                  "refinements": Json(iteration),
                  "spurious_inputs": Json(regressions),
                }),
              }
            }
            guard lr.learning.model is Some(lm) && rr.learning.model is Some(rm) else {
              return finish(Inconclusive("missing completed hypothesis"), 3)
            }
            if lr.learning.status is Unstable(..) ||
              rr.learning.status is Unstable(..) {
              return finish(Inconclusive("unstable learning observations"), 3)
            }
            let candidate = @lens.distinguish(lm, rm) catch {
              @lens.LimitExceeded(reason) =>
                return finish(Inconclusive(reason), 3)
              error => raise error
            }
            guard candidate is Some(diff) else {
              return finish(
                NoDifferenceBetweenHypotheses,
                if left.accepts(lr.learning) && right.accepts(rr.learning) {
                  0
                } else {
                  3
                },
              )
            }
            let mut side = "left"
            let replayed = try {
              let lo = le.query(diff.inputs, bypass_cache=true)
              side = "right"
              let ro = re.query(diff.inputs, bypass_cache=true)
              if lo != ro {
                Some(
                  finish(
                    ConfirmedDifference({
                      inputs: diff.inputs,
                      left_outputs: lo,
                      right_outputs: ro,
                    }),
                    2,
                  ),
                )
              } else {
                None
              }
            } catch {
              @lens.InconsistentObservation(word~, expected~, actual~) =>
                Some(
                  finish(ReplayUnstable(side~, word~, expected~, actual~), 3),
                )
              @lens.LimitExceeded(reason) =>
                Some(finish(Inconclusive(reason), 3))
              error => raise error
            }
            if replayed is Some(result) {
              return result
            }
            if iteration == max_refinements {
              return finish(Inconclusive("compatibility-refinements"), 3)
            }
            regressions.push(diff.inputs.copy())
            lplan = Chain([Replay(regressions.copy()), left.plan])
            rplan = Chain([Replay(regressions.copy()), right.plan])
          }
          raise @runner.Target("comparison refinement loop did not return")
        })
      })
    },
    error=@runner.TimedOut("comparison"),
  )
}
