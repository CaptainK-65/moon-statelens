# Native component integration (v0.2)

These APIs and configuration commands are native-only. The root algorithms
remain portable across wasm, wasm-gc, JS and native. Asynchronous IO is sequential
within a target session; concurrent/nondeterministic target learning is outside scope.

## Reproduce real components

Install a compatible MoonBit toolchain and make `sqlite3 --version` work.
CI pins compiler/core `0.10.15+943464bfa`.

```sh
moon update
moon build --target native --deny-warn
moon run cmd/statelens --target native -- run-config configs/session-jsonl.json
moon run cmd/statelens --target native -- run-config configs/sqlite-kv.json
moon run cmd/statelens --target native -- run-config configs/sqlite-lstar.json
moon run cmd/statelens --target native -- replay-config configs/sqlite-kv.json configs/sqlite-words.json
moon run cmd/statelens --target native -- compare-config configs/sqlite-kv.json configs/sqlite-mutant.json
```

The comparison intentionally exits **2**, after actually reproducing different
outputs. `sqlite-mutant.json` injects an adapter defect that maps ROLLBACK to
COMMIT. It does NOT allege a defect in SQLite. Both targets use the actual CLI.
The SQLite scope is one fixed row, BEGIN/PUT/DELETE/COMMIT/ROLLBACK/READ, with
normalized transaction errors. Each physical query starts a new :memory: database.
The independent six-state reference exists only in tests, after learning.

For the controlled HTTP example, run this in one terminal:

```sh
moon run cmd/http_fixture --target native -- 41080
```

Then in another terminal:

```sh
moon run cmd/statelens --target native -- run-config configs/http-session.json
```

The fixture is a separate controlled process. Automated verification uses an
OS-assigned port, not a globally reserved test port.

```sh
moon test --target all --deny-warn
moon run tools/verify_cli.mbtx
moon run tools/verify_native.mbtx
```

Build first: native adapter tests execute the compiler-produced fixture binary
at `_build/native/debug/build/cmd/fixture/fixture.exe` (including on Unix).
The native verification script saves reports under `_build/v0.2-evidence/run-*/`.

## Configuration contract

See `configs/` for complete version-1 experiment files. Top-level fields:
format/version, identity, abstraction, alphabet, learner, target, verification,
budgets, expectations and optional artifacts. Unknown keys and invalid numeric
ranges are rejected. Identity and abstraction must be explicitly supplied.

Learners: `lstar` and `kv`. Plans: `exact`, `exhaustive`, `random`, `w`,
`wp`, `replay`, `chain`. W/Wp require a user-supplied `state_bound`; this is
a premise, not a bound established by the tool. Chain returns the last stage's
evidence only if every stage completes without a counterexample. An incomplete
stage stops the chain. Every experiment-based conformance query bypasses cache.

Target kinds:
- `model`: wraps a complete explicit model for reproducible experiments.
- `jsonl`: launches an executable and separate argument array. The target or
  bridge must implement the protocol below; arbitrary CLI tools are not inferred
  without a mapping.
- `sqlite`: dedicated real SQLite CLI mapping.
- `http`: finite literal action mapping, reset/close hooks and optional session token.

HTTP actions configure path, verb, body, output_field and expect_status.
Supported verbs are GET/POST/PUT/DELETE/PATCH. A top-level JSON scalar is selected
as output. Empty output_field selects `status:N`; expect_status=0 accepts any
HTTP status. Reset and close hooks must return the abstract output `ok`.
An optional session_field from reset is carried through session_header.
No automatic retry of state-changing requests is performed. Failure to reset,
timeout, invalid JSON and IO failure are execution failures, not business outputs.

## Evidence policy and exits

New configuration commands have these exit meanings:
- 0: the configured evidence expectation was met, or replay completed.
- 1: invalid configuration, transport/protocol/target failure or timeout.
- 2: a difference was confirmed by fresh queries to both targets.
- 3: incomplete, unstable or insufficient evidence.

`budgeted` accepts a supported finite experiment; it is not an equivalence proof.
`conditional-state-bound` requires completed W/Wp with the stated assumptions.
`exact-reference` is accepted only for model-backed targets; an explicit
reference cannot certify that an arbitrary external adapter implements it.

Equal learned models return `no-difference-between-hypotheses`; read both
configurations and learning evidence. Candidate differences that do not reproduce
are added as fresh regression experiments and trigger relearning. Limits and
observation drift never become confirmed differences.

Legacy CLI commands retain their old exit and report semantics.

## JSONL lifecycle

One process per physical query; reset -> step* -> close. Each step within that
query uses the same process. The callback-based `with_jsonl`/`with_sqlite`
scope owns its task group; AsyncSystem must not escape that scope.

Request:
```json
{"version":1,"id":7,"method":"step","input":"login"}
```
Response:
```json
{"version":1,"id":7,"ok":true,"output":"ok"}
```

Reset/close use the same envelope and must acknowledge `ok`. Stdout contains
protocol only; stderr is separately bounded. Partial reads and UTF-8 boundaries
are handled. IDs, versions, frames, EOF and final exit are checked. Default
frame limit is 1 MiB and stderr limit is 64 KiB. Both are configurable with caps.

The runner bounds reset/step/query/cleanup waits. Cancellation triggers protected
process reaping; cleanup may extend past a query deadline. The supervisor owns
the direct child, not arbitrary descendant process trees. Timeouts are not a
sandbox or preemption of arbitrary synchronous target computation.

## Artifacts and reports

Optional artifacts: report, model, dot and traces. Files must not already exist;
writes use CreateNew. Model/DOT are omitted if no complete model exists.
Different output files are not a filesystem transaction: interrupted writes can
leave partial files, and a write failure does not imply an accepted run.

Traces contain successful logical queries, including labelled cache hits.
Failures are not stored as observations. Trace logging is bounded at 10,000
entries and 2,000,000 serialized UTF-16 code units when enabled through config;
the artifact explicitly records truncation. Selected outputs may contain
application data, so choose and review the declared abstraction.

v2 run/inference/comparison envelopes contain v1 complete models and learning
results for interoperability. KV reports real tree metrics; its table cell
counts are zero. Target credentials/settings are not dumped in manifests.
The manifest records declared identity, abstraction, algorithm, budgets and
verification plan; it is not an automatically verified target version/hash.

## Public API discovery

Use `moon ide doc` in the source tree or inspect generated interfaces:
- `runner/pkg.generated.mbti`
- `adapters/native/pkg.generated.mbti`
- `integration/pkg.generated.mbti`

The toolchain writes canonical wasm interfaces by default. Regenerate native
snapshots using `moon run tools/update_native_interfaces.mbtx`, which copies
unmodified native `moon info` compiler output. CI rejects snapshot drift.

