# Behavioral contract

- The target is a deterministic, resettable finite-state Mealy system with a finite alphabet and one observable output per action.
- Model tables are complete, with unique input symbols and valid state indices. Construction and accessors copy mutable arrays.
- State IDs and graph layout have no behavioral meaning. Only input/output traces define observable equivalence.
- Product BFS returns a shortest distinguishing word between two complete explicit models, or exact model equivalence. It enforces a visited-pair limit and compares symbols even when column order differs.
- A learner must only access the target through its reset/step adapter. Reference tables are available only to separate exact test oracles.
- A learning table stores suffix outputs after an access prefix, not the complete trace. It must be closed and consistent before constructing a hypothesis.
- Counterexamples refine the observation table. Longer experiments may separate histories that look identical under short observations.
- Query caches must preserve all observed prefix outputs and allow uncached consistency probes. Repeated observations are evidence of stability, not proof of determinism.
- Budget exhaustion is inconclusive. No random or depth-bounded black-box experiment establishes unconditional equivalence.
- W-method claims require a complete minimal reachable hypothesis, a valid implementation state upper bound, complete deterministic resettable target, matching alphabet, and an entirely executed test suite.
- Differences between inferred models require fresh replay against the actual targets before being reported as implementation differences.
- Target exceptions are propagated, cleanup is attempted, and incomplete queries must not become cached successful traces.
- Configurations are parsed into typed targets before target IO. Offline validation checks declared structure and operation semantics, not target availability or behavioral premises.
- Run/comparison/replay artifact settings are either honored or explicitly rejected. Comparison artifacts belong to their configured side; report files contain the common comparison result. Replay never pretends to learn a model.
- Artifact files use exclusive creation. A write failure is an execution failure, even when a valid model or confirmed difference was computed first. Multiple artifact writes are not an atomic filesystem transaction.
