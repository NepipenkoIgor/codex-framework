---
name: message-queue-patterns
description: Implement message queue systems for producer/consumer patterns, schema registry, message ordering, and idempotent consumers
metadata:
  version: 1.3
  argument-hint: "broker (RabbitMQ/Kafka/NATS), pattern (work-queue/pub-sub/event-streaming), ordering/delivery guarantees, language/framework"
---

Implement message queue infrastructure for $ARGUMENTS with reliable delivery and production-ready messaging patterns.


## Broker Selection

| Broker | Best for | Ordering | Delivery |
|--------|----------|----------|----------|
| RabbitMQ | Task queues, routing, RPC, low latency | Per-queue FIFO | At-least-once (with ack) |
| Apache Kafka | Event streaming, replay, high throughput | Per-partition | At-least-once (default) |
| NATS | Lightweight, cloud-native, low latency | Per-subject (JetStream) | At-most-once (core), at-least-once (JS) |

Decision: Flexible routing/RPC -> RabbitMQ. Event log/replay/high throughput -> Kafka. Lightweight/cloud-native -> NATS. .NET with MassTransit -> RabbitMQ (first-class). All three well-supported in Node.js.

## RabbitMQ Patterns

Exchange types: Direct (exact routing key), Fanout (broadcast), Topic (wildcard routing), Headers (match on headers).

### Work Queue (Node.js amqplib)

```typescript
// Producer
await ch.assertQueue(queue, {
  durable: true,
  arguments: { 'x-dead-letter-exchange': 'dlx', 'x-dead-letter-routing-key': `${queue}.dlq`, 'x-message-ttl': 86400000 },
});
ch.sendToQueue(queue, Buffer.from(JSON.stringify(payload)), { persistent: true, messageId: crypto.randomUUID() });

// Consumer
await ch.prefetch(10);
ch.consume(queue, async (msg) => {
  if (!msg) return;
  try { await handler(JSON.parse(msg.content.toString())); ch.ack(msg); }
  catch (err) { ch.nack(msg, false, isTransientError(err)); }
});
```

Topic exchange: `ch.publish(exchange, routingKey, ...)` with wildcards `order.*` (one level), `order.#` (multi-level).

DLQ: configure `x-dead-letter-exchange` on every queue. Messages arrive when nack'd without requeue, TTL expires, or queue length exceeded.

Rules: durable queues + persistent messages in production, manual ack (never auto-ack), prefetch for concurrency control, DLX on every queue, monitor queue depth and consumer count.

## Apache Kafka

Partitions determine ordering and parallelism. Messages within a partition are strictly ordered. Consumer groups enable parallel consumption.

### Partition Key Strategy

| Key | Guarantee | Use when |
|-----|-----------|----------|
| Entity ID | All entity events in order | Order lifecycle, user events |
| Tenant ID | All tenant events in order | Multi-tenant isolation |
| None (round-robin) | No ordering, max throughput | Independent events, logging |

### KafkaJS (Node.js)

