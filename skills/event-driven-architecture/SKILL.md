---
name: event-driven-architecture
description: Design read-only domain-event, schema-evolution, publication, consumption, ordering, replay, privacy, and recovery contracts across bounded contexts. Use when event-driven architecture decisions are unresolved; do not use for straightforward queue or broker implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-09-14"
  version: 1.7
  argument-hint: "business invariants, producers/consumers, broker/store, ordering and delivery needs, schema/privacy/replay constraints"
---

# Event-Driven Architecture

Design `$ARGUMENTS` read-only. Do not assume event sourcing, CQRS, sagas, Kafka, or a queue is required.

## Start from contracts and failure

1. Identify bounded contexts, business invariants, transaction boundaries, producers/consumers/owners, consequences, volume, latency, retention, residency and audit/privacy requirements.
2. Distinguish domain facts, integration events, commands and notifications. Define stable event identity, aggregate/resource/tenant scope, causation/correlation, occurred versus recorded time, schema version, privacy classification and owner.
3. Select direct request, queue/work item, pub/sub event, log/stream, outbox/CDC, saga/process manager, CQRS or event sourcing only where the required coupling, fan-out, audit, replay and consistency justify it. Queue implementation is a separate delivery task.

## Publication and consumption

- Avoid dual writes: persist domain state and outbox intent atomically when they share a transactional store, or define the equivalent provider-specific atomic/CDC contract. Publication is normally at least once; consumers deduplicate by stable event/effect identity.
- State the delivery guarantee separately from business-effect uniqueness in every design or replay assessment. Reject an assumed end-to-end exactly-once guarantee; identify the at-least-once publication boundary and the durable idempotency/reconciliation contract that prevents duplicate effects. A broker guarantee alone does not establish that external effects happen once.
- A consumer must establish idempotency/claim before performing an irreversible effect, or reconcile an effect that can succeed before acknowledgement. Ack/checkpoint only after durable outcome and dedupe state; timeout does not imply failure.
- Define bounded retries, backoff, poison/quarantine/DLQ, redrive authorization, dedupe retention, dependency outage behavior, and observability. Redrive is a production mutation, not a harmless read.
- Define ordering only at the necessary partition/aggregate key. Cross-partition total order is not assumed; consumers handle duplicates, gaps, stale versions and concurrent events explicitly.

## Schema compatibility and replay

- Set producer/consumer compatibility rules and a registry/contract-test gate: additive fields, defaults, enum evolution, semantic changes, new event types, upcasters/adapters, deprecation and mixed-version rollout. Never rewrite immutable history casually.
- Treat replay/rebuild as a privileged side-effectful operation. Before redrive or rebuild, require an authorized exact stream/topic, tenant/resource scope and time/offset range. Separate pure projections from external effects; define observable stop conditions, replay mode/sinks, checkpoints, rate limits, dry-run/canary, reconciliation and rollback so emails, charges or webhooks are not repeated.
- Snapshots and projections are optimizations/read models only when the chosen architecture defines them; verify rebuild from historical fixtures and schema versions.

## Privacy and deletion

Minimize PII in immutable events; prefer stable subject references or encrypted/segmented payloads where justified. Define access, retention, legal hold, subject export/correction/deletion, key destruction or tombstone strategy, backups, derived projections/search/analytics and consumer propagation. "Events are immutable" does not cancel privacy obligations.

## Verification and output

Test transaction/outbox crash windows, duplicate/concurrent delivery, effect-before-ack and timeout-after-effect, consumer crash/restart, schema compatibility with historical fixtures, partition ordering/gaps, poison/redrive, full replay without duplicate external effects, tenant isolation, PII deletion propagation, and projection reconciliation.

Report event catalog/ownership, invariants and consistency boundaries, publication/delivery/idempotency/ack, ordering/partitioning, schema evolution, replay/rebuild, privacy/deletion, failure/observability, alternatives rejected, and residual risk. Explicitly record whether CQRS and event sourcing were selected or rejected and the task evidence for that decision; neither is a universal event-driven default.
