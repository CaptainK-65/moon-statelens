# Standalone v0.3 API gate

This independent MoonBit module uses the public `CaptainK-65/moon-statelens@0.3.0`
package. Once that version is published:

```sh
moon update
moon run . --target native --deny-warn
```

It exercises suite import, full original assertions, prefix certificates,
normal/mutated execution, finite rule confirmation, multi-context diagnosis,
JUnit and offline HTML. The native branch calls the public integration API.
These are controlled examples; no third-party defect is alleged.

Before publishing, the repository runs **the same committed sources** against
an isolated workspace containing the candidate module. After publishing, it
runs them again with no workspace substitution and verifies the actual installed
registry version. From the repository root:

```sh
moon run tools/verify_v03_consumer.mbtx -- source wasm
moon run tools/verify_v03_consumer.mbtx -- source wasm-gc
moon run tools/verify_v03_consumer.mbtx -- source js
moon run tools/verify_v03_consumer.mbtx -- source native
moon run tools/verify_v03_consumer.mbtx -- public native 0.3.0
```

Portable backends use the identical `core.mbt` and a trivial portable main.
Receipts distinguish source verification from actual public downloads. Source
validation is not proof that a version has been uploaded to the registry.
