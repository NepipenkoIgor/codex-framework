---
name: data-modeling
description: Design read-only persistent data models, relationships, constraints, lifecycle, temporal behavior, privacy, and indexes from business invariants and representative queries. Use when schema shape is unresolved; route an approved migration to database-migration.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.4
  argument-hint: "engine/version, entities/invariants, ownership/relationships, queries/cardinality, lifecycle/privacy/temporal policy"
---

# Data Modeling

1. Inspect existing schema/migrations, exact engine/version, ORM mappings, identifiers, tenancy, data volume/cardinality, representative read/write queries, retention/privacy register and consumers. Keep an engine upgrade decision separate from a compatible schema migration and from version-specific online-DDL mechanics.
2. Extract entities, ownership/cardinality, uniqueness, state transitions, transaction/concurrency invariants, temporal meaning, deletion/restore/legal-hold and PII classification/access/audit requirements.
3. Produce conceptual and logical models before engine-specific physical choices. Stay read-only; executable migration/backfill is owned by `database-migration`.

## Model contract

- Define primary/natural/public identifiers from merge, enumeration, distribution and compatibility needs; no identifier strategy is universal or an authorization boundary.
- Model one-to-many, many-to-many, optional and self-referential relationships with explicit ownership, nullability, referential action and lifecycle. Database constraints enforce invariants where supported; ORM validation is not a substitute.
- Define uniqueness/check/exclusion/version constraints and transaction boundaries, including concurrent writer behavior.
- Derive indexes from real equality/range/join/order/group access paths and realistic cardinality/plans. Foreign keys, every filtered column, selectivity order, index types and live-build syntax are engine/workload decisions, not blanket rules.
- Normalize or denormalize from update anomalies, read cost, ownership and reconciliation. JSON/document embedding requires bounded growth and validation; avoid arbitrary 3NF/EAV rules.
- Define temporal event/effective/recorded time, overlap policy, timezone and correction/history semantics explicitly.
- Soft deletion requires approved purpose, visibility, uniqueness, cascade, restore collision, retention/erasure/legal hold, analytics/search/cache propagation and hard-delete process. It is not a universal default.
- Minimize and protect PII: purpose, access, encryption/tokenization where justified, audit, residency, retention, subject export/correction/deletion and backups/derived stores.

## Verification and output

Test required/unique/FK/check/temporal constraints with concurrent writers, including allowed and rejected temporal-overlap boundaries, delete/restore/cascade, tenant isolation, PII lifecycle, ORM-generated SQL and representative query plans on the selected engine/version. Design migration, backfill, reconciliation and rollback/forward-fix evidence without executing unless authorized.

Report ER/logical model, identifiers/relationships, constraints/transactions, query-index evidence, temporal/delete/privacy policies, migration considerations, alternatives and residual assumptions.
