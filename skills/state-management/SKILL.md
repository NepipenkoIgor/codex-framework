---
name: state-management
description: Design frontend state ownership, server materialization, optimistic operations, local persistence, and bounded client recovery. Use for an unresolved application-state architecture decision; route durable multi-device offline replicas, outboxes, tombstones, and synchronization conflicts to offline-sync-design, and do not use for routine local component state implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "installed stack, state categories, SSR/offline needs, mutation/conflict authority"
---

# State Management

Produce a design from repository evidence; do not select a tool from a universal table.

1. Inventory URL/router, local UI, form/draft, server/cache, authenticated subject/tenant, durable client and cross-tab/device state. Name the authority and lifecycle for each value.
2. For SSR, create request-scoped state and serialize only authorized data. Hydration materialization must be offline-valid: distinguish server snapshot, stale cache, missing network and current authorization; never reuse one user's singleton store across requests.
3. Model each optimistic mutation as an operation with immutable ID, base/version, exact optimistic patch, inverse/reconciliation data and server idempotency. Reconcile timeout-after-commit, duplicate/reordered response, conflict, rejection, logout/tenant switch and process death. Do not blindly roll back over newer operations.
4. Offline writes require a durable atomic local mutation/outbox boundary, ownership isolation, tombstones/conflict policy and server authorization on reconnect. Derive retry attempts and total elapsed time from operation/server semantics, background window, queue freshness and observed recovery evidence; after exhaustion expose a durable unresolved state rather than inventing constants. If those guarantees are not justified, use cached reads or disable offline mutation.
5. Choose existing framework/store/cache primitives from installed capabilities, team conventions, bundle/runtime cost and testability. For explicitly authorized greenfield setup only, resolve stable/LTS components from official sources, verify cross-stack compatibility, generate manifest/lockfile and make them authority. Capacity, stale time, persistence size and normalization thresholds come from measured workload—not fixed constants.
6. Verify multiple concurrent operations, conflict, stale server snapshot, refresh/navigation, SSR cross-request isolation, offline/reconnect, account switch, storage corruption/quota and devtools/log redaction.

Return state map/authority, operation state machine, SSR/offline materialization, persistence/privacy, selected capability evidence, failure tests and residual consistency risk.
