# Architecture and invariants

## Packages

The root package owns Machine, System, Experiment, Oracle, LearningResult and CompatibilityResult. Consumers never need an internal package to construct or inspect public values. The root package imports only core/json and core/debug. Module dependencies support the native CLI and real cache adapter; no external model-learning engine executes the algorithms.

| Files | Responsibility |
| --- | --- |
| machine / comparison / minimization | Validated complete models, reachable product BFS, partition refinement, reverse pair characterization |
| system / experiment | Synchronous target contract, cleanup, trace trie, stable-observation checks and budgets |
| learning_driver / learning_table / learning_tree | Suspended L* and independent KV, complete hypotheses and counterexample refinement |
| query_session / experiment | Shared IO-independent lifecycle, cache and budgets; synchronous compatibility facade |
| verification / verification_words | Lazy W/Wp and composable verification cursors with stage logs |
| runner / adapters/native / integration | Async execution, scoped real targets, configuration and replay-confirmed comparison |
| oracle_* / word_cursor | Exact reference, finite experiments, lazy W-method word enumeration and oracle evaluation |
| compatibility | Two-target inference, fresh replay and spurious-disagreement refinement |
| serialization / status_json | Validated versioned interchange and readable evidence scopes |
| adapters/moonlarder | Real third-party cache target; never an inference dependency of the root package |
| examples / benchmarks / cmd | Consumers of the public API |

## Observation table

The current suspended table is learning_table.mbt. [Algorithm invariants](algorithms.md) also document KV, the continuation protocol and Wp. [Native integration](native.md) covers IO ownership and failure semantics. The root never imports the native layer.

S is a prefix-closed set of access words; E is a suffix-closed set of distinguishing experiments, initially every one-letter input. T(s,e) stores only the output suffix after executing s. The preceding output history is not part of state identity.

Closure requires every row of S·alphabet to equal a row represented by S. Consistency requires equal S rows to have equal successor rows for every action. Immediate Mealy outputs are represented because E includes one-letter experiments. A consistency violation prepends the offending action to an existing distinguishing suffix. A counterexample adds its prefixes. Rows are invalidated when E changes; table cell and output-symbol budgets are rebuilt for the current table.

A stable table produces one state per distinct S row. Prefix closure makes the states reachable. Suffix closure and transition consistency make distinct rows behaviorally distinguishable in the hypothesis. These are implementation invariants validated by tests, not a machine-checked proof of the entire library.

The learner never reads a reference model. Exact test oracles separately compare the hypothesis with a known complete target and return only a distinguishing word. Returned words are freshly checked against the real adapter; a lying oracle is rejected.

## Model algorithms

Product BFS records parent pointers, not a copy of the entire path per visited pair. It compares input symbols even when model column order differs. A reachable output mismatch reconstructs a shortest word; exhausting the complete reachable product establishes explicit-model equivalence. Pair limits raise a resource error.

Minimization refines partitions by the vector of outputs and successor classes, then removes unreachable classes and numbers them by reachable order. Transition checks have a separate work budget.

Characterization builds a reverse graph of unordered state pairs once. Immediate output mismatches seed a multi-source BFS. A predecessor is distinguishable by its action followed by its successor's witness. The resulting shortest suffixes are cross-checked against the independent product BFS on generated targets. A shared work bound includes pair transitions and witness reconstruction; partial sets are never returned as complete.

## Conformance

W-method operates on a minimized reachable hypothesis H with n states and declared implementation bound m. It constructs transition cover P, characterizing suffixes W (including epsilon), and executes P·alphabet^(0..m-n)·W. Intermediate words are enumerated with an odometer cursor, so exponential layers are not materialized. A test-count or preparation limit is inconclusive.

The bound and reset/determinism/totality assumptions are caller responsibilities. Ordinary random and depth-bounded oracles report only budgeted evidence. No branch upgrades a missing counterexample to an unconditional implementation theorem.

## Ownership and failures

Models copy mutable arrays on entry and exit. Experiments copy words before invoking user callbacks, disallow reentry, preflight query/step/cache limits and retain no successful cache entry for an incomplete query. Cleanup is attempted after reset/step exceptions without replacing the original failure. Conflicting observations poison the session and are copied when reported.

Compatibility learns both sides, checks their complete hypotheses and freshly executes candidate words on both adapters. Real differences are retained; spurious model differences enter regression experiments. Final counters include confirmation calls. A changed target or exhausted budget during confirmation has an explicit result.
