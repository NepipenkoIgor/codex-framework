---
name: multi-tenancy-design
description: Design tenant isolation across trusted identity, database, cache, jobs, queues, storage, analytics, migration, backup, and privileged operations. Use when one product serves multiple security tenants and the isolation boundary must be selected or changed; do not use for ordinary organization membership.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.4
  argument-hint: "tenant threat model, identity source, data planes, residency/restore/noisy-neighbor requirements, migration scope"
---

# Multi-Tenancy Design

Design `$ARGUMENTS` read-only. Implementation, schema mutation, migration, project creation or backfill requires separate explicit authorization for the exact target and is a hard gate, even when the design includes a safe plan. Give version-independent design guidance and hand version selection to authorized project setup; only that execution resolves stable/LTS releases from official sources, checks cross-stack compatibility, and makes generated manifest/lockfile authoritative. State this gate in the delivered design rather than relying on read-only mode to imply it.

## Threat model and trusted context

1. Define the protected tenant/security boundary, actors and adversaries, support/control-plane privileges, residency, restore granularity, noisy-neighbor tolerance, and incident blast radius.
2. Inventory every data path: identity/session, API, database/ORM/search, cache, queue/job/retry/DLQ, object keys/presigned URLs, realtime rooms, analytics/export, logs/traces, backups/restores, provisioning/deletion, and migrations.
3. Resolve tenant context from a server-validated identity and authorized membership/resource relationship. A client header, subdomain, route/body field, JWT claim without current authorization, or ambient global is not sufficient authority. Refer to any caller-supplied tenant field generically until the inspected repository contract supplies its exact identifier; never invent a conventional header, claim, route, or column name.
4. Propagate immutable context explicitly across request, transaction, job, and event envelopes; reject missing, conflicting, stale, or unauthorized context.

## Isolation contract

- Choose shared rows with database policy, schema, database, account/project, or hybrid topology from the threat model and operations evidence. Compliance labels do not dictate a topology.
- Application query filters are ergonomics/defense in depth, not the sole isolation boundary. For RLS, verify runtime role ownership/BYPASS behavior, policy `USING` and `WITH CHECK`, pooled-connection transaction scoping, and privileged-role separation.
- Scope composite keys, uniqueness constraints, joins, cache keys/tags, search indexes, rate-limit keys, room/channel names, storage paths/policies, job identities, dedupe/idempotency keys, metrics, and exports by tenant where their semantics require it.
- Background and scheduled work must carry a trusted tenant plus actor/system purpose and reauthorize the target; never infer tenant from the first payload record or a reused worker context.
- Cross-tenant support/admin work uses separate least-privileged paths, explicit actor/purpose/target authorization, short-lived elevation, and immutable audit evidence.

## Lifecycle and migration

Design idempotent provisioning, suspension, deletion/privacy erasure, legal hold, export, per-tenant restore, key rotation, schema/data migration, partial failure and reconciliation. For an existing system, inventory and backfill tenant ownership, quarantine ambiguous/orphan rows, dual-enforce/read where needed, canary tenants, verify isolation continuously, and define rollback without reopening cross-tenant access.

## Verification and output

Test cross-tenant read/write/delete/insert, guessed identifiers, joins and uniqueness, cache poisoning, pooled connection reuse after error, jobs/retries/DLQ, storage and presigned URLs, rooms, exports, analytics/logging, backup/restore, migration partial failure, and privileged paths using production-equivalent non-owner credentials. Include a harness-control test that would fail if isolation were bypassed.

Report threat model, trusted context chain, selected topology and rejected alternatives, isolation per data plane, privileged access, lifecycle/migration/rollback, executable counterexamples, and residual shared-control-plane risk.
