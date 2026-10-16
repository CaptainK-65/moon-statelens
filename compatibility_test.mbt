///|
fn session_fixture(buggy : Bool) -> @lens.System {
  let logged_in = [false]
  @lens.System::new(reset=() => logged_in[0] = false, step=input => {
    match input {
      "login" => {
        logged_in[0] = true
        "ok"
      }
      "logout" => {
        if !buggy {
          logged_in[0] = false
        }
        "ok"
      }
      _ => if logged_in[0] { "allowed" } else { "denied" }
    }
  })
}

///|
test "compatibility report confirms a multi-step regression against both adapters" {
  let actions = ["login", "logout", "request"]
  let report = @lens.compare(
    @lens.Experiment::new(session_fixture(false), actions),
    @lens.Experiment::new(session_fixture(true), actions),
    @lens.Oracle::w_method(2),
    @lens.Oracle::w_method(2),
  )
  guard report.status is ConfirmedDifference(diff) else {
    fail("expected confirmed regression")
  }
  assert_eq(diff.inputs, ["login", "logout", "request"])
  assert_eq(diff.left_outputs, ["ok", "ok", "denied"])
  assert_eq(diff.right_outputs, ["ok", "ok", "allowed"])
}

///|
test "spurious model differences become experiments instead of false implementation regressions" {
  let target = delayed_target(5)
  let report = @lens.compare(
    @lens.Experiment::new(target.system(), target.alphabet()),
    @lens.Experiment::new(target.system(), target.alphabet()),
    @lens.Oracle::exhaustive(0),
    @lens.Oracle::exact(target),
  )
  assert_true(report.status is NoDifferenceBetweenHypotheses)
  assert_true(report.refinements > 0)
  assert_true(report.spurious_inputs.length() > 0)
  assert_true(
    @lens.distinguish(report.left.model.unwrap(), report.right.model.unwrap())
    is None,
  )
}

///|
test "exhausted comparison learning cannot be reported as implementation equivalence" {
  let target = sample()
  let report = @lens.compare(
    @lens.Experiment::new(target.system(), target.alphabet(), max_queries=0),
    @lens.Experiment::new(target.system(), target.alphabet()),
    @lens.Oracle::exact(target),
    @lens.Oracle::exact(target),
  )
  assert_true(report.status is Inconclusive("missing-hypothesis"))
}
