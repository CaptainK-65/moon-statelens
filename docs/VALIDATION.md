# Validation record — 0.1.0

Date: 2026-10-16. Local environment: Windows, MoonBit 0.10.15+943464bfa, moon 0.1.20261012.

The release candidate passes 41 tests on each of wasm, wasm-gc, JS and native. Counts include executable README examples. One generated-corpus test validates 200 targets; this is not presented as 200 separately named tests. Characterization tests cross-check 40 generated models against independent product BFS.

Commands completed locally:

```sh
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
moon run tools/verify_cli.mbtx
```

The real MoonLarder adapter learns a ten-state abstraction without receiving its reference table. The reference is used only after learning. The session regression is freshly replayed on both controlled adapters. The CLI smoke verifies JSON learning, exact-model comparison, replay, incorrect state bounds, report reproduction, overwrite protection and invalid arguments.

Linux, Windows and macOS source CI is public in [Actions](https://github.com/CaptainK-65/moon-statelens/actions). Successful earlier boundary-fix run: [e20c774](https://github.com/CaptainK-65/moon-statelens/actions/runs/38862174612). The latest branch run also includes the executable README tests.

`moon publish --dry-run` checked the extracted package and the service returned “Dry run completed successfully” with HTTP 202. The current CLI then exited nonzero; that client exit code is retained as a tool limitation, not reported as a clean command exit. Actual publication and clean registry-consumer verification are recorded separately after completion.

The README diagram was authored as SVG and visually checked after local browser rendering. No third-party bitmap assets are embedded.

## Publication completed

- Published `CaptainK-65/moon-statelens@0.1.0`; the service returned HTTP 200 and the CLI exited 0.
- The live registry returned version 0.1.0 with the expected repository and package summaries.
- Clean, separately generated consumer modules downloaded the registry package and exercised learning, model JSON round trips and replay-confirmed compatibility on wasm, wasm-gc, JS and native.
- Package source commit: `50ff75e1135825d926e2c92ea21f2addd7ca57db`.
- Source CI for that commit: [38863192445](https://github.com/CaptainK-65/moon-statelens/actions/runs/38863192445), all three platform jobs successful.
- Published ZIP SHA-256: `9e7b2717b110184da41c15f666339b32fcef65ff7597bf6fb4f6b87a5f0a74f2`.
- CI now additionally verifies the registry package in four independent consumer jobs without Mooncakes publishing credentials.

This record validates implementation behavior within the documented scope. It does not establish global uniqueness, arbitrary black-box equivalence or competition acceptance.
