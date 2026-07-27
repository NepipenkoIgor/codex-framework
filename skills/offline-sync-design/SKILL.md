---
name: offline-sync-design
description: Design durable offline synchronization, including local transactions, outbox processing, versioned pull cursors, tombstones, conflicts, account isolation, and deletion. Use for an architecture decision; do not use for routine feature implementation or assume every product should be local-first.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "platform, data sensitivity, offline guarantees, ownership scope, conflict policy"
---

# Offline Sync Design

Design the smallest offline capability justified by the product. Offline read cache, queued commands, editable replicas, and collaborative local-first data have different consistency and privacy costs; do not silently promote one into another.

## Workflow

1. Read repository instructions, manifests, lockfiles, schemas, authorization boundaries, existing storage, API contracts, and tests. For an existing project run `scripts/framework-stack-context.py project <path>` before version-specific advice and check runtime engine constraints, peer dependencies, compiler/framework, local-store/transport adapters, test runner and deployment/background-execution support together. Preserve installed pins unless migration is requested. For greenfield work resolve relevant stable/LTS technologies with `scripts/framework-stack-context.py latest ...`, then let the generated manifest and lockfile become authority.
2. Define the offline contract per operation: unavailable, cached read, deferred command, editable replica, or collaborative merge. Record latency, durability, ordering, revocation, deletion, multi-account, and regulatory requirements.
3. Define server authority, entity ownership, tenant/account partition keys, immutable operation IDs, server versions, and authorization revalidation. Local data is never proof of current permission.
4. Design one local transaction that commits the user-visible mutation and its outbox operation together. Include encrypted-at-rest requirements and an account-scoped wipe plan where the platform supports them.
5. Design durable processing: atomically claim an eligible operation with a lease/fencing token; renew or expire the claim; retry only retryable failures with jitter; derive maximum attempts and total elapsed time from server/provider retry semantics, operation deadline, background-execution window, queue freshness and observed recovery evidence, or leave them unresolved rather than invent values; reconcile timeout-after-commit using the same idempotency key; persist terminal/manual-review state.
6. Design pull synchronization from an opaque server-issued cursor or snapshot/version boundary. Apply returned mutations, tombstones, and the next cursor atomically. Do not use a client wall-clock timestamp as the sole cursor.
7. Choose conflict behavior per invariant: reject and refresh, compare-and-swap, semantic merge, user resolution, or a proven CRDT. Last-write-wins is valid only when silent loss and clock/order semantics are explicitly acceptable.
8. Model logout, tenant/account switch, credential rotation, revoked access, process death, storage pressure, schema migration, server rollback, and privacy deletion before implementation.

## Required Invariants

- A local mutation cannot exist without its durable outbox intent, or vice versa.
- Concurrent workers cannot complete the same logical command twice; leases coordinate work, while server idempotency and reconciliation establish the outcome.
- Queue compaction preserves causal dependencies and delete semantics. Never reorder operations merely by create/update/delete type.
- Tombstones remain visible long enough for every supported replica or force a bounded full resync; resurrection is an explicit failure case.
- The cursor advances only with the corresponding local apply. Pagination belongs to one defined snapshot/version boundary.
- Every row, queue item, cursor, key, and cache is isolated by the current account/tenant and environment. An auth change pauses work until ownership is revalidated.
- Privacy deletion covers server data, local replicas, queued payloads, logs, backups, conflict copies, and derived caches according to the governing policy.

## Failure Scenarios

Walk through at least: crash between local edit and enqueue; two processors claiming one item; server commit followed by client timeout; process death during cursor apply; delete versus offline edit; stale replica after tombstone retention; permission revoked while queued; and account A data visible after switching to account B.

For each scenario state persisted state before/after, retry decision, server-visible effect, user-visible state, recovery path, and evidence that proves convergence or safe rejection.

## Verification and Deliverable

Use repository-authoritative unit, migration, integration, and process-restart tests. Add deterministic fault injection around transaction commit, claim/lease expiry, server timeout, pull-page apply, auth switch, and deletion. Test conflicts with multiple independent replicas and verify persisted/server outcomes, not only UI state.

Return: chosen offline level; authority and data-flow diagram; local/outbox/cursor/tombstone schema; idempotency and conflict contracts; account/privacy lifecycle; failure matrix; version/capability evidence; executed checks and residual risks.

Do not claim exactly-once delivery, universal local-first behavior, background execution guarantees, fixed retry schedules, or provider limits without repository and current official capability evidence.
