---
name: event-driven-architecture
description: Design event-driven systems with event sourcing, CQRS, projections, sagas, and the outbox pattern
metadata:
  version: 1.4
  argument-hint: "event flow, patterns (event sourcing/CQRS/sagas), message broker (Kafka/RabbitMQ/SNS), scale expectations, consistency requirements (strong/eventual)"
---

Design the event-driven architecture for $ARGUMENTS.


## Event Store Technology Selection

| Technology | Best for | Ordering guarantee | Retention |
|------------|----------|-------------------|-----------|
| EventStoreDB | Purpose-built ES, projections, subscriptions | Per-stream | Unlimited |
| Kafka (as event store) | High throughput, log compaction, streaming | Per-partition | Configurable |
| PostgreSQL event table | Simple setup, transactional outbox, existing PG | Per-aggregate (app-enforced) | Unlimited |
| .NET Marten | EF-like DX with PG-backed event sourcing | Per-stream | Unlimited |
| .NET Wolverine | Saga/process manager + messaging + ES integration | Per-stream (via Marten) | Unlimited |

Decision guide:
- Already using PostgreSQL, want simplicity? PostgreSQL event table
- .NET project with EF Core familiarity? Marten (optionally + Wolverine for messaging)
- Need high-throughput streaming + replay? Kafka
- Dedicated event sourcing with built-in projections? EventStoreDB
- Node.js project? PostgreSQL event table or EventStoreDB client

## Core Concepts

### Aggregates

Consistency boundary enforcing invariants. Each has event stream (stream ID). Commands target aggregate; aggregate decides accept/reject. State rebuilt by replaying events or snapshot+subsequent. Emits domain events on state change.

Pattern: validate command → apply event → evolve state → collect uncommitted events → persist with version check.

For .NET/Marten: define event records, implement Apply(EventType) methods — Marten calls during projection/replay.

### Aggregate Design Rules

- One aggregate per transaction boundary -- never modify multiple aggregates in one transaction
- Keep aggregates small -- only the data needed to enforce invariants
- Reference other aggregates by ID, not by embedding
- Prefer eventual consistency between aggregates over distributed transactions
- Use optimistic concurrency (expected version) to prevent conflicting writes

## CQRS (Command Query Responsibility Segregation)

### Architecture

```
Commands → Command Handler → Aggregate → Event Store → Event Bus → Projection Engine → Read Database
Queries  → Query Handler  → Read Model (optimized view)
```

### When CQRS Adds Value

- Read and write models differ significantly (denormalized views, search indexes, reporting)
- High read-to-write ratio where reads need different optimization than writes
- Multiple read representations of the same data (list view, detail view, dashboard, search)
- Audit and traceability requirements where the event log is the source of truth

### When CQRS Is Overkill

- Simple CRUD with identical read/write shapes
- Low traffic where a single model handles both well
- Small team unfamiliar with event-driven patterns

## Event Schema Design

### Event Structure

EventId (UUID), eventType (namespaced: "Order.ItemAdded"), streamId (aggregate ID), streamPosition (version), globalPosition (global order), data (payload), metadata (correlationId, causationId, userId, timestamp, schemaVersion).

### Event Naming Rules

- Past tense: `OrderCreated`, `ItemAdded`, `PaymentFailed`
- Domain language, not technical: `OrderShipped` not `OrderStatusUpdatedToShipped`
- Specific over generic: `InvoiceLineItemAdded` not `EntityUpdated`
- Namespace by aggregate: `Order.Created`, `Order.ItemAdded`, `Payment.Completed`

## Event Versioning and Upcasting

### Why

Events are immutable once stored. When the schema evolves, old events must still be readable.

### Strategies

| Strategy | Complexity | Best for |
|----------|-----------|----------|
| Weak schema (add optional fields) | Low | Minor additions |
| Upcasting (transform on read) | Medium | Field renames, restructures |
| New event type | Medium | Semantic changes |
| Stream migration (copy-transform) | High | Major schema overhaul |

### Upcasting Pattern

Transform old events on read. Check schemaVersion, apply field adds/renames. For .NET/Marten: implement IEventUpcaster<TOld,TNew> and register via AddEventUpcaster.

### Versioning Rules

- Never modify stored events -- they are immutable facts
- Add optional fields with defaults for backward compatibility (preferred for minor changes)
- Use upcasters for structural changes -- transform old shapes to current on read
- Store `schemaVersion` in event metadata for routing upcasting logic
- Test upcasting with real historical events -- not just the latest version

## Snapshot Strategies

### When to Snapshot

- Aggregate has 50+ events and rebuild time is noticeable (>100ms)
- Read-heavy aggregates where rebuild happens frequently
- Long-lived aggregates (e.g., user account, organization) with years of events

### Snapshot Pattern

Load: read latest snapshot (state + snapshotVersion) → read events from snapshotVersion+1 → apply to snapshot state.
Save: append uncommitted events with expected version; if `version % 50 === 0`, persist state as snapshot.

### Snapshot Rules

- Snapshots are an optimization, not a source of truth -- always be able to rebuild from events
- Store snapshots separately from events (different table or collection)
- Include the version number with the snapshot for correct replay
- Invalidate snapshots when the aggregate's evolve logic changes
- Do not snapshot every write -- use a threshold (every 50-100 events)

## Projections (Read Model Builders)

### Projection Types

| Type | Description | Use when |
|------|-------------|----------|
| Inline (synchronous) | Built during command handling, same transaction | Strong consistency required |
| Async (background) | Built by a subscription processor after events are stored | Eventual consistency acceptable |
| Live (on-demand) | Rebuilt from events at query time | Rarely queried, always fresh |

### Async Projection Pattern

Subscribe to event stream. Per event type: insert/update read model. Idempotent — same event twice = same result. Track checkpoint (last processed global position) for resuming.

