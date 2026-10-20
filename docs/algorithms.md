# Algorithms and engineering invariants

MoonStateLens independently implements published active-learning ideas; it does
not invoke LearnLib or AALpy. Algorithms are not claimed to be globally novel.

## Suspended learning

LearningDriver stores a continuation for the current algorithm phase.
A Query event requests a word; submit validates its ID/length and resumes that
continuation with a copied trace. No restarting the learner to emulate async IO.
Hypothesis events expose only complete machines. Refinement validates the real
counterexample, trims at its first output mismatch and records its actual outputs.

QuerySession owns one outstanding physical query, a prefix observation trie,
attempted-call budgets and conflict poisoning. Both Experiment and AsyncExperiment
use this state. Only execution plus cleanup success can commit a trace.

## Mealy L*

learning_table.mbt keeps access prefixes, suffix experiments and rows of complete
suffix-output traces. It fills missing rows for S and S·alphabet, repairs closure
and consistency, constructs the complete hypothesis, then incorporates
counterexample prefixes. Direct query execution is outside the table.

## Mealy KV

learning_tree.mbt maintains a classification tree. Leaves carry access words;
internal nodes carry distinguishing suffixes and branches are keyed by the FULL
suffix-output trace. Sifting classifies successors and can introduce a new leaf.
The complete transition table is rebuilt after a distinguishing split.

For a counterexample trimmed to its first mismatch, let h_i be the hypothesis
state after its first i inputs. Consider the final output of executing
access(h_i) followed by the remaining counterexample suffix. At i=0 this is the
real counterexample output; at the last-input position it equals the recorded
hypothesis transition output. The endpoints differ, so an adjacent differing pair
exists. A linear scan finds one; the remaining nonempty suffix distinguishes
access(h_i) from access(h_(i-1)) followed by the preceding action. The code checks
both complete suffix traces before splitting that leaf.

This version uses linear counterexample analysis. It does not claim TTT or an
optimized logarithmic KV counterexample processor. Independent correctness tests
cover 200 generated targets and all 256 binary two-state transition/output tables.

## Wp and W

verification_words.mbt lazily enumerates middle words up to the declared extra
state allowance. W uses transition coverage with a global characterization set.
Wp uses state coverage with global suffixes and the remaining transition coverage
with identifiers for the reached state. Local identifiers are selected from the
global set and checked to separate every competing state. Epsilon is included to
test outputs of single-state models and transitions.

Both operate on a reachable minimal model view; the learner keeps its own tree
or table state. Global characterization and local identifier selection have
separately enforced preparation work limits. Tests/words are generated lazily.
The correct state bound, totality, deterministic outputs and reliable reset are
premises. Complete generation without executing every required test is not proof.

Wp is checked against independent exact product comparison for all 65,536 ordered
pairs of binary two-state machines. This finite corpus is strong regression
evidence, not a formal proof for all finite machines.

## Verification chain

Replay -> random -> Wp/W is a configurable sequence, not a new learning algorithm.
Each hypothesis gets a fresh cursor. Stage logs record completed test counts and
results; counterexamples return immediately to learning. Incomplete stages stop
the chain. The final completed stage supplies the final evidence.
Nested caller-owned arrays are snapshotted before suspension.

## Comparing real components

The model product search proposes a word. Both targets then execute it from fresh
resets with cache bypass. Different actual outputs confirm a difference. Equal
outputs add a regression word to both relearners. Conflicts, resource limits and
refinement exhaustion produce explicit incomplete/unstable results.

A shortest word between two complete models need not be a globally shortest real
program defect unless their correspondence with the programs is established.

## Costs

`benchmark-algorithms` compares L* and KV using the same targets, Wp parameters,
budgets and cache policy. It reports total and verifier query/step counts.
Results may favor either algorithm; no universal reduction or speedup is claimed.

