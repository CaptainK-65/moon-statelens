# Tested embedding example

Add `CaptainK-65/moon-statelens` to your module and this import to its `moon.pkg`:

```moonbit nocheck
///|
import {
  "CaptainK-65/moon-statelens" @lens,
}
```

Model-derived regression suites retain every original assertion when sharing
prefixes. Independent fresh stability probes remain enabled by default:

```mbt check
///|
test "saved assertions and successful-event safety rules" {
  let model = @lens.Machine::new(["logout", "request"], [
    [{ target: 0, output: "ok", }, { target: 0, output: "denied", }],
  ])
  let suite = model.regression_suite(profile="wp", state_bound=1)
  let imported = @lens.RegressionSuite::from_json(Json(suite))
  assert_true(imported.plan().validate())
  let report = imported
    .plan()
    .run(@lens.Experiment::new(model.system(), model.alphabet()))
  guard report is { "passed": True, .. } else { fail("regression") }
  let rule = @lens.BehaviorRule::new(
    "logged-out-denial",
    { input: "request", output: "allowed", },
    kind="after",
    trigger={ input: "logout", output: "ok", },
  )
  assert_true(rule.search(model).witness is None)
  assert_eq(rule.check_trace(["logout", "request"], ["ok", "allowed"]), Some(1))
}
```

The following blocks are executed by `moon test`. The learner sees only the adapter, not the hidden state or a supplied reference model. Its conclusion is conditional on the declared two-state bound and resettable deterministic Mealy assumptions.

```mbt check
///|
test "quick start learns a resettable session" {
  let active = [false]
  let target = @lens.System::new(reset=() => active[0] = false, step=input => {
    match input {
      "login" => {
        active[0] = true
        "ok"
      }
      "logout" => {
        active[0] = false
        "ok"
      }
      "request" => if active[0] { "allowed" } else { "denied" }
      _ => raise @lens.UnknownInput(input)
    }
  })
  let experiment = @lens.Experiment::new(target, ["login", "logout", "request"])
  let result = @lens.learn(experiment, @lens.Oracle::w_method(2))
  assert_true(result.status is Supported(ConditionalStateBound(2)))
  let model = result.model.unwrap()
  assert_eq(model.state_count(), 2)
  assert_eq(model.trace(["login", "logout", "request"]), ["ok", "ok", "denied"])
  assert_true(
    @lens.distinguish(model, @lens.decode_model(model.encode())) is None,
  )
}
```

Budget exhaustion is data, not equivalence:

```mbt check
///|
test "quick start preserves an inconclusive query budget" {
  let target = @lens.System::new(reset=() => (), step=_ => "ok")
  let experiment = @lens.Experiment::new(target, ["x"], max_queries=0)
  let result = @lens.learn(experiment, @lens.Oracle::w_method(1))
  assert_true(result.status is Inconclusive("physical-queries"))
  assert_true(result.model is None)
}
```
