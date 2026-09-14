# Runtime efficiency contract

The framework keeps native Codex goals, tasks, subagents, worktrees, caching, compaction, and automations authoritative. It adds only project-neutral execution invariants and evidence checks.

## Bounded execution epochs

An open-ended goal remains active, but each execution epoch owns one coherent batch and at most one implementation-to-delivery lifecycle. Before substantive work, record the batch members, dependencies, target environment, allowed mutations, definition of done, verification inputs, external blockers, and checkpoint condition. Finish or explicitly block that epoch before selecting unrelated work.

A user status request receives a compact readback from current evidence. It does not restart repository discovery, board enumeration, full verification, or provider queries whose inputs have not changed. After resolving an attachment or bootstrap objective, rename the native task to the real outcome.

## Dependency-aware batching

Batch only work that shares a contract or delivery boundary. A blocked independent item must not hold unrelated review-ready work in progress: preserve its exact blocker and evidence, move it to the project-defined blocked state when one exists, and continue with the largest coherent unblocked batch. Do not split genuinely atomic migrations, schemas, or releases merely for throughput.

## Waiting and monitoring

For an external operation, read status once and perform at most one bounded attached wait. If it remains active, either do independent in-scope work or, when continued monitoring was requested, use a native thread heartbeat that stays quiet until a meaningful change, completion, failure, or required user action. Otherwise yield a checkpoint. Shell sleep loops, repeated status reads without changed evidence, repository polling daemons, and retry hooks are prohibited. Automatic goal continuation does not change the observed external state or reset the attached-wait allowance. Follow native goal blocking/scheduling rules, do independent authorized work, and never manufacture a local pause/monitor engine. The framework cannot guarantee suspension of a native goal through prompt text; absent native support is a reported limitation.

## Verification ledger

A reusable check result is identified by the code SHA or source digest, exact command and configuration, target environment, relevant provider identity, and other inputs that can invalidate it. Run targeted checks during implementation, one full local gate for an unchanged identity, and one CI/deployment run for that identity. After a failure, diagnose with the narrowest authoritative check, change the input, and rerun the full gate once. Never represent an old result as current after an input changes.

For a shared mutable environment, serialize changes until its active acceptance cycle finishes or is explicitly superseded for a documented reason. Do not cancel an own acceptance run by merging unrelated work. Independent isolated preview targets may run in parallel.

## Execution lanes

The parent keeps the goal, contracts, decisions, dependency graph, integration, and final evidence. Use an explorer for independent read-heavy reconnaissance, a tester when long execution or log triage would pollute the parent context, and a worker only with bounded ownership and an isolated worktree when writing in parallel. Each subagent returns a concise evidence summary. Because subagents also consume tokens, do not delegate routine sequential work.

High-risk work receives one reviewer for one immutable diff and risk boundary. A contract-invalid or context-contaminated attempt makes independent review unavailable for that diff; it is not retried as `v2`, `clean`, or `fresh`. The parent may revise once and rerun affected checks, but a second reviewer requires explicit user authority or a materially different diff and risk boundary.

## Measures

Runtime diagnostics distinguish observable response, root-turn and thread usage; execution epochs and reviewer identities require actual evidence and are unknown when absent. They report cached and uncached input separately; context-window pressure; tool/output volume by type; repeated external-status reads; failed waits; full-gate repetitions; compactions; and reviewer identities. Raw rollout bytes are pressure evidence, not proof of retained model context or API cost.

A valid task may be large, but it may not busy-poll, repeat an unchanged full gate, run multiple reviewers for the same immutable diff, or hold unrelated work behind an external blocker. Diagnostic command-pattern matches are advisory when target, identity or changed state is unavailable. Do not infer these violations from aggregate command counts. Safety hooks do not enforce lifecycle efficiency by shell regex.

## Evidence levels

Lexical contract checks establish structure, not semantic compliance. The policy-classification suite measures decisions about hypothetical cases. Tool-enabled behavioral fixtures independently check actual actions and outputs. Only real project acceptance proves the user outcome; fixture success does not certify Property, production readiness or universal quality. See `project-understanding.md` for incremental discovery and knowledge updates.
