# Validation history — 0.2.1

Date: 2026-10-26. Source commit:
50ddfeb3a1ec9eb7d7d834d3f9e0038bd9d436a5.
Its tree c0b3db1ea42ff390eee1358cff7e2550fd709a3c is identical to tested
candidate dc0820618e896a1ccdb6d0287efbf26c864cb1e8.

- Candidate CI: https://github.com/CaptainK-65/moon-statelens/actions/runs/40258706865
- Default-branch CI: https://github.com/CaptainK-65/moon-statelens/actions/runs/40259200739
- All seven jobs passed, with 51 named tests per portable backend and 71 native.
- Source CLI verification reproduced missing artifacts before the fix and
  passed offline validation, output ownership, alias/overwrite protection and
  an actual target-created-file race after the fix.
- Registry publication returned HTTP 200 and client exit 0.
- Uploaded ZIP SHA-256:
  29ae16038232b3225a08fcba21af295625da219c8e93562a856cabd220b241a4.
- Initial public-package checks passed wasm, wasm-gc and JS.
- Initial public native verification stopped before application compilation:
  the verification script generated two import blocks in moon.pkg (E4192).
  This was a verifier configuration defect, not evidence of a library runtime failure.
- After fixing the script, actual public 0.2.1 native checks passed, including
  Config.validate and persisted comparison/replay reports. The standalone
  SQLite consumer also passed normal/controlled-mutation exits 0/2 and fresh replays.
  These checks used the repaired repository verifier, not the defective script
  inside the original 0.2.1 upload.
- Version 0.2.2 supersedes the upload so the distributed verification script
  itself also includes the correction.
- Dry-run service success (HTTP 202) was accompanied by client exit -1 and
  was not counted as a clean client success.

Historical records: [0.1.0](VALIDATION-v0.1.md), [0.2.0](VALIDATION-v0.2.0.md).
