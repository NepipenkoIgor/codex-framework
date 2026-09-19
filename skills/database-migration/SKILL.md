---
name: database-migration
description: Design and implement schema and data migrations with expand-contract compatibility, online-DDL capability checks, bounded backfills, lock analysis, rollout gates, and recovery. Use when persisted structure or data representation changes; do not use for query tuning alone or greenfield data modeling without a migration.
metadata:
  owner: codex-framework
  reviewed: "2026-09-19"
  version: 2.1
  argument-hint: "engine/version, schema/data change, writers/readers, table size/traffic, deployment sequence, recovery objective"
---

# Database Migration

Implement `$ARGUMENTS` against the exact database engine/version, migration runner, production topology, and application compatibility window.

## Workflow

1. Inspect instructions, manifests/lockfiles, migration history/runner, schema and ORM mappings, every reader/writer/job/export, exact production database configuration plus engine/version/extensions, replicas/CDC, table/index sizes, traffic and long transactions, deployment process, backup/restore evidence, and nearby tests. Treat deployed configuration and pins as capability authority unless engine or framework migration is explicit.
2. Define current and target invariants, compatibility matrix, authoritative data, transformation, validation, rollout/rollback or forward-fix strategy, and concrete stop/abort thresholds. Derive the thresholds from measured workload and recovery evidence, obtain the required operational approval, and record them before rollout. Determine whether old and new application versions can overlap.
3. Prefer expand → migrate/backfill → switch reads/writes → verify → contract when a one-step change would break overlapping binaries or hold unacceptable locks. Dual writes require one authoritative path, idempotency, reconciliation, and a bounded retirement plan.
4. Verify each DDL operation against the installed engine/version and the applicable table, partition and index form. “Online”, “concurrent”, “instant”, and lock-free are capability- and operation-specific; inspect lock modes, table rewrite, validation scans, transaction restrictions, replica/CDC effects, temporary disk/WAL, and failure artifacts. Record the exact capability, engine/version and matching source beside the migration decision rather than relying on a remembered current-release claim.
5. Backfill in resumable, idempotent, bounded batches with a stable key/range and checkpoint. Control concurrency from measured database headroom and replica lag. Handle rows created or changed during the backfill through dual-write, watermark/change capture, or a final reconciliation pass.
6. Add constraints and indexes in a sequence the engine can validate safely. Prove uniqueness/nullability/reference invariants from real data before enforcement; handle invalid concurrent index artifacts and partial failures explicitly.
7. Treat destructive contraction as a separate release after telemetry proves old readers/writers are gone and rollback/restore boundaries are acceptable. Assign an accountable owner and tracked retirement gate for every deprecated field/path; do not let dual-write or compatibility code become ownerless. A down migration is not automatically safe: data loss or incompatible new writes often require a forward fix, feature disable, or point-in-time restore instead.
8. Rehearse with production-shaped volume and concurrency. Deliberately attempt lock acquisition behind long transactions while concurrent writes continue, and inject uniqueness violations where the migration can encounter them. Measure lock acquisition/wait, statement duration, WAL/log growth, CPU/I/O, replica lag, application errors, and backfill rate; record abort, cleanup and resume behavior for every injected failure.
9. Deploy through explicit gates and verify schema, data counts/checksums/invariants, old/new application compatibility, query plans, replication/CDC, and caller-visible behavior. Record every irreversible step and evidence.

## Required counterexamples

- Adding a non-null column with backfill in one statement is not universally online or safe.
- `CREATE INDEX CONCURRENTLY` and equivalents have version, transaction, failure-artifact, and uniqueness caveats; the name is not proof of zero impact.
- Rolling back code after new-format writes may be unsafe even if a down script exists.
- A backfill without reconciliation can miss concurrent inserts/updates.
- A successful migration command does not prove replicas, old binaries, or caller-visible behavior remain correct.

## Output

Report engine/version and topology evidence, current/target invariants, compatibility and expand-contract phases, exact DDL capability/lock analysis, backfill/reconciliation design, rollout/abort/recovery gates, production-shaped measurements, validation results, irreversible steps, and residual restore/replication risk.

## Provenance

- PostgreSQL explicit lock modes: https://www.postgresql.org/docs/current/explicit-locking.html
- PostgreSQL concurrent index behavior and caveats: https://www.postgresql.org/docs/current/sql-createindex.html
