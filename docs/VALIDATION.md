# Validation record — 0.3.0

Date: 2026-10-28. Historical stable baseline: [0.2.2](VALIDATION-v0.2.2.md).
Earlier records: [0.1](VALIDATION-v0.1.md), [0.2.0](VALIDATION-v0.2.0.md), [0.2.1](VALIDATION-v0.2.1.md).

## Source verification

[Initial v0.3 candidate CI](https://github.com/CaptainK-65/moon-statelens/actions/runs/40658111670)
passed all seven jobs: Linux/Windows/macOS source acceptance and four explicitly
selected public v0.2.2 compatibility checks. **Those public jobs do not prove
that v0.3.0 has been published.** Source acceptance tests the new v0.3 consumer
sources on all four backends against an isolated candidate workspace.

Selected evidence records immutable clean PR checkout
`1247abd2720a0f69b2fe87456f5e1b71d15f9736`, candidate head
`86475e3f69f1e05cc92cf315de98f9792caf9106` and Ubuntu SQLite 3.45.1.
The source CI includes four-backend checks/builds/tests, format and generated
interface drift, old integration tests, new fixed corpora, actual SQLite,
controlled HTTP/JSONL services, report/artifact output and independent consumers.
The additional real MoonLarder saved-suite demo is part of the final release gate.

| Backend | Named source tests |
| --- | ---: |
| wasm | 60 |
| wasm-gc | 60 |
| JS | 60 |
| native | 83 |

Generated models, exhaustive pairs and mutation cases are cases inside named
tests/studies, not thousands of individually named unit tests.

## Reproducible finite measurements

| Measurement | Result | Evidence |
| --- | --- | --- |
| New learning corpus | 60 minimal/reachable targets, 120 correct runs, both algorithms, up to 64 states | [scale study](evidence/v0.3.0/scale-study.json); exact reference oracle, not external-target W/Wp cost |
| Suite assertion preservation | 1,183 original cases, every output position preserved | [regression study](evidence/v0.3.0/regression-study.json); 30 models × W/Wp |
| Mutation detection | 1,080 inequivalent controlled output/target mutations killed | Same study; independent exact comparison; identical original failed cases before/after compaction |
| False positives | 0 on passing baselines and 30 state-renumbered equivalents | Finite corpus only; no universal guarantee |
| Physical reset reduction | Median 62.5% | Complete normal executions, same independent fresh rechecks; all samples retained |
| Deliberately nested prefix family | 87.5–98.4375% fewer resets | [separate state-cover study](evidence/v0.3.0/prefix-study.json), not W/Wp completeness or a representative workload |
| Actual SQLite diagnosis | 4 freshly confirmed contexts | [diagnosis](evidence/v0.3.0/sqlite-diagnosis.json); contexts are not independent bugs |
| Defect shared by both versions | Equal actual targets in [diagnosis](evidence/v0.3.0/shared-defect-diagnosis.json), but [safety rule violation confirmed](evidence/v0.3.0/jsonl-mutant-rules.json) | Controlled session fixture |

Full metric definitions and limitations: [behavior validation](behavior-validation.md).
Root inference and analysis code uses MoonBit core only. W/Wp generation,
finite monitors and prefix sharing are established techniques independently
implemented here, not claims of algorithm invention.

## Distribution and exact-version public verification

The [v0.3.0 release](https://github.com/CaptainK-65/moon-statelens/releases/tag/v0.3.0)
records the final source commit/tree, tested candidate, actual uploaded ZIP hash,
registry result and post-upload checks. The actual public-download receipt is
appended after upload; source verification and package-publication evidence remain
separate. Later documentation/CI-selector commits do not replace the uploaded archive.

From a clean checkout with the pinned compiler/core 0.10.15+943464bfa,
moon 0.1.20261012 and sqlite3 on PATH:

```sh
moon update
moon run tools/verify_acceptance.mbtx
moon run tools/verify_v03_consumer.mbtx -- public wasm 0.3.0
moon run tools/verify_v03_consumer.mbtx -- public wasm-gc 0.3.0
moon run tools/verify_v03_consumer.mbtx -- public js 0.3.0
moon run tools/verify_v03_consumer.mbtx -- public native 0.3.0
moon run tools/verify_published.mbtx -- native 0.3.0
moon run tools/verify_consumer.mbtx -- 0.3.0
```

The same committed v0.3 consumer sources run before publication against candidate
source and afterward against an actual registry download. Their receipts explicitly
state which mode ran. The original public verification and standalone SQLite gate
also remain available for checking previous APIs and real transactions.

## Retained evidence and limits

[Provenance](evidence/v0.3.0/provenance.json) identifies the actual producer.
The selected evidence directory includes complete original study outputs, suite
and model files, per-case regression results, JUnit, fresh rule traces,
multi-context diagnosis and an [offline HTML report](evidence/v0.3.0/sqlite-diagnosis.html).
Artifacts are whitelisted public controlled examples; credentials are excluded.
The GitHub release retains evidence beyond the CI artifact retention window.

SQLite rollback-as-commit is deliberately injected in the adapter, not a SQLite
defect. Reliable reset, determinism, a finite alphabet/abstraction and correct
state bounds remain premises. Completed state/transition cover is model coverage,
not implementation code coverage. Truncated generation, pending queries, unstable
replays and resource exhaustion never yield an unconditional pass. Multi-file
artifact writes remain non-transactional; output failures cannot be accepted.
No claim is made about arbitrary program equivalence or production adoption.
