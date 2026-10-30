# Validation record — 0.4.0

Date: 2026-10-29. Historical stable evidence remains in
[0.3.0](VALIDATION-v0.3.0.md), including its immutable package/release receipts.

## Source and independent-reference gate

[Final candidate CI](https://github.com/CaptainK-65/moon-statelens/actions/runs/40808040911)
passed all eight jobs: Linux/macOS/Windows source acceptance, an independent AALpy
reference job, and four legacy public **0.3.0** compatibility jobs. The latter
do not establish publication of 0.4.0.
Candidate head is `0590fbade7cd0e8dcb45d32a896e9b12c65ed143`;
actual clean PR checkout is `f6456ec46ab0aa58b0a02075cc3d16b953f93028`.
The candidate was merged as `d08c28ec6d9b13db20b175fbafd1ad3ab886101b`.

| Backend | Named tests passed |
| --- | ---: |
| wasm | 64 |
| wasm-gc | 64 |
| JS | 64 |
| native | 88 |

All source platforms check/build/test four backends, generated interfaces and
format, actual SQLite/HTTP/JSONL targets, v0.3 studies and four-backend independent
source consumers of the new evolution APIs. Compiler/core is
0.10.15+943464bfa, moon 0.1.20261012; Ubuntu SQLite is 3.45.1.
Selected original [CI evidence](evidence/v0.4.0/ci/provenance.json) retains the
environment, commands, test summary, study, reference models and equivalence receipt.

## Finite measurements

| Measurement | Actual result | Scope |
| --- | --- | --- |
| History-guided L* | 61.02% median physical reset reduction, including Wp verification | 20 fixed delayed-observation version pairs, 3–12 states; baseline already available; zero-benefit cases included |
| Independent AALpy 2.0.0 reference | 20/20 targets observably equivalent | Independent L* with exact reference oracle, then exact model comparison; no throughput comparison |
| Changed-structure correctness | 60 target pairs | Historical structure may be unrelated; new observations and exact-oracle correctness, not a performance corpus |
| Binary KV delayed split | Linear processing/rebuild >1,000 queries; binary <30 | One 1,025-input delayed-split case; short counterexamples can favor linear splitting |
| Actual quota upgrade | 83 cold resets → 54 history-guided resets | MoonLimit capacity 2→3; models have 3→4 states; third acquisition freshly differs |
| Actual token bucket / LRU | 3 / 10 observable states | Finite explicit-time MoonLimit abstraction / existing finite MoonLarder abstraction |

[Workflow and limitations](evolution.md), [raw CI study](evidence/v0.4.0/ci/study.json),
[independent reference receipt](evidence/v0.4.0/ci/receipt.json).
Counts inside generated studies are not individually named unit tests.
The v0.3 suite-compaction median of 62.5% is a different experiment and is not
added to the history-guidance gain. No result promises universal performance,
unbounded equivalence or production adoption.

## Reproduction

```sh
moon update
moon run tools/verify_acceptance.mbtx
moon run examples/evolution
moon run tools/build_evolution_demo.mbtx
```

For the independent AALpy environment and exact-reference command, see
[evolution guide](evolution.md). The browser HTML contains actual compiled MoonBit
code and can also run locally without a network connection.

## Distribution

[Publication-source main CI](https://github.com/CaptainK-65/moon-statelens/actions/runs/40810486063)
passed all eight jobs. It still selected public 0.3.0 compatibility; the post-upload
checks below are the independent evidence for 0.4.0.

Actual upload returned HTTP **200**, client exit **0**. Publication source is
`b6c3cf3f0e231ef38fbe60de8b1dd9efdfcba9ee`, tree
`559f2cc5b5751287c7e849da0c7a3e2916c5840d`. Only documentation/assets/evidence
changed between the tested candidate and this frozen upload source.
The actual uploaded ZIP contains 2,643,510 bytes; SHA-256 is
`b7fd31da2fbb4a726786825794e65621ddf8f6ecfa5afe87eab53d6796558321`.

After upload, **nine actual public-download checks passed**: legacy and evolution
consumers on each of wasm/wasm-gc/JS/native, plus the independent actual SQLite
gate. The [receipt](evidence/v0.4.0/public-verification.json) records a clean verifier
checkout and every command exit. Public evolution consumers use the same committed
test sources as source consumers and exercise actual quota/token/cache learning
and fresh replay. The SQLite controlled mutation must confirm a difference.

The [v0.4.0 release](https://github.com/CaptainK-65/moon-statelens/releases/tag/v0.4.0)
retains the actual uploaded ZIP and selected evidence beyond CI artifact retention.
See the structured [publication record](evidence/v0.4.0/publication.json).
Later evidence, CI-selector and browser-license documentation updates do not
replace this package archive or frozen source. The historical 0.3.0 records remain intact.

The [live browser laboratory](https://captaink-65.github.io/moon-statelens/demo/)
was actually executed in Edge: 3/4 quota states, 83/54 resets and the freshly
confirmed acquire/acquire/acquire difference. The offline HTML includes its
third-party source attribution and Apache-2.0 text.
