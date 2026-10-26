# Validation record — 0.2.2

Date: 2026-10-26. Frozen candidate and publication evidence are recorded below
as they complete; this file does not claim a pending release is already public.

Historical records remain available:
[0.1.0](VALIDATION-v0.1.md), [0.2.0](VALIDATION-v0.2.0.md), [0.2.1](VALIDATION-v0.2.1.md).

## Verified during implementation

- Baseline check/test passed: 51 named tests on each portable backend and 66 on native.
- The new artifact regression first failed because compare did not save its declared report.
- After the fix, all eight integration tests passed, including five new regressions.
- Native total is now 71; portable tests remain 51 per backend.
- CLI verification passed offline validation, comparison/replay outputs, private-setting omission, evidence-aware exits and overwrite rejection.
- The unified source acceptance command completed during development. Final commit evidence must come from a clean, unchanged checkout or CI, rather than that moving development tree.
- The corrected native verifier downloaded public 0.2.1 and exercised offline validation plus comparison/replay artifacts successfully. The standalone public 0.2.1 SQLite gate also passed exits 0/2 and fresh replays.
- The generated duplicate-import defect and the superseded 0.2.1 upload are documented in the historical record. Candidate CI now uses public 0.2.1 so it exercises the corrected native branch before 0.2.2 publication.

## Commands for the frozen candidate

```sh
moon run tools/verify_acceptance.mbtx
moon run tools/verify_published.mbtx -- wasm 0.2.2
moon run tools/verify_published.mbtx -- wasm-gc 0.2.2
moon run tools/verify_published.mbtx -- js 0.2.2
moon run tools/verify_published.mbtx -- native 0.2.2
moon run tools/verify_consumer.mbtx -- 0.2.2
```

Source CI pins compiler/core 0.10.15+943464bfa, moon 0.1.20261012, explicit OS
labels and action revisions. It saves environment, actual command exits, logs,
native reports and GitHub summaries. Public consumer jobs name their selected
registry version explicitly. Source and registry results are separate evidence.

## Result interpretation

Both learners, W/Wp, cache/conflict semantics and legacy model/report formats
remain supported. Offline validation checks declared configuration semantics;
it does not prove a reset contract, target availability or state upper bound.
Wp work can increase sharply for loose bounds. The real SQLite examples use
declared bounds 6 for normal and 4 for the deliberately mutated finite mapping.

A confirmed SQLite comparison concerns an injected adapter mapping defect, not
a claim about SQLite itself. Fresh replay evidence and evidence-aware exit codes
must be considered together. Failed writes can leave partial artifacts; outputs
are not a multi-file transaction.

No claim is made about universal correctness, arbitrary black-box equivalence,
production adoption or guaranteed competition acceptance.

## Frozen CI and publication

Pending. Actual commit, run URLs, public-package verification, archive digest
and selected reproducible evidence will be added after completion.
