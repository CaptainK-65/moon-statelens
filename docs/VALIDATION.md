# Validation record — 0.2.2

Date: 2026-10-26. Final distributed patch: CaptainK-65/moon-statelens@0.2.2.

Historical records: [0.1.0](VALIDATION-v0.1.md),
[0.2.0](VALIDATION-v0.2.0.md), [0.2.1](VALIDATION-v0.2.1.md).

## Frozen source and CI

- Publication source commit: b925110a028148fa5e306317e27a0c32af3d3453.
- Source tree: da1569a45aba2b8b8c9237c8021c970ec3ab8d3f; identical to candidate
  118bef412490dc09f835c3f1da5d286261c6a2fe.
- [Candidate CI](https://github.com/CaptainK-65/moon-statelens/actions/runs/40260754530)
  and [default-branch source CI](https://github.com/CaptainK-65/moon-statelens/actions/runs/40261462438)
  both passed all seven jobs.
- Linux/Windows/macOS source validation includes four-backend check/build/test,
  formatting, generated-interface drift, real HTTP/JSONL/SQLite, CLI artifacts
  and an actual target-created-file race after output preflight.
- That source CI's public-consumer jobs explicitly selected 0.2.1, exercising
  the repaired native configuration/artifact branch before 0.2.2 publication.
  They are separate from the actual public 0.2.2 checks recorded below.
- The selected source environment records a clean checkout at the publication
  commit. All recorded source command exits are 0.

| Backend | Named source tests |
| --- | ---: |
| wasm | 51 |
| wasm-gc | 51 |
| JS | 51 |
| native | 71 |

Five new integration regressions and CLI verification cover offline parsing,
artifact persistence, aliases, overwrite protection, unsupported replay outputs,
private-setting omission and write failures. Generated corpora remain cases
inside named tests, not tens of thousands of separately named tests.

## Registry publication and actual public consumers

- Actual 0.2.2 registry upload returned HTTP **200**, client exit **0**.
- Uploaded archive SHA-256:
  84d58d7e36b412b9977b05be6e671668633d51ce6313cca6c473c88db739e7e7.
- [GitHub release](https://github.com/CaptainK-65/moon-statelens/releases/tag/v0.2.2)
  attaches the actual uploaded ZIP.
- [Mooncakes 0.2.2](https://mooncakes.io/docs/CaptainK-65/moon-statelens@0.2.2)
  is the public package selected by fresh independent consumers.
- All four public backend checks exited 0 after downloading the actual 0.2.2
  module. Native additionally exercised Config.validate, persisted comparison
  and replay reports, and real SQLite transactions.
- The standalone public 0.2.2 consumer passed normal exit 0 and deliberately
  mutated exit 2; saved fresh replays differed.
- [Public verification receipt](evidence/v0.2.2/public-verification.json)
  records all five actual successful command exits from verifier checkout b925110.
- The 0.2.1 generated-consumer import defect was fixed and tested against public
  0.2.1 before publishing 0.2.2, so the distributed verifier is also corrected.

The uploaded archive captures pre-upload publication status. This current GitHub
record appends the post-upload receipts; later documentation/CI-selector commits
do not replace the publication source or the uploaded archive.

## Reproduction

From a clean repository checkout, first bootstrap a fresh registry:

```sh
moon update
moon run tools/verify_acceptance.mbtx
moon run tools/verify_published.mbtx -- wasm 0.2.2
moon run tools/verify_published.mbtx -- wasm-gc 0.2.2
moon run tools/verify_published.mbtx -- js 0.2.2
moon run tools/verify_published.mbtx -- native 0.2.2
moon run tools/verify_consumer.mbtx -- 0.2.2
```

CI pins compiler/core 0.10.15+943464bfa and moon 0.1.20261012, explicit runner
labels and action revisions. Source verification writes environment, commands,
logs and summaries; public verification always names its registry version.
See [acceptance mapping](ACCEPTANCE.md) and the [current CI](https://github.com/CaptainK-65/moon-statelens/actions/workflows/ci.yml).

## Selected retained evidence

[Evidence provenance](evidence/v0.2.2/provenance.json) links selected public-only
files to source CI and the actual publication commit. The directory includes
source commands/test output, offline validation, explicit-model comparison and
replay, a real output-write failure, and real SQLite comparison/fresh replays.
It excludes ephemeral target configuration files and credentials. CI keeps full
artifacts for its retention window; the GitHub release also retains this selected
evidence as an attachment.

SQLite's defect is deliberately injected in the adapter mapping. W/Wp evidence
depends on the declared finite abstraction, deterministic reliable reset and
correct state bounds (normal=6, controlled mutant=4). Offline validation does not
prove those behavioral premises. Output logs may be bounded/truncated, and
multiple artifact writes are not a transaction; a failed write is an execution
failure even if inference first computed a valid model or confirmed difference.
No claim is made about arbitrary black-box equivalence or production adoption.
