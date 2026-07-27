---
name: data-pipeline-engineering
description: Design and implement batch or streaming pipelines with schema contracts, immutable identity, lineage, idempotent sinks, checkpoints, late data, privacy, replay, and backfill safety. Use when dataset movement/transformation is primary; do not use for request APIs or message transport alone.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.1
  argument-hint: "sources/sinks/owners, volume/latency, event time/lateness, schema/privacy/lineage, replay/backfill requirements"
---

# Data Pipeline Engineering

1. Inspect source/sink ownership and contracts, pinned engine/orchestrator, volume/velocity, event versus processing time, privacy/residency/retention, current jobs/checkpoints/lineage and downstream consumers.
2. Define immutable input/batch identity, schema versions and compatibility, delivery/ordering, allowed lateness/watermark, correction/retraction, quality/quarantine and consumer SLOs. Do not claim exactly once without end-to-end proof.
3. Implement idempotent or transactional sinks with checkpoint coupling appropriate to the engine. Handle crash before/after sink/checkpoint, partial sinks, duplicate/reordered inputs and checkpoint loss.
4. Capture field-level/source-to-sink lineage, code/config/schema version, run identity, counts and reconciliation without logging sensitive rows.
5. Treat backfill/replay as an authorized production mutation: exact source/time/tenant range, immutable snapshot, dry run, isolated capacity/output, idempotent merge, canary, rate/abort conditions, reconciliation, rollback/forward-fix and cleanup. Prevent live/backfill overwrite races.
6. Enforce PII minimization, access, encryption, retention/deletion/legal hold and propagation to quarantine, checkpoints, derived tables, analytics and backups.

Verify duplicates, late/out-of-order/corrupt/missing records, mixed schema versions, checkpoint loss, partial sink, retry/replay, backfill/live overlap, deletion propagation and row/count/value/control-total reconciliation.

Report contracts/owners, time/delivery/schema semantics, identity/checkpoint/sink design, quality/lineage/privacy, replay/backfill plan, performance envelope, checks/reconciliation and residual source/sink guarantees.
