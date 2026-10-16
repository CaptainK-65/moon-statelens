# Contributing

Use MoonBit 0.10.15 / moon 0.1.20261012 or a compatible newer stable toolchain. Automation belongs in .mbtx files; the root package must remain independent of third-party inference engines.

```sh
moon update
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
moon run tools/verify_cli.mbtx
```

Add behavioral regressions for algorithm or boundary changes. Generated models need reproducible seeds. Claims of equivalence must state their evidence and assumptions. Do not add empty commits or fabricate adoption and performance results.

When experiment scheduling or counters change, run moon run tools/update_evidence.mbtx, inspect the evidence diff and rerun the CLI smoke. Format scripts explicitly with moon fmt tools/verify_cli.mbtx tools/update_evidence.mbtx. Never hand-edit generated .mbti files.

New target adapters must document reset semantics, finite input/output abstractions, state-bound justification and cleanup. Keep actual third-party components distinct from controlled fixtures. Preserve upstream licenses and source notices.
