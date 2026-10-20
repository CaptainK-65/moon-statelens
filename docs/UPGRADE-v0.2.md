# v0.2 engineering completion

Implemented and published on 2026-10-20. Tracking: Issue #5, merged PR #6.
See VALIDATION.md for source, registry and artifact evidence.

## Delivered work packages

- E1: continuation-based query suspension; no restart per query.
- E2: migrated L* and synchronous compatibility facade onto shared query state.
- E3: independent KV classification tree and counterexample splitting.
- E4: lazy Wp, replay, composed verification and stage logs.
- E5: bounded JSONL process protocol and real SQLite transaction learning.
- E6: native HTTP actions, explicit abstraction and session handling.
- E7: strict configuration, v2 reports, evidence-aware CLI exits, fresh replay
  confirmation and spurious-difference refinement.
- E8: three-platform source/native CI, release ZIP, public registry installation,
  four-backend consumer verification, docs and updated application.

## Regression evidence

Portable backends: 51 named tests each. Native: 66 including real IO.
Embedded corpora: 200 generated targets, all 256 binary two-state machines for
both learners, and all 65,536 ordered pairs for Wp vs independent exact comparison.

The SQLite reference specification is used after learning, never supplied to the
learner. The rollback-as-commit mutation is intentionally injected in the adapter.
Session/HTTP fixtures are controlled examples, not third-party defect reports.

Cancellation during cleanup initially prevented reliable process reaping; the
protected wait fix is covered by hanging-close/timeout regressions. Scheduling
changes removed duplicate logical cache requests; deterministic evidence was
regenerated while physical totals in the original reference study stayed equal.

## Published artifacts

- GitHub: https://github.com/CaptainK-65/moon-statelens/releases/tag/v0.2.0
- Registry: https://mooncakes.io/docs/CaptainK-65/moon-statelens@0.2.0
- Contracts: native.md and algorithms.md.
- Reviewer response: review-response-v0.2.md; application: ../APPLICATION.md.

## Remaining roadmap, not v0.2 claims

TTT, optimized counterexample processing, nondeterministic/probabilistic/timed
models, concurrent interleaving inference, unbounded parameter domains and
cross-version checkpoint recovery. The present async executor operates a
deterministic resettable finite abstraction sequentially.

Original synchronous APIs and v1 model interchange remain available. Native
consumers explicitly import moonbitlang/async for async main. No external
LearnLib/AALpy engine is embedded, copied or invoked.

