# Cross-service transport notes

Load only the selected transport/platform section conceptually. Verify exact APIs against installed generated clients, runtime types, CLI/schema help and matching official documentation; do not copy remembered Node, .NET, NestJS, gRPC, gateway or service-mesh syntax.

## Transport selection

- REST/HTTP is appropriate when ubiquitous request-response interoperability matters. Define media/schema compatibility, status/error contract, deadlines/cancellation, conditional/idempotent mutation semantics and connection behavior.
- gRPC is appropriate when supported typed contracts, streaming or efficient internal calls justify its operational constraints. Preserve field identity and wire compatibility, treat generated code as derived, and plan mixed-version rollout.
- Durable messaging is appropriate for temporal decoupling, buffering or fan-out. Define producer/event identity, partition/order scope, acknowledgement, retry/poison behavior, schema compatibility, replay and consumer idempotency.
- A gateway, mesh, broker or discovery system is not a default. Adopt it only when its ownership, failure modes, latency, cost and migration are justified by the current environment.

## Deadline and failure contract

- Allocate an end-to-end deadline across hops and propagate remaining budget and cancellation. Select values from caller SLO, measured latency and dependency behavior; never embed corpus-wide timeouts.
- Retry only classified transient failures when the operation/effect is safe under duplicate execution. Bound attempts, elapsed budget and concurrency with jitter, and prevent multiplicative retries across layers.
- Circuit breaking, bulkheads, hedging and fallback are evidence-based controls. Define what they protect, state ownership, recovery probe, compatibility and user-visible degradation before enabling them.
- A timeout may occur after downstream effect or commit. Reconcile by stable request/effect identity or authoritative status; do not infer rollback.
- Idempotency scope and retention follow the business effect and ambiguity window. Not every request needs a key, and a deterministic key must not collapse distinct operations.

## Data and compatibility

- Keep authoritative data and transaction ownership local to one service boundary. Coordinate cross-boundary effects through durable handoff/outbox, idempotent consumers, compensation and reconciliation rather than an unprotected dual write.
- Evolve schemas from observed consumers. Test old/new producer and consumer combinations, unknown fields/enum values, requiredness/nullability, deprecated-field removal and replayed historical messages.
- Propagate authenticated service identity and request context deliberately, but reauthorize the target tenant/resource in the receiving service. Do not trust forwarded ownership claims.

Verify slow/down/partial dependencies, cancellation, retry amplification, duplicate/concurrent requests, timeout-after-effect, incompatible versions, wrong-tenant context, queue lag/backpressure, poison/replay, failover and recovery. Report caller-visible outcome plus transport telemetry.