### Read Model Rebuild

- Every projection must be rebuildable from scratch by replaying all events
- Store a checkpoint (last processed global position) per projection
- On rebuild: delete the read model, reset checkpoint to 0, replay all events
- Rebuild should be a single command: `rebuildProjection('OrderSummary')`
- Test rebuilds regularly -- a projection that cannot rebuild is a liability

### Projection Rules

- Projections are disposable -- the event store is the source of truth
- One projection per read model concern (list view, search index, dashboard, report)
- Projections must be idempotent -- processing the same event twice produces the same result
- Track checkpoint per projection -- resume from last processed position after restart
- Handle projection lag gracefully in the UI -- show "updating" or stale indicator

## Sagas and Process Managers

### When to Use

- Multi-aggregate workflows that span consistency boundaries
- Long-running processes with multiple steps (order fulfillment, onboarding)
- Coordination between bounded contexts (payment + shipping + notification)

### Saga Pattern

Coordinates multi-aggregate workflow. Listen to domain events, emit commands in sequence. Example: OrderConfirmed → ReserveInventory → ChargePayment → ShipOrder. On failure: emit compensating commands (ReleaseInventory → Refund). Track saga state by ID. Compensations idempotent (run multiple times safely).

### Compensating Transactions

- For each forward action define a compensating action; compensations must be idempotent (may run multiple times)
- Design for partial failure; log all compensation attempts

| Forward | Compensating |
|---------|-------------|
| Reserve inventory | Release inventory |
| Charge payment | Refund payment |
| Send confirmation email | Send cancellation email |
| Create shipping label | Cancel shipment |

## Outbox Pattern

### Why

When a command handler writes to the database AND publishes an event, a failure between the two leaves the system inconsistent. The outbox pattern solves this by writing events to an outbox table in the same database transaction, then publishing asynchronously.

### Implementation

Outbox table: event_type, stream_id, payload, metadata, created_at, published_at (null until published), retry_count. Index on (created_at) WHERE published_at IS NULL.

In transaction: append to event store AND insert into outbox. Background worker: poll unpublished → publish to message bus → mark published. On error: increment retry; move to DLQ after N failures.

### Outbox Rules

- Outbox write MUST be in the same transaction as the aggregate state change
- Background publisher polls the outbox and publishes to the message bus
- Mark messages as published after successful delivery
- Retry failed messages with backoff; move to DLQ after N failures
- Clean up published messages periodically (retain for 7 days for debugging)

## PostgreSQL Event Table

Schema: id (UUID), stream_id, stream_position (INT), global_position (BIGSERIAL), event_type, data (JSONB), metadata (JSONB), created_at. UNIQUE (stream_id, stream_position). Indexes on (stream_id, stream_position), (global_position), (event_type).

Optimistic concurrency: INSERT with stream_position = expectedVersion+i+1 in transaction. UNIQUE constraint error (23505) on conflict → ConcurrencyConflictError → command handler retries.

## Eventual Consistency in the UI

- **Optimistic UI** — apply locally, reconcile when projection catches up
- **Polling** — poll read model until expected version appears (max 3s timeout)
- **WebSocket/SSE subscription** — push projection updates to the client
- **Stale indicator** — show "updating..." when write version > read model version
- Never hide lag — make it visible; provide manual refresh; set max acceptable lag (2-5s); for payments/inventory prefer synchronous projections or read-your-writes

## Anti-Patterns

- Treating events as database change logs instead of domain facts
- One giant aggregate that tries to enforce all invariants -- keep aggregates small
- Modifying stored events -- events are immutable historical facts
- Projections that cannot be rebuilt from scratch -- projection = disposable cache
- Synchronous cross-aggregate operations -- use sagas for multi-aggregate coordination
- Publishing events without the outbox pattern -- leads to lost events on failure
- Snapshot-only recovery without event replay capability -- loses the source of truth
- Generic CRUD events (`EntityUpdated`) instead of meaningful domain events
- Ignoring event versioning -- schema evolution without upcasting breaks consumers
- Using event sourcing for every module -- use it where audit, replay, or temporal queries justify the complexity

## Architecture Workflow

1. Identify aggregates and their invariants
2. Define the event catalog: event types, schemas, versioning strategy
3. Choose the event store technology based on project stack
4. Design command handlers: validation, aggregate loading, event appending
5. Design projections: which read models, inline vs async, rebuild strategy
6. Design sagas for cross-aggregate workflows with compensation
7. Implement the outbox pattern for reliable event publishing
8. Define snapshot strategy for long-lived aggregates
9. Plan event versioning and upcasting for schema evolution
10. Address eventual consistency in the UI layer

## Output Format

For each event-driven design:

```
Aggregates:        [list with invariants and stream ID strategy]
Events:            [catalog of event types with schema versions]
Event Store:       [technology and configuration]
CQRS:              [command side and query side separation]
Projections:       [read models, sync/async, rebuild strategy]
Sagas:             [cross-aggregate workflows with compensation]
Outbox:            [reliable publishing strategy]
Snapshots:         [threshold and storage approach]
Versioning:        [upcasting strategy for schema evolution]
Consistency:       [eventual consistency handling in UI]
```

## Done Criteria

- Aggregates enforce invariants and emit well-defined domain events
- Event store appends with optimistic concurrency (expected version)
- Events have versioned schemas with upcasting for backward compatibility
- Projections are rebuildable from scratch and track checkpoints
- Sagas coordinate multi-aggregate flows with explicit compensation
- Outbox pattern ensures reliable event publishing without dual-write risk
- Snapshots optimize long-lived aggregate loading without sacrificing rebuild capability
- Eventual consistency is visible and handled gracefully in the UI
- Event catalog is documented with types, schemas, and ownership
