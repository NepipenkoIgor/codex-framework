---
name: backend-review
description: Review backend diffs read-only for concrete correctness, security, performance, reliability, data-integrity, migration, and contract regressions. Use when findings and risk assessment are requested; do not implement fixes.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.1
  argument-hint: "PR/diff/module, stack, expected behavior and verification scope"
---

# Backend Review

1. Read instructions, actual diff and callers, manifests/lockfiles/runtime, API/event schemas, migrations, auth/tenant model, jobs/providers, tests and deployment context.
2. Reconstruct changed execution paths and invariants: validation, resource authorization, transactions/concurrency, idempotency/retry/timeout, queries/indexes, queues, error compatibility and telemetry/privacy. For retry or wait changes, verify that total attempts or elapsed time are bounded by operation deadlines, provider semantics, idempotency/reconciliation and observed recovery evidence; flag unbounded or generic copied values rather than inventing a replacement number.
3. Verify version-sensitive claims against installed artifacts and documentation matched to the pinned installed version; neither current docs alone nor manifest pins alone prove capability. Run or identify focused checks when safe; label code-only hypotheses and unavailable DB/provider/production paths.
4. Report only actionable behavior or material maintainability risks, not style preferences or speculative rewrites.

Findings first, ordered by impact and likelihood. Each needs severity, exact file/line, affected path, expected versus observed behavior, concrete counterexample/reproduction and bounded fix direction. Distinguish confirmed defect from hypothesis. Then list checks/evidence, blockers and residual risk. If no finding is supported, say so.
