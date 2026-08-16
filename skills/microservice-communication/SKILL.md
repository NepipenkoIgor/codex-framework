---
name: microservice-communication
description: Design or implement communication contracts between independently deployed services across REST, gRPC, and messaging with compatibility, deadlines, cancellation, retries, idempotency, partial failure, backpressure, auth, and observability. Use when inter-service communication is primary; route edge gateway/BFF topology and public API contract design to their dedicated skills, and do not use for in-process modules.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.1
  argument-hint: "services/owners, sync-async semantics, SLO/deadline, compatibility, auth/idempotency/failure and migration"
---

# Microservice Communication

Read [the full transport guide](references/full-guide.md) only for the selected installed protocol/platform.

1. Resolve the exact repository, services, contracts and deployment targets authorized for change, their code/runtime owners and required permissions, then map service/data ownership, trust/tenant boundaries, call/event graph, latency budget, load, consistency and partial-outage modes. Define recovery or rollback for contract, configuration and deployment before mutation.
2. Choose synchronous communication only for immediate authoritative response; choose durable asynchronous transport for temporal decoupling, buffering or fan-out. Do not force microservices, gRPC, messaging or a gateway.
   Do not infer that a transport or broker is installed merely because the requirement needs synchronous validation or durable events. Use observed repository/runtime capability, or keep the transport choice unresolved with explicit evaluation and migration evidence.
3. Define schema ownership/version compatibility, auth/service identity and resource authorization, deadlines/cancellation, idempotency, ordering scope, retries, backpressure and observability before implementation.
4. Allocate end-to-end deadline across hops. Derive concrete deadline, attempt, elapsed-time and backoff bounds from the caller SLO, observed latency/error behavior, provider contract and effect ambiguity; do not copy generic values. Retry only transient safe/idempotent operations within those bounds and prevent retry amplification. Circuit/bulkhead/hedging are evidence-based, not defaults.
5. Avoid dual writes/distributed transactions: use local transaction plus outbox/durable handoff, compensation and reconciliation. Handle effect/commit before timeout and duplicate/out-of-order delivery.
6. Plan mixed-version producer/consumer rollout, generated contract tests, canary, rollback and deprecated-field removal.

Test slow/down/partial dependencies, deadline/cancellation, duplicate/concurrent retries, timeout-after-effect, incompatible versions, auth/tenant propagation, queue lag/backpressure, replay and recovery. Report transport/contract, failure semantics, compatibility rollout, telemetry and residual distributed risk.
