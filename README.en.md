# MoonStateLens

[中文](README.md) · [Tested quick start](README.mbt.md) · [Architecture](docs/architecture.md)

![MoonStateLens overview](docs/assets/overview.png)

A MoonBit-native active Mealy learner that infers observable states through reset/step experiments and confirms behavioral regressions by replaying distinguishing words on both actual adapters.

The root library supports wasm, wasm-gc, JS and native. Version 0.2 adds independent L* and KV learners, W/Wp and composed verification, resumable query execution, and native asynchronous HTTP, JSONL subprocess and real SQLite CLI adapters. Systems remain deterministic, resettable and finite under an explicit abstraction. See [native integration](docs/native.md) and [algorithm invariants](docs/algorithms.md).

## Run

```sh
moon update
sqlite3 --version
moon build --target native --deny-warn
moon test --target all --deny-warn
moon run examples/session
moon run examples/regression
moon run examples/lru
moon run cmd/statelens --target native -- demo regression
moon run tools/verify_cli.mbtx
moon run cmd/statelens --target native -- run-config configs/sqlite-kv.json
moon run tools/verify_native.mbtx
```

CI pins compiler/core 0.10.15+943464bfa / moon 0.1.20261012. Native tests require SQLite on PATH and built fixture executables. Install the package with `moon add CaptainK-65/moon-statelens@0.2.0`, then import `"CaptainK-65/moon-statelens" @lens` in your package. Portable core-only tests can use the wasm backend.

## Independent core

Observation-table L*, classification-tree KV, suffix observations, hypothesis construction, counterexample refinement, bounded conformance experiments, minimization and shortest distinguishing sequences are implemented here. Standard collections and JSON are reused. Async IO serves native runners/adapters and the CLI. MoonLarder and SQLite are real systems under learning, not inference engines.

The real LRU adapter learns a ten-state observable abstraction: capacity two, three fixed keys, values equal to keys, no TTL, and hidden statistics. Session fixtures demonstrate a replay-confirmed login/logout/request regression. They do not allege a third-party vulnerability.

## Evidence scopes

- `confirmed-difference`: reproduced outputs differ on the actual adapters.
- `no-difference-between-hypotheses`: learned models agree, subject to both learning results' evidence.
- `exact-reference`: equivalence to the supplied explicit model; the caller establishes adapter correspondence.
- `conditional-state-bound`: complete W/Wp execution under the stated bound and deterministic, total, resettable Mealy assumptions.
- `budgeted`: no counterexample found in the completed finite experiment.
- `inconclusive`: a budget or prerequisite prevented completion.
- `unstable` or `unstable-during-replay`: inconsistent observations, with the conflicting trace retained.

Observed conflicts invalidate the session. Cache bypass and periodic checks provide evidence of stability, not proof of determinism. Output abstraction is explicit and may hide differences. Async IO does not add learning of concurrent interleavings, stochastic/timed models or infinite data domains.

## Validation

The suite includes 200 generated targets, delayed distinguishing suffixes, independent reverse-pair/BFS cross-checks, mutation witnesses, real-library integration, replay and resource boundaries. CI checks all four library backends on Linux, Windows and macOS, plus the native CLI.

`benchmark` emits a deterministic [query-cost reference study](docs/evidence/query-study.json). Active costs include learning and W-method testing; exhaustive validation receives the final model. It is not a like-for-like learner speedup claim.

[LearnLib](https://learnlib.de/) and [AALpy](https://github.com/DES-Lab/AALpy) are related implementations in other languages, not runtime dependencies. This is an independent implementation of published research, not a claim to invent active learning. See [provenance](THIRD_PARTY_NOTICES.md), [ecosystem audit](docs/ecosystem-audit.md) and [LICENSE](LICENSE).
