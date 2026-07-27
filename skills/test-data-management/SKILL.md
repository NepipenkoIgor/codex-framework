---
name: test-data-management
description: Implement isolated test factories, fixtures, seeds, anonymized datasets, and bounded cleanup with privacy and relational integrity. Use when test-data infrastructure is the requested deliverable; not for feature implementation or E2E coverage itself.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "exact environment/database, schemas and relationships, worker isolation, volume, privacy and retention policy"
---

Implement test data management for $ARGUMENTS.

## Resolve the target before writing

Read repository instructions, manifests/lockfiles, database configuration, migrations/schema, test runner and workers, existing factories/seeds, environment guards, CI topology, privacy policy, and cleanup conventions. Resolve the exact database/project/account, environment, schema/namespace and credentials from trusted configuration. Prove it is an approved non-production target before any mutation; ambiguous ownership or production reachability is a stop condition.

Preserve installed libraries and repository patterns. Verify APIs from installed types/CLI/schema or matching official docs. For greenfield tool selection, use `scripts/framework-stack-context.py`; never upgrade a test stack incidentally.

## Data design

- Derive factories from the authoritative schema and business invariants. Build parent records before dependents and preserve foreign keys, tenant ownership, uniqueness, checks, enum/domain constraints, temporal rules, and application-visible defaults.
- Make deterministic reproduction possible by recording seed, scenario, worker/run identifier and relevant schema version. Randomness must not hide the failing values.
- Allocate an isolated transaction, schema/database, tenant, account, or namespaced identifier range per test/worker according to repository capabilities. UUIDs alone do not prove isolation where shared global constraints or queries exist.
- Bound requested volume, concurrency, batch size, runtime and cost. Avoid unbounded `Promise.all`, full-table copies and uncontrolled fan-out.
- Synthetic data is preferred. Production-derived data requires explicit authority, data minimization, irreversible or risk-assessed transformation, restricted transfer/storage, retention and deletion. Replacing obvious names does not prove anonymity.

## Mutation and cleanup

Never run shared `TRUNCATE ... CASCADE`, drop shared schemas, or delete by broad/unresolved predicates. Use exact run-owned identifiers and database-supported transactions/savepoints where possible. Cleanup must be idempotent, ordered by relationships or cascades that were explicitly reviewed, and scoped to data created by this run.

For committed setup, register ownership before or atomically with writes so a crash can be recovered. On partial failure, roll back the transaction or clean only recorded run-owned rows; preserve evidence if cleanup fails. Development seed replacement is a separately authorized operation with preview, target guard, backup/rollback where material, and explicit confirmation.

## Verification and output

Test parallel workers, retries, partial setup, partial cleanup, tenant boundaries, referential integrity, uniqueness, deterministic reproduction, privacy transformation, retention and zero accidental modification of pre-existing rows. Compare pre/post counts or ownership queries for the exact namespace and run focused plus affected repository checks.

Report resolved target and proof it is non-production, ownership/isolation scheme, schemas and invariants, volume bounds, privacy provenance, setup/cleanup transaction behavior, actual checks, remaining data left by the run, and recovery instructions. A successful seed command is not proof of privacy, isolation or cleanup.
