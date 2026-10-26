# Standalone SQLite compatibility gate

This is a separate MoonBit module. Copy this directory into your own repository;
it imports the public Mooncakes package and does not import this checkout by path.

Prerequisites: the documented MoonBit toolchain and sqlite3 on PATH. Run these
commands **inside this directory** after version 0.2.2 has been published:

```sh
moon update
moon run . -- evidence-normal
moon run . -- evidence-CONTROLLED-mutation --controlled-mutation
```

Use a new output directory for each run. The first command compares two normal
SQLite adapters and should exit 0. The mutation command should exit **2**, which
normally fails a CI step. It deliberately maps ROLLBACK to COMMIT in one adapter;
it does not report a defect in SQLite itself.

The consumer learns the finite single-row transaction abstraction through the
public integration API, using KV and Wp with **declared bounds of six states for
the normal adapter and four for the controlled mutant**. These are premises for
the documented finite mappings, not bounds inferred or proven by the tool.
Both targets use separately launched real SQLite processes. It does not give a
reference model to either learner. A zero exit is an evidence-policy result,
not unconditional equivalence of arbitrary SQLite programs.

Each completed comparison saves:

- comparison.json: evidence, inference results and actual comparison status.
- replay-words.json: confirmed inputs, or a fixed smoke sequence when no difference is found.
- counterexample-words.json: saved only when a difference was actually confirmed.
- left-replay.json and right-replay.json: fresh execution of those inputs.
- SUMMARY.md: readable verdict and stated assumptions.

Exit codes: 0 meets the evidence policy, 1 is execution/configuration/output
failure, 2 is a freshly confirmed difference, 3 is insufficient evidence.
Outputs use CreateNew. A failed run can leave partial evidence files; inspect
its exit code and logs before treating any file as an accepted result.

Wp work can grow exponentially with the gap between the declared bound and the
hypothesis size. A loose bound may exhaust the run timeout; do not lower a bound
without an independent justification. The controlled mappings here use the same
documented 6/4 assumptions as the source integration examples.

Copy [regression.example.yml](regression.example.yml) to
.github/workflows/regression.yml in the new repository. It runs the ordinary
comparison. Enable the controlled mutation manually to see a failing gate and
download its evidence. GITHUB_STEP_SUMMARY is populated by the consumer.

From the source repository root, maintainers can verify these exact committed
source files against an **explicit public version**:

```sh
moon run tools/verify_consumer.mbtx -- 0.2.2
```

The verifier copies the example to a fresh temporary module, selects that public
version, checks its installed version, and requires exit 0 and exit 2 in the two
scenarios. Candidate CI may select the previous public release to check existing
API compatibility; that result is not evidence for an unpublished new package.
