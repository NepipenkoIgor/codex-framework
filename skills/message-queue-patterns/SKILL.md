---
name: message-queue-patterns
description: Implement broker-backed producers and consumers with durable publish, acknowledgements, redelivery-safe effects, schema evolution, ordering, poison handling, and recovery. Use when an external message broker carries application work or events; do not use for in-process background jobs, event-driven architecture design, or HTTP webhooks.
metadata:
  owner: codex-framework
  reviewed: "2026-09-09"
  version: 2.1
  argument-hint: "broker, topic/queue, producer transaction, message contract, consumer effect, ordering, replay"
---

# Message Queue Patterns

Implement `$ARGUMENTS` against the configured broker and client capabilities.

Treat producer durability and consumer correctness as one end-to-end contract even when the reported incident is consumer-side. Do not omit the producer transaction/outbox boundary, broker acknowledgement/confirm responsibility, schema-registry capability or ambiguous-publish recovery from discovery, design, fault tests or the final report.

This skill owns transport, delivery and replay mechanics. Preserve payment or other domain policy with its domain owner and preserve higher-level event boundaries, event meaning and service topology with the event-architecture owner; broker implementation must not silently redefine either.

## Workflow

1. Inspect manifests/lockfiles, broker/client configuration, topic/queue declarations, producer transaction, message schemas and registry, consumer groups, offset/ack mode, retry/dead-letter topology, retention, deployment lifecycle, existing telemetry, recent failure/redelivery evidence, and tests. Preserve pins and verify unfamiliar APIs against installed types/config and matching official docs.
2. Define message purpose, owner, key, immutable event/command ID, schema identifier/version, partition/ordering key, producer transaction boundary, consumer business operation, retention/privacy, and compatibility rules.
3. Publish durably: atomically persist domain change plus outbox when direct broker publish cannot share the transaction. Mark outbox dispatch complete only after the configured broker acknowledgement/confirm proves broker responsibility; ambiguous publish is retried with the same message identity.
4. Assume redelivery. The consumer establishes a durable inbox/business-operation identity, applies the side effect and completion atomically when possible, and acknowledges/commits only after the durable outcome. If the side effect is external, use provider idempotency plus reconciliation for crash-between-effect-and-ack.
5. Ordering is scoped to the broker's proven unit (for example a partition or single active consumer), not a global promise. Key related mutations consistently and make handlers robust to duplicates, gaps, late messages, and rebalances. Commit only work whose ownership and effects are complete.
6. Evolve schemas by explicit compatibility policy. Consumers tolerate unknown fields where the format allows, reject or quarantine unknown enum variants safely, and never reinterpret an old field silently. Roll out producer/consumer changes in an order supported by compatibility tests.
7. Poison messages are classified and quarantined with the lossless original payload (encrypted and access-controlled according to data policy), schema/version, attempts, error, side-effect evidence, and trace context. User-facing reports redact payload secrets, but the protected quarantine record must retain enough exact payload evidence for schema-aware diagnosis and authorized replay. Prevent hot requeue loops. Replay is authorized, schema-aware, auditable, idempotent, and does not discard the original failure.
8. Bound prefetch/poll batch, concurrency, processing deadline, retry delay, retention, and DLQ policy from measured workload, broker limits, downstream capacity, and recovery objectives—not universal values.
9. Verify broker outage and ambiguous confirm; crash before the external/provider effect, after provider success but before durable local completion/ack, and after acknowledgement/commit; duplicate and out-of-order delivery; poison payload; rebalance during work; redelivery after ownership loss; an old consumer receiving a new enum without falling into a destructive default; schema rollback; DLQ evidence and replay; shutdown; backlog recovery; and provider reconciliation. For every listed fault, give executable fixture inputs, delivery/failure actions and observable broker, store, provider and caller-visible assertions; marking results pending or listing desired properties is not a test plan. For poison/new-enum/replay, also replay or redeliver the same replayed identity a second time and assert no duplicate prior effect, alongside healthy-message progress, bounded attempts, quarantine evidence, schema upgrade/rollback and reconciliation.

## Required counterexamples

- A consumer crashing after a provider side effect but before ack must not repeat the side effect without idempotency/reconciliation.
- A rebalance or channel loss invalidates ownership; work completed afterward cannot blindly commit another consumer's offset/tag.
- An unknown enum value must not fall through to a privileged or destructive default branch.
- Publisher send success without a broker confirm is not durable-publish proof.
- A poison message must not loop forever and starve healthy traffic.

## Output

Report broker/client and topology evidence, inspected deployment lifecycle/shutdown ownership, message/schema contract, publish transaction and confirm semantics, consumer inbox/effect/ack ordering, ordering and rebalance behavior, retry/DLQ/replay policy, capacity assumptions, observability, and any unverified broker or provider boundary. Enumerate fault-test results separately for the three crash boundaries (before effect, after effect before completion/ack, and after ack/commit), duplicate delivery, out-of-order delivery, rebalance/ownership loss, broker outage/ambiguous confirm, poison/schema replay, shutdown, and backlog recovery. Include a recovery inventory of quarantined and replayed identities, schema versions, known prior effects, and unresolved messages without leaking payload secrets.

## Provenance

- RabbitMQ acknowledgements and publisher confirms: https://www.rabbitmq.com/docs/confirms
- RabbitMQ reliability and redelivery: https://www.rabbitmq.com/docs/reliability
- Apache Kafka consumer rebalance API: https://kafka.apache.org/43/javadoc/org/apache/kafka/clients/consumer/ConsumerRebalanceListener.html
