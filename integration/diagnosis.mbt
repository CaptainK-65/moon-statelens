///|
/// Infer both targets, enumerate differing reachable product edges, and freshly
/// replay each context on BOTH actual targets. No one-to-one state alignment.
pub async fn diagnose(
  left : Config,
  right : Config,
  max_findings~ : Int32 = 64,
  max_pairs~ : Int32 = 100000,
) -> RunResult {
  ignore(left.validate(operation="compare"))
  ignore(right.validate(operation="compare"))
  if left.alphabet != right.alphabet || left.abstraction != right.abstraction {
    raise @runner.Configuration("diagnosis alphabet and abstraction must match")
  }
  if max_findings < 1 ||
    max_findings > 10000 ||
    max_pairs < 1 ||
    max_pairs > 1000000 {
    raise @runner.Configuration("invalid diagnosis budget")
  }
  let destinations = []
  left.preflight_artifacts(seen=destinations)
  right.preflight_artifacts(seen=destinations)
  let timeout = if left.budgets.run_timeout_ms < right.budgets.run_timeout_ms {
    left.budgets.run_timeout_ms
  } else {
    right.budgets.run_timeout_ms
  }
  @async.with_timeout(
    timeout,
    () => {
      left.with_target(ls => {
        right.with_target(rs => {
          let le = left.experiment(ls)
          let re = right.experiment(rs)
          let lr = left.infer(le, left.plan)
          let rr = right.infer(re, right.plan)
          let findings = []
          let mut prediction : @lens.ModelDiagnosis? = None
          let mut complete = left.accepts(lr.learning) &&
            right.accepts(rr.learning)
          let mut confirmed = 0
          let mut reason : String? = None
          if lr.learning.model is Some(lm) &&
            rr.learning.model is Some(rm) &&
            !(lr.learning.status is Unstable(..)) &&
            !(rr.learning.status is Unstable(..)) {
            let candidates = @lens.diagnose_models(
              lm,
              rm,
              max_findings~,
              max_pairs~,
            )
            prediction = Some(candidates)
            complete = complete && candidates.complete
            for candidate in candidates.differences {
              let (lo, ro) = (
                le.query(candidate.inputs, bypass_cache=true),
                re.query(candidate.inputs, bypass_cache=true),
              ) catch {
                @lens.LimitExceeded(message) | @runner.TimedOut(message) => {
                  complete = false
                  reason = Some(message)
                  break
                }
                @lens.InconsistentObservation(..) => {
                  complete = false
                  reason = Some("unstable fresh replay")
                  break
                }
                error => raise error
              }
              let status = if lo != ro {
                confirmed += 1
                "confirmed-difference"
              } else {
                complete = false
                "not-reproduced"
              }
              findings.push(
                Json::object({
                  "status": Json(status),
                  "inputs": Json(candidate.inputs),
                  "predicted_left": Json(candidate.left_outputs),
                  "predicted_right": Json(candidate.right_outputs),
                  "actual_left": Json(lo),
                  "actual_right": Json(ro),
                }),
              )
            }
          } else {
            complete = false
            reason = Some("missing or unstable hypothesis")
          }
          let report = Json::object({
            "format": Json("moonstatelens.diagnosis"),
            "version": Json(1),
            "left_configuration": left.manifest(),
            "right_configuration": right.manifest(),
            "left": Json(lr),
            "right": Json(rr),
            "prediction": prediction.map(p => Json(p)).unwrap_or(Json::null()),
            "findings": Json(findings),
            "confirmed_contexts": Json(confirmed),
            "complete": Json(complete),
            "reason": reason.map(s => Json(s)).unwrap_or(Json::null()),
            "left_statistics": Json(le.statistics()),
            "right_statistics": Json(re.statistics()),
            "scope": Json(
              "bounded differing product edges; contexts are not independent bug counts; all confirmed contexts freshly replayed on both targets",
            ),
          })
          left.write_artifacts(report, lr.learning.model, le.traces_json())
          right.write_artifacts(report, rr.learning.model, re.traces_json())
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
      })
    },
    error=@runner.TimedOut("diagnosis"),
  )
}
