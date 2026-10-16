# Sources and dependencies

MoonStateLens is an independent MoonBit implementation of published ideas in active automata learning. It does not embed or invoke LearnLib or AALpy, and no source files were copied from them.

- Dana Angluin, *Learning regular sets from queries and counterexamples*, Information and Computation 75(2), 1987. DOI: https://doi.org/10.1016/0890-5401(87)90052-6. The original formalism is DFA; this project implements an output-suffix Mealy variant.
- [LearnLib](https://learnlib.de/) and [AALpy](https://github.com/DES-Lab/AALpy) were consulted for the established problem, reset/step adapter pattern and scope of equivalence oracles. They remain external references, not included source or runtime computation backends.
- [MoonLarder](https://github.com/jhshuai/moonlarder), package `jhshuai/moonlarder@0.15.0`, Apache-2.0, is a real system under learning in `adapters/moonlarder`. This cache is not the model-learning implementation. The adapter only calls its public API.
- `moonbitlang/quickcheck@0.15.0`, Apache-2.0, is a direct version override of MoonLarder's legacy 0.14.0 dependency so that the entire module graph uses metadata recognized by the October toolchain. The learner does not import QuickCheck.
- MoonBit core supplies standard collections, JSON and runtime facilities. They are not counted as new project algorithms.

All controlled session fixtures, generated-model seeds, finite LRU reference specification, tests, diagrams and examples were authored for this repository. Controlled defects are intentional examples and do not allege bugs in third-party software. The root LICENSE covers this repository's original material; dependencies retain their own notices.
