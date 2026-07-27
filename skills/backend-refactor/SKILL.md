---
name: backend-refactor
description: Refactor existing backend code while preserving characterized API, persistence, authorization, job, provider, error, and observability behavior. Use when structural repository changes are explicitly requested; do not use for features, diagnosis-only, review-only, or an incidental stack migration.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.1
  argument-hint: "module and maintenance defect, behavior to preserve, compatibility and verification scope"
---

# Backend Refactor

1. Read instructions, manifests/lockfiles/runtime pins, target and callers, API/event schemas, persistence/migrations, auth, jobs, integrations, telemetry and nearby tests.
2. Characterize current behavior before editing: inputs/outputs/errors, actor/tenant/resource authorization, transactions/concurrency/idempotency, ordering/retries/timeouts, provider effects, jobs, cancellation, logs/metrics and performance where relevant.
3. Establish an executable regression or explicit baseline, identify the concrete maintenance defect, and choose the smallest structural boundary that removes it.
4. Preserve public contracts and persisted/effect behavior unless explicitly changed. Inspect the diff for accidental schema, migration, authorization, retry, logging or dependency changes.

## Constraints

- Preserve repository language, runtime/framework/ORM, package manager, validation, test harness and deployment pins. Do not add TypeScript, Zod, Pydantic, a repository layer, event bus, framework upgrade, async conversion, ORM or test migration as cleanup.
- Extract boundaries when cohesion, ownership, testability or measured performance improves; no fixed file-size, method-count, duplication or abstraction thresholds.
- Do not parallelize I/O until transaction, ordering, rate, connection and failure semantics prove independence.
- Client or transport validation does not replace domain/database constraints, server authorization, concurrency or idempotency.
- Performance refactors require measured evidence at the affected boundary; preserve cancellation, retry and observability semantics.

Generate stack context before version-sensitive recipes and apply only installed capability. A stack upgrade is a separate migration with compatibility, rollout and rollback.

Run focused characterization/regression then affected type/lint/build/unit/integration/migration-contract checks. Verify invalid/auth/tenant, concurrent duplicate, conflict, timeout-after-effect and rollback paths relevant to the refactor. Report baseline, structural change, checks/results and unverified provider/deployment risk.
