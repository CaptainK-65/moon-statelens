# Security and operating assumptions

Version 0.2 supports synchronous callbacks and native asynchronous IO to controlled HTTP/process targets. It is not a sandbox for hostile target code. Operation budgets cannot preempt arbitrary synchronous computation. Async IO waits have deadlines and protected cleanup; the supervisor reaps its direct child but does not claim arbitrary descendant-tree isolation. See docs/native.md for the actual contract.

Do not probe targets without authorization. Reset and step can change real state. Use disposable or explicitly controlled target instances. Avoid recording secrets as output symbols; define a stable abstraction that preserves the behavior being investigated.

Input/output files, cached traces and exported models should not contain credentials or private sessions. CLI export refuses overwrites, model files are bounded and validated, and observed output conflicts invalidate the experiment. These measures do not establish determinism or correctness of an arbitrary target.

For a sensitive report, use GitHub's private vulnerability reporting feature if available or an established private channel with the maintainer. Do not place secrets in a public issue.
