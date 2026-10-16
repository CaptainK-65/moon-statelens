# MoonStateLens

Pure MoonBit active learning of black-box Mealy behavior, with replay-confirmed compatibility witnesses.

**Development status:** the validated model and shortest distinguishing-word kernel are implemented. The active learner, conformance oracles, real-library adapter and release evidence are being built. No release or general black-box equivalence claim is made yet.

## Build

Tested toolchain: MoonBit 0.10.14 / moon 0.1.20260920.

```sh
moon update
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run cmd/statelens
```

## Scope

Finite alphabets, deterministic resettable systems, one output per input. The learning core will infer hidden observable states through reset/step interactions. Explicit model comparison is exact; finite experiments against real programs only support their stated assumptions and budget.

## Independent contribution

Existing MoonBit state-machine testing libraries accept a reference model. MoonStateLens is implementing the missing model-inference step: observation-table closure/consistency, distinguishing suffixes, counterexample refinement and conformance experiments. JSON, CLI and graph rendering are consumers of that core.

Algorithms are based on published automata-learning research, including [Angluin's work](https://www.sciencedirect.com/science/article/pii/0890540187900526). [LearnLib](https://learnlib.de/) and [AALpy](https://github.com/DES-Lab/AALpy) are related implementations in other languages, not runtime dependencies. No code has been copied from them.

Apache-2.0. See [LICENSE](LICENSE).
