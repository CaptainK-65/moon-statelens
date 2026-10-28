///|
/// Run a saved baseline suite on a configured component without relearning it.
/// Artifacts follow replay policy: reports and traces, no inferred model/DOT.
pub async fn regress(
  config : Config,
  suite : @lens.RegressionSuite,
  compact~ : Bool = true,
  stability_rechecks~ : Int32 = 1,
) -> RunResult {
  ignore(config.validate(operation="replay"))
  // Check before starting a child process or contacting a network endpoint.
  if suite.plan().alphabet() != config.alphabet {
    raise @runner.Configuration(
      "regression suite alphabet order must match target",
    )
  }
  let plan = suite.plan(compact~)
  ignore(plan.execution(stability_rechecks~))
  config.preflight_artifacts()
  @async.with_timeout(
    config.budgets.run_timeout_ms,
    () => {
      config.with_target(system => {
        let experiment = config.experiment(system)
        let report = @runner.run_regression(
          experiment,
          plan,
          stability_rechecks~,
        )
        guard report is Object(fields) else {
          raise @runner.Target("invalid regression report")
        }
        fields["configuration"] = config.manifest()
        fields["statistics"] = Json(experiment.statistics())
        config.write_artifacts(report, None, experiment.traces_json())
        let exit_code = if report is { "passed": True, .. } {
          0
        } else if report
          is { "failed_cases": Number(n, ..), "unstable": False, .. } &&
          n > 0 {
          2
        } else {
          3
        }
        { report, exit_code, }
      })
    },
    error=@runner.TimedOut("regression-run"),
  )
}

///|
/// Infer then validate safety rules. No model witness is a model-only result.
pub async fn check_rules(
  config : Config,
  rules : Array[@lens.BehaviorRule],
) -> RunResult {
  ignore(config.validate())
  if rules.is_empty() || rules.length() > 256 {
    raise @runner.Configuration("expected 1..256 rules")
  }
  // Validate event alphabets without IO using a one-state validation model.
  let validation_model = @lens.Machine::new(config.alphabet, [
    config.alphabet.map(_ => { target: 0, output: "", }),
  ])
  let ids : Map[String, Unit] = Map([])
  for rule in rules {
    ignore(rule.search(validation_model))
    guard Json(rule) is { "id": String(id), .. } else {
      raise @runner.Configuration("invalid rule")
    }
    if ids.contains(id) {
      raise @runner.Configuration("duplicate rule ID")
    }
    ids[id] = ()
  }
  config.preflight_artifacts()
  @async.with_timeout(
    config.budgets.run_timeout_ms,
    () => {
      config.with_target(system => {
        let experiment = config.experiment(system)
        let inference = config.infer(experiment, config.plan)
        let findings = []
        let mut confirmed = 0
        let mut complete = config.accepts(inference.learning)
        let mut reason : String? = if complete {
          None
        } else {
          Some("learning evidence expectation not met")
        }
        if inference.learning.model is Some(model) &&
          !(inference.learning.status is Unstable(..)) {
          for rule in rules {
            let finding = @runner.verify_rule(experiment, model, rule) catch {
              @lens.LimitExceeded(message) | @runner.TimedOut(message) => {
                complete = false
                reason = Some(message)
                findings.push(rule.finding(rule.search(model), None))
                break
              }
              @lens.InconsistentObservation(..) => {
                complete = false
                reason = Some("unstable fresh rule replay")
                findings.push(rule.finding(rule.search(model), None))
                break
              }
              error => raise error
            }
            if finding is { "status": "confirmed-violation", .. } {
              confirmed += 1
            }
            if finding is { "status": "not-reproduced" | "inconclusive", .. } {
              complete = false
            }
            findings.push(finding)
          }
        } else {
          complete = false
          reason = Some("missing or unstable hypothesis")
        }
        let report = Json::object({
          "format": Json("moonstatelens.rule-check"),
          "version": Json(1),
          "configuration": config.manifest(),
          "inference": Json(inference),
          "rules": Json(rules),
          "findings": Json(findings),
          "confirmed_violations": Json(confirmed),
          "complete": Json(complete),
          "reason": reason.map(r => Json(r)).unwrap_or(Json::null()),
          "statistics": Json(experiment.statistics()),
          "scope": Json(
            "confirmed violations have fresh target traces; absence of violations remains conditional on learned-model evidence",
          ),
        })
        config.write_artifacts(
          report,
          inference.learning.model,
          experiment.traces_json(),
        )
        {
          report,
          exit_code: if confirmed > 0 {
            2
          } else if complete {
            0
          } else {
            3
          },
        }
      })
    },
    error=@runner.TimedOut("rule-check"),
  )
}
