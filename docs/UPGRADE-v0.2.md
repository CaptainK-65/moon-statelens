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

## Remaining gates

- Actual delayed async, timeout/cancellation/cleanup verification.
- Real process/HTTP/SQLite targets and malformed/fragmented protocol tests.
- Configuration, native CLI integration, versioned report and fresh replay.
- Four-backend core tests, Linux native integration CI, publication/consumer tests.
- Updated application distinguishing implemented features from roadmap.

Algorithm references remain theoretical/behavioral references, not runtime
LearnLib/AALpy backends. No source code has been copied from them.