> KafkaJS is in maintenance mode. For new production Kafka workloads, prefer `@confluentinc/kafka-javascript` (Confluent's official client, built on librdkafka) for better performance and active support.

```typescript
// Producer — idempotent, Snappy compression
const producer = kafka.producer({ idempotent: true, transactionalId: 'tx-1' });
await producer.send({
  topic: 'orders', compression: CompressionTypes.Snappy,
  messages: [{ key: event.orderId, value: JSON.stringify(event.data),
    headers: { 'event-type': event.type, 'schema-version': '1' } }],
});

// Consumer — with idempotency check
await consumer.run({
  partitionsConsumedConcurrently: 3,
  eachMessage: async ({ topic, partition, message }) => {
    const messageId = `${topic}-${partition}-${message.offset}`;
    if (await isAlreadyProcessed(messageId)) return;
    await processEvent(message.headers?.['event-type']?.toString(), JSON.parse(message.value!.toString()));
    await markAsProcessed(messageId);
  },
});
```

Exactly-once: use `producer.transaction()` with `sendOffsets` to commit consumer offsets atomically.

Rules: partition keys based on ordering needs, `idempotent: true` on producers, monitor consumer lag, Snappy/LZ4 compression, set `retention.ms` for replay needs.

## NATS

Core NATS: fire-and-forget, pub/sub with wildcards, queue groups for load balancing. JetStream: persistence, ack/nak, durable consumers, message deduplication by `msgID`.

```typescript
// JetStream publish with dedup
const pa = await js.publish('orders.created', JSON.stringify(event), { msgID: event.id });

// Durable consumer
for await (const msg of consumer.consume()) {
  try { await processEvent(JSON.parse(msg.data)); msg.ack(); }
  catch (err) { isPermanentError(err) ? msg.term() : msg.nak(); }
}
```

## Schema Registry (Kafka)

Avro with Confluent Schema Registry: register schemas, encode on produce, decode on consume. Protobuf as alternative.

Compatibility modes: Backward (add optional fields, consumers updated first), Forward (producers updated first), Full (add/remove optional only).

Rules: backward compatibility by default, new fields with defaults only, never rename/change type of existing fields, validate in CI.

## .NET — MassTransit with RabbitMQ

```csharp
builder.Services.AddMassTransit(x => {
    x.AddConsumer<OrderCreatedConsumer>();
    x.UsingRabbitMq((context, cfg) => {
        cfg.Host(config["RabbitMQ:Host"], h => { h.Username(config["RabbitMQ:User"]!); h.Password(config["RabbitMQ:Pass"]!); });
        cfg.ReceiveEndpoint("order-created", e => {
            e.PrefetchCount = 16;
            e.UseMessageRetry(r => r.Exponential(5, TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(2)));
            e.ConfigureConsumer<OrderCreatedConsumer>(context);
        });
    });
});
```

MassTransit sagas: `MassTransitStateMachine<TState>` for multi-step process management with state persistence.

## Message Ordering

Strategies: single partition/queue (global order, low throughput), partition by key (order per key, high throughput), sequence numbers (app-enforced), no ordering (maximum throughput).

Handle out-of-order: track last processed sequence per entity, skip duplicates (seq <= last), buffer gaps (seq > last + 1), drain buffer after processing.

## Idempotent Consumers

Use message ID or `topic-partition-offset` as dedup key. Check before processing, clear on failure. TTL 24-48h on dedup keys. DB unique constraints for financial operations.

## Poison Pill Handling

Track attempt count per message ID. After max attempts (3), move to DLQ. Deserialization errors -> immediate DLQ. Let broker handle retry for transient errors.

## Monitoring

| Metric | Alert threshold |
|--------|----------------|
| Consumer lag (Kafka) | >10,000 sustained |
| Queue depth (RabbitMQ) | >5,000 sustained |
| Processing latency P95 | >5s |
| Error rate | >5% of throughput |
| DLQ size | >0 |

## Anti-Patterns

- Auto-ack before processing completes — message lost on crash mid-handler; always ack after success
- Large messages (>1MB) in broker — use object storage and pass a reference; brokers are not file stores
- Publishing + DB write without outbox pattern — race condition between commit and publish on failure
- Shared DLQ for all queues — impossible to attribute or replay failures per queue/topic

## Output Format

```
Broker:            [RabbitMQ / Kafka / NATS]
Topics/Queues:     [list with partitioning]
Ordering:          [strategy and partition key]
Delivery:          [at-most/at-least/exactly-once]
Idempotency:       [dedup approach]
DLQ:               [per queue/topic]
Schema:            [Avro / Protobuf / JSON validation]
Monitoring:        [metrics and thresholds]
```

## Done Criteria

- Messages delivered with chosen delivery guarantee
- Ordering preserved for related messages
- Consumers idempotent, handle duplicates gracefully
- Poison pills detected and moved to DLQ
- Schema validated on produce and consume
- DLQ configured with alerting for every queue/topic
- Consumer lag and queue depth monitored
- Outbox pattern used when DB write + publish must be atomic
