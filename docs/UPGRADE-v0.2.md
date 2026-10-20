# v0.2 engineering work log

Status: in development, not released. Existing v0.1.0 remains the published release.

## Accepted scope

Independent KV and L* learners; resumable query execution; Wp and composed
verification; native asynchronous runners; JSONL subprocess and HTTP adapters;
a real SQLite CLI integration; configuration, fresh compatibility replay,
versioned reports and reproducible CI evidence.

## Completed core work (2026-10-20)

- Extracted IO-independent QuerySession. The original synchronous Experiment
  delegates cache, attempted-call budgets and conflict poisoning to it.
- Added continuation-based LearningDriver. Each continuation keeps the actual
  table/tree phase; resuming never reruns the learner from the beginning.
- L* uses the suspended driver; the synchronous custom Oracle API still works.
- Added independent KV state classification and counterexample splitting.
- Added lazy W/Wp verification cursors, replay/random/exhaustive/exact plans,
  stage logs and ordered strategy chains.
- Added all 256 binary two-state transition/output targets to learner tests.
- Compared Wp to independent exact model comparison for all 65,536 pairs of
  those two-state targets.
- Local wasm check/test passes: 50 named tests, including existing 200-target
  corpus and new exhaustive subcorpora. This is not yet an async/platform claim.

## Completed native work (2026-10-20)

- Added native asynchronous runner with actual suspension, timeout and cancellation.
- Sync/async runs have identical statistics under the same learner and plan.
- JSONL supports bounded UTF-8 framing, request IDs, separate bounded stderr,
  fault detection and protected process reaping even during cleanup cancellation.
- Added configurable finite HTTP actions, output abstraction and session headers.
- Real sqlite3 CLI learned as a six-state transaction abstraction with KV + Wp;
  an independent reference was used only after learning.
- Ten native runner/adapter tests pass locally on Windows, including real sockets,
  real processes, invalid frames, failed exits and injected timeouts.
- Native integration tests require first running moon build --target native and
  having sqlite3 on PATH. Test fixture paths are compiler output paths.

## Remaining gates

- Configuration, native CLI integration, versioned report and fresh replay.
- Four-backend core tests, Linux native integration CI, publication/consumer tests.
- Updated application distinguishing implemented features from roadmap.

Algorithm references remain theoretical/behavioral references, not runtime
LearnLib/AALpy backends. No source code has been copied from them.

