# Sources and dependencies

MoonStateLens is an independent MoonBit implementation of published ideas in active automata learning. It does not embed or invoke LearnLib or AALpy, and no source files were copied from them.

- Dana Angluin, *Learning regular sets from queries and counterexamples*, Information and Computation 75(2), 1987. DOI: https://doi.org/10.1016/0890-5401(87)90052-6. The original formalism is DFA; this project implements an output-suffix Mealy variant.
- [LearnLib](https://learnlib.de/) and [AALpy](https://github.com/DES-Lab/AALpy) were consulted for the established problem, reset/step adapter pattern and scope of equivalence oracles. They remain external references, not included source or runtime computation backends.
- [MoonLarder](https://github.com/jhshuai/moonlarder), package `jhshuai/moonlarder@0.15.0`, Apache-2.0, is a real system under learning in `adapters/moonlarder`. This cache is not the model-learning implementation. The adapter only calls its public API.
- `moonbitlang/quickcheck@0.15.0`, Apache-2.0, is a direct version override of MoonLarder's legacy 0.14.0 dependency so that the entire module graph uses metadata recognized by the October toolchain. The learner does not import QuickCheck.
- MoonBit core supplies standard collections, JSON and runtime facilities. They are not counted as new project algorithms.
- `moonbitlang/async@0.22.5`, Apache-2.0, supplies native runner/adapters, file/process/HTTP IO and verification automation. The root inference package does not import async.
- `moonbitlang/x@0.5.5`, Apache-2.0 (as declared in its module metadata), supplies platform-aware path normalization for native artifact destinations. It is not an inference engine; the root inference package does not import it.
- [SQLite CLI](https://www.sqlite.org/cli.html) is an externally installed real target, not bundled source or an inference dependency. SQLite retains its [upstream licensing terms](https://www.sqlite.org/copyright.html). The project authors the finite transaction mapping and independent test specification.
- KV classification-tree and Wp-method references include the public [AALpy KV](https://github.com/DES-Lab/AALpy/blob/master/aalpy/learning_algs/deterministic/KV.py) and [Wp](https://github.com/DES-Lab/AALpy/blob/master/aalpy/oracles/WpMethodEqOracle.py) documentation/implementation for behavioral comparison; no source is copied or executed as the learner.

Controlled session fixtures, generated-model seeds, the finite LRU reference specification, tests and examples were developed for this repository with AI assistance. Controlled defects are intentional examples and do not allege bugs in third-party software. No production user data is included in the public evidence.

Generated .mbti interfaces are unmodified MoonBit compiler output. Generated model corpora use the recorded seeds; checked-in reports come from the documented verification commands. The original overview SVG is repository-authored. The current hero-v2.png is AI-generated conceptual artwork made with the built-in image generation tool; its exact prompt and creation record are in docs/assets/hero-v2.prompt.md. It is not a product screenshot or measured model.

The root LICENSE applies to this repository's distributed material; dependencies retain their own notices. Third-party libraries and the separately installed SQLite CLI retain their upstream terms. CI references external GitHub Actions by revision; their source is not redistributed as project algorithms.

README navigation cards and utility buttons in `docs/assets/nav/` are repository-authored SVGs with original simple geometric icons. Regenerate them with `moon run tools/generate_readme_nav.mbtx`. Navigation is supplied by README anchor elements, with no remote badge generator, font, script or UI library dependency.

v0.3 model-derived suite workflows were informed by the public [AutomataLib overview](https://learnlib.de/pages/automatalib) and [ALEX learning/testing documentation](https://learnlib.de/alex/book/contents/user-manual/learning/). Finite monitor product search, suite certificates, native execution, reports and fixed mutation corpora are repository-authored implementations of established techniques, not copied source. The HTML viewer contains authored CSS/JavaScript/SVG and has no external frontend or CDN dependency. No claim is made to invent W/Wp, safety monitors, prefix tries or generic replay/reduction.
