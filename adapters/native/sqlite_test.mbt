///|
/// Independent finite transaction specification, used only AFTER learning.
fn transaction_reference() -> @lens.Machine raise {
  let alphabet = ["begin", "put", "delete", "commit", "rollback", "read"]
  let rows : Array[Array[@lens.Transition]] = []
  for state in 0..<6 {
    let in_transaction = state >= 2
    let base = if in_transaction { (state - 2) / 2 } else { state }
    let value = if in_transaction { (state - 2) % 2 } else { state }
    let row : Array[@lens.Transition] = [
      {
        target: if in_transaction {
          state
        } else {
          2 + base * 2 + value
        },
        output: if in_transaction {
          "transaction-error"
        } else {
          "ok"
        },
      },
      {
        target: if in_transaction {
          2 + base * 2 + 1
        } else {
          1
        },
        output: "ok",
      },
      { target: if in_transaction { 2 + base * 2 } else { 0 }, output: "ok", },
      {
        target: if in_transaction {
          value
        } else {
          state
        },
        output: if in_transaction {
          "ok"
        } else {
          "transaction-error"
        },
      },
      {
        target: if in_transaction {
          base
        } else {
          state
        },
        output: if in_transaction {
          "ok"
        } else {
          "transaction-error"
        },
      },
      { target: state, output: if value == 0 { "empty" } else { "present" }, },
    ]
    rows.push(row)
  }
  @lens.Machine::new(alphabet, rows)
}

///|
async test "real SQLite CLI resets reliably and preserves transaction history within each query" {
  @external.with_sqlite("sqlite3", system => {
    let experiment = @runner.AsyncExperiment::new(system, [
      "begin", "put", "delete", "commit", "rollback", "read",
    ])
    assert_eq(experiment.query(["begin", "put", "rollback", "read"]), [
      "ok", "ok", "ok", "empty",
    ])
    assert_eq(
      experiment.query(["put", "begin", "delete", "rollback", "read"]),
      ["ok", "ok", "ok", "ok", "present"],
    )
    assert_eq(experiment.query(["read"], bypass_cache=true), ["empty"])
    assert_eq(experiment.query(["rollback", "begin", "begin", "commit"]), [
      "transaction-error", "ok", "transaction-error", "ok",
    ])
  })
}

///|
async test "KV learns a real six-state SQLite transaction abstraction without receiving its reference" {
  @external.with_sqlite("sqlite3", system => {
    let alphabet = ["begin", "put", "delete", "commit", "rollback", "read"]
    let report = @runner.infer(
      @runner.AsyncExperiment::new(system, alphabet),
      WpMethod(bound=6, max_tests=20000, max_work=100000),
      algorithm=KearnsVazirani,
    )
    assert_true(report.learning.status is Supported(ConditionalStateBound(6)))
    assert_eq(report.learning.model.unwrap().state_count(), 6)
    assert_true(
      @lens.distinguish(report.learning.model.unwrap(), transaction_reference())
      is None,
    )
  })
}
