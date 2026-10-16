# Security and operating assumptions

Version 0.1 executes trusted synchronous in-process callbacks. It is not a sandbox for hostile target code. Callback execution is not preempted by the experiment's operation budgets; the host must provide isolation/timeouts when needed.

Do not probe targets without authorization. Reset and step can change real state. Use disposable or explicitly controlled target instances. Avoid recording secrets as output symbols; define a stable abstraction that preserves the behavior being investigated.

Input/output files, cached traces and exported models should not contain credentials or private sessions. CLI export refuses overwrites, model files are bounded and validated, and observed output conflicts invalidate the experiment. These measures do not establish determinism or correctness of an arbitrary target.

For a sensitive report, use GitHub's private vulnerability reporting feature if available or an established private channel with the maintainer. Do not place secrets in a public issue.
