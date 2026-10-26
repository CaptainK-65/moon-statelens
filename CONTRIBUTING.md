# Contributing

Use MoonBit 0.10.15 / moon 0.1.20261012 or a compatible newer stable toolchain. Automation belongs in .mbtx files; the root package must remain independent of third-party inference engines.

After an initial `moon update` to bootstrap the registry on a fresh toolchain,
the primary source acceptance entry point is `moon run tools/verify_acceptance.mbtx`.
It records environment, commit, initial working-tree state, command exits and logs.
Run it from a clean, unchanged checkout when recording final release evidence.
It exercises public controlled fixtures and writes under _build; use isolated
instances when adapting the framework to your own components.

CI pins compiler/core 0.10.15+943464bfa. Native tests require sqlite3 on PATH and a prior native build for the subprocess fixture. Regenerate native-only API snapshots with moon run tools/update_native_interfaces.mbtx; these are unmodified compiler output, not handwritten interfaces.

```sh
moon update
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
moon run tools/verify_cli.mbtx
moon run tools/verify_native.mbtx
```

Add behavioral regressions for algorithm or boundary changes. Generated models need reproducible seeds. Claims of equivalence must state their evidence and assumptions. Do not add empty commits or fabricate adoption and performance results.

When experiment scheduling or counters change, run moon run tools/update_evidence.mbtx, inspect the evidence diff and rerun the CLI smoke. Format scripts explicitly with moon fmt tools/verify_cli.mbtx tools/update_evidence.mbtx. Never hand-edit generated .mbti files.

New target adapters must document reset semantics, finite input/output abstractions, state-bound justification and cleanup. Keep actual third-party components distinct from controlled fixtures. Preserve upstream licenses and source notices.

Public-release verification requires an explicit version:
`moon run tools/verify_published.mbtx -- native 0.2.1` and
`moon run tools/verify_consumer.mbtx -- 0.2.1`.
Before publication, CI may select the previous public version; report that exact
version and do not use it as evidence for an unpublished candidate.
Format the nested consumer from its own module directory with `moon fmt`.
