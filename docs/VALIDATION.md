# Validation record — 0.5.0

Acceptance date: 2026-10-30 (Asia/Shanghai). Historical published evidence:
[0.4.0](VALIDATION-v0.4.0.md), [0.3.0](VALIDATION-v0.3.0.md).

## Toolchain and source

Compiler/core **0.10.18+6c83a7f62**, moon/moonrun **0.1.20261028**.
This exceeds the contest minimum moonc 0.10.16. Official Windows archive SHA-256:
`249c53518a4b63fbb2577734e03f3f7e0ca15614ba6e66255359315bed9bc73a`, matched locally.
The toolchain is isolated from the older global installation. Compiler-generated
interfaces now spell Int32 explicitly; snapshots were regenerated, not hand-edited.

Local named tests after migration: **69 each wasm/wasm-gc/JS, 93 native**, zero failures.
New tests cover alphabet extension/removal, state renumbering, product-pair limits,
fresh recorded counterexample outputs for both learners, callback equivalence and
terminal incomplete events. Full acceptance and distribution receipts follow below
after their actual completion; pre-publication CI may still check public 0.4.0.

## Browser and independent consumers

`moon run tools/build_evolution_demo.mbtx` builds actual MoonBit executables.
`moon run tools/verify_browser.mbtx` runs all 17 page checks in Linux Chrome;
failure blocks CI and retains DOM and stderr in `_build/browser-acceptance/`.
File-protocol fixture execution uses an explicit browser flag; ordinary online use
does not require it. `verify_lab_wizard.mbtx` checks generated configs with the native CLI.

Evolution consumers now exercise `backward_compatibility` and the learning event
callback, as well as actual quota/token/cache inference and fresh version replay.
They run the same committed source before publication in an isolated workspace and
afterward against a public package download. These two evidence modes remain separate.

## Finite results and limits

The retained historical 20-pair evolution study records 61.02% median reset reduction
including Wp verification; the actual default quota case records 83→54 resets.
The AALpy 2.0.0 reference checks 20 explicit targets. These are finite results, not
universal speed or production-adoption claims; fresh release-gate outputs are retained
with the final evidence. The separate v0.3 compaction result of 62.5% is not added.

Directional compatibility is exact for supplied models on old-input histories;
new-operation histories and real target conformity are outside that conclusion.
W/Wp support depends on correct state bounds and reliable deterministic resets.
Imported evidence and checksum consistency do not certify actual execution.
Synchronous learning event callbacks are not async-runner tracing or resumable checkpoints.

## Publication status

Release candidate 0.5.0. Actual upload, immutable source, archive digest and public
download verification will be recorded here after publication. The existing 0.4.0
release/package is not replaced or retagged.
