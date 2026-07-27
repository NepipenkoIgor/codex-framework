---
name: database-optimization
description: Diagnose and improve database query, index, statistics, connection, contention, and configuration performance using production evidence and reversible changes. Use when measured database behavior is the bottleneck; do not use for schema migration delivery, greenfield modeling, or generic application performance without database evidence.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "engine/version, workload/query fingerprint, latency/throughput target, production evidence, change authority"
---

# Database Optimization

Optimize `$ARGUMENTS` from captured workload evidence and the exact engine/version, not fixed thresholds, selectivity folklore, or a generic index checklist.

## Workflow

1. Inspect instructions, engine/version/extensions, schema/indexes/statistics, query fingerprints and bind values, plans, table/index sizes and bloat, locks/waits, I/O/cache/CPU, connection pools and transaction duration, replicas, configuration ownership, deployment/migration path, SLOs, and representative baseline telemetry.
2. Localize the bottleneck before proposing a change: planning/cardinality error, scan/join/sort, N+1 or round trips, lock/contention, transaction scope, connection exhaustion, I/O/cache, vacuum/maintenance, replica lag, or application demand. Separate symptoms from causes.
3. Capture plain plans safely first. `EXPLAIN ANALYZE` executes the statement; never run it on production writes or an unbounded expensive query without exact authority and a proven containment/rollback boundary. Deferred/external side effects can survive naïve transaction rollback.
4. Evaluate query rewrites and indexes against real predicates, joins, ordering, projections, data distribution, operator classes/collations, write amplification, storage, and maintenance. Equality-first or “most selective first” is not a universal multicolumn-index rule; planner behavior depends on the full access pattern and engine.
5. Create or change indexes through the migration workflow after checking installed online/concurrent capability, lock mode, invalid-index recovery, uniqueness timing, WAL/disk, replicas, and write impact. Do not remove an index from a short observation window; prove duplicate/unused status across workload cycles, constraints, failover/replica use, and rollback.
6. Tune statistics or configuration only when evidence identifies the parameter and owner. Do not issue `ALTER SYSTEM`, server restart/reload, or managed-provider setting changes without explicit external authority, change control, exact scope, rollback, and workload validation.
7. Size application and proxy pools from total database connection budget, instance count/autoscaling, transaction duration, workload mix, reserved operational capacity, and pooler semantics. More connections can worsen contention; no corpus-wide pool number or utilization threshold is safe.
8. Compare before/after on representative data and concurrency using latency distribution, throughput, rows and loops, buffers/I/O, locks, CPU, temp/WAL, error rate, pool wait, and replica lag. Check plan stability across important bind values and statistics states, then run repository or executable compatibility/regression tests for the affected query and application boundary.
9. Roll out one attributable reversible change at a time where possible, with canary/observation, regression and abort criteria. Verify caller-visible SLO plus production database evidence; a faster isolated plan is not enough.

## Required counterexamples

- Never run `EXPLAIN ANALYZE DELETE/UPDATE/INSERT` on production merely to inspect a plan.
- Never apply `ALTER SYSTEM` or global managed-database settings as a repository-only optimization.
- Do not set pool sizes, slow-query thresholds, cache ratios, or index selectivity cutoffs from remembered constants.
- Do not drop an index solely because a usage counter is zero or because another index shares a prefix.
- A sequential scan can be correct; an index scan can be slower. Judge measured end-to-end workload cost.

## Output

Report engine/workload and baseline evidence, localized cause, candidate and rejected hypotheses, exact query/index/statistics/pool/config changes, lock/migration/authority implications, before/after measurements, rollout/rollback, production verification, and residual plan/data-distribution risk.

## Provenance

- PostgreSQL `EXPLAIN ANALYZE` execution caveats: https://www.postgresql.org/docs/current/using-explain.html
- PostgreSQL index behavior: https://www.postgresql.org/docs/current/indexes-intro.html
- PostgreSQL cluster-wide configuration: https://www.postgresql.org/docs/current/sql-altersystem.html
