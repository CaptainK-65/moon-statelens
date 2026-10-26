# Validation record — 0.2.0

Date: 2026-10-20. Compiler/core 0.10.15+943464bfa, moon 0.1.20261012.
The [0.1.0 historical publication record](VALIDATION-v0.1.md) remains available.

## Source and integration

- Portable backends have 51 named tests each (wasm, wasm-gc, JS).
- Native adds 15 runner/adapter/integration tests, for 66 total.
- Generated corpora are contained within named tests: 200 one-to-twenty-state
  targets, all 256 binary two-state transition/output tables for both learners,
  Wp vs independent exact comparison for all 65,536 ordered model pairs,
  plus the existing 40-model characterization cross-check.
- Native tests use actual asynchronous suspension, HTTP sockets, subprocesses
  and an independently installed sqlite3 CLI, not mock transports alone.
- Failure cases include fragmented UTF-8, wrong IDs, invalid/oversized frames,
  stderr overflow, failed exits, hanging close, cancellation, error priority,
  trace truncation, observation drift and spurious hypothesis differences.
- SQLite is learned as a six-state abstraction, without receiving a reference
  machine. The independent reference is used only after learning.

Completed local commands include source check/build, core/runner/adapter tests,
legacy CLI verification and the complete native CLI verification. Final matrix
results and registry publication are recorded below after they finish.

```sh
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
moon run tools/update_native_interfaces.mbtx
moon run tools/verify_cli.mbtx
moon run tools/verify_native.mbtx
```

Full integration verifies L*/KV SQLite learning, exact comparison of their learned
models, comparison against a CONTROLLED rollback-as-commit adapter, fresh replay
on both targets, independent HTTP process learning, evidence-aware exit codes,
timeout classification, artifact generation and overwrite protection.

The observed SQLite difference is begin -> put -> rollback -> read, with final
outputs empty/present. This is an intentionally injected adapter defect, NOT a
SQLite bug claim. JSONL/HTTP session implementations are controlled fixtures.

## Cost data and reproducibility

The query study is regenerated after scheduling changes. v0.2 removes some
duplicate logical cache requests, while the existing reference study's physical
query/step totals remain unchanged. Old snapshots are available in the v0.1 tag.

The L*/KV study uses identical Wp plans and fixed targets; neither algorithm is
claimed universally faster. Native evidence records actual run reports rather
than inventing timing or adoption numbers.

Compiler-generated native API snapshots are regenerated through
tools/update_native_interfaces.mbtx because moon info keeps wasm as the module's
canonical backend. CI checks these bytes for drift.

## CI and publication status

Source candidate [bd82947](https://github.com/CaptainK-65/moon-statelens/commit/bd829474efa83639bbab321a293d6f23dce36790)
is tested in [CI 39407101805](https://github.com/CaptainK-65/moon-statelens/actions/runs/39407101805).
All three source jobs completed successfully, including real SQLite, JSONL,
HTTP and full native CLI verification on Linux, macOS and Windows.

Registry consumer jobs on that source candidate verified the previously published
0.1.0; they are not used as evidence for the new publication.

## Publication completed

- Published CaptainK-65/moon-statelens@0.2.0 on 2026-10-20. Actual publication
  returned HTTP 200 and CLI exit 0.
- Package source commit: 2b915a54bfb3ecc9ab43d089bab01bb61683dcec (PR #6 merge),
  with a tree identical to source-tested 78bc401.
- Source CI: [39408430003](https://github.com/CaptainK-65/moon-statelens/actions/runs/39408430003),
  all three platform/source/native-integration jobs successful.
- Uploaded ZIP SHA-256:
  15a635b28e33155a1e21f9972ea102951d95e2d08371d08d1538666528b4cfc2.
- [GitHub release](https://github.com/CaptainK-65/moon-statelens/releases/tag/v0.2.0)
  provides the uploaded ZIP; [Mooncakes](https://mooncakes.io/docs/CaptainK-65/moon-statelens@0.2.0)
  provides the installable package.
- Four clean local consumer modules downloaded the actual public 0.2.0 package
  and passed on wasm, wasm-gc, JS and native. They exercised both learners, Wp,
  model JSON and legacy compatibility. Native additionally imported the published
  runner/adapters and executed real SQLite transactions.
- Published-consumer CI now targets 0.2.0 and includes SQLite for the native case.
  Current runs are linked from the repository's Actions page.
- The dry-run service returned HTTP 202 success, but the client exited 1;
  this known client behavior is retained, not reported as a clean dry-run exit.
  The extracted ZIP separately passed all-target checking before publication.

Finite testing does not establish universal correctness, global uniqueness,
arbitrary black-box equivalence or competition acceptance.
