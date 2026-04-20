---
name: backend-architecture
description: Design backend architecture for .NET, ASP.NET Core, Node.js, Bun, NestJS, Elysia, TypeScript, or JavaScript applications
metadata:
  version: 1.6
  argument-hint: "tech stack (Node.js/NestJS/ASP.NET Core/.NET), feature scope, scalability needs (monolith/microservices/modular), database/cache requirements"
---

Design the architecture for $ARGUMENTS.

## Tool Integration

- **Language diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone

Core architecture principles:

- Follow existing project conventions when extending an existing system
- Design systems that are easy to implement, test, evolve, and operate
- Keep service boundaries, contracts, and persistence responsibilities explicit
- Separate transport, validation, orchestration, business logic, persistence, and infrastructure
- Avoid over-engineering; prefer the smallest clean architecture that fits the problem
- Prefer explicit, predictable data flow with aligned runtime validation and compile-time typing
- Design for operational clarity, not just conceptual elegance

Architecture goals:

- Clear module boundaries and explicit contracts
- Efficient persistence design and clean async orchestration
- Reliable side effects and maintainable background processing
- Predictable error handling and implementation-ready structure
- Good developer ergonomics with reasonable extensibility

Architecture completeness checklist:

- Identify transactional vs non-transactional flows; synchronous vs deferred background flows
- Identify read-heavy, write-heavy, and side-effect-heavy paths separately
- Identify audit, traceability, and compliance needs
- Identify payment, billing, refund, credit, balance, or ledger-like requirements
- Identify streaming, real-time, long-running, and event-driven workflows
- Identify authorization, tenant isolation, and boundary protection requirements
- Identify reporting, analytics, and projection-heavy read requirements
- Identify retention, archival, and deletion requirements
- Identify idempotency, deduplication, retry, and replay requirements
- Identify operational risk areas before finalizing the design

Architecture workflow:

1. Identify the business goal and core use cases
2. Identify the main modules, bounded contexts, or feature areas
3. Define core domain concepts, entities, aggregates, and relationships
4. Define write flows, read flows, background flows, and integration boundaries
5. Define request, response, command, event, and job contracts
6. Design persistence strategy, schema, indexes, and query patterns
7. Define service, handler, and infrastructure boundaries
8. Map the architecture into implementation-ready structure for the target stack
9. Highlight tradeoffs, risks, and recommended next steps

Problem framing:

- Clarify the primary business workflow before designing tables or handlers
- Distinguish core domain logic from supporting workflows and external integrations
- Prefer explicit assumptions when requirements are incomplete
- Design for the stated use case first, then extension points second

Module and service architecture:

- Define modules with clear ownership; keep responsibilities narrow
- Avoid god-services and god-modules; separate transport, business, persistence, and integration
- Prefer explicit boundaries between API, application, domain, and infrastructure layers
- Remove unnecessary indirection; prefer semantic naming reflecting purpose

```typescript
// Service layer pattern: transport -> validation -> service -> persistence
// Each layer has one responsibility with explicit contracts between them.

// 1. Transport: thin handler, delegates to service
// routes/orders.ts
app.post("/orders", async (req, res) => {
  const input = CreateOrderSchema.parse(req.body);
  const order = await orderService.createOrder(input, req.user.id);
  res.status(201).json(OrderResponse.from(order));
});

// 2. Service: business logic, orchestration, side effects
// services/order.service.ts
class OrderService {
  async createOrder(input: CreateOrderInput, userId: string): Promise<Order> {
    const user = await this.userRepo.findById(userId);
    if (!user) throw new NotFoundError("User");

    const order = Order.create({ ...input, userId, status: "pending" });
    await this.orderRepo.save(order);
    await this.eventBus.publish(new OrderCreatedEvent(order.id));
    return order;
  }
}

// 3. Contracts: explicit DTOs, never leak persistence models
// contracts/order.contracts.ts
const CreateOrderSchema = z.object({
  productId: z.string().uuid(),
  quantity: z.number().int().positive().max(100),
});
type CreateOrderInput = z.infer<typeof CreateOrderSchema>;
```

Domain modeling:

- Identify core entities, value structures, and relationships
- Distinguish write models from read models when needs differ materially
- Prefer explicit ownership of state transitions and business rules
- Prefer domain models reflecting real business behavior over generic CRUD objects

AI product architecture:

- Separate prompt storage/versioning from runtime assembly
- Track prompt version history, token usage, latency, and model usage
- Preserve AI interaction logs for debugging and quality monitoring
- Design evaluation datasets for prompt drift detection

State and flow design:

- Keep state ownership explicit; avoid hidden mutable shared state
- Distinguish request-time state, persisted state, and transient orchestration state
- Design side effects explicitly rather than burying them in generic services

Read and write separation:

- Distinguish write paths (optimized for correctness) from read paths (optimized for projection, filtering, pagination)
- Avoid forcing one model shape to satisfy every read and write use case

Async and orchestration design:

- Design async flows explicitly: request-time work, background jobs, queue consumers, integration retries
- Handle success, failure, retry, timeout, cancellation, idempotency deliberately
- Distinguish synchronous user-facing operations from deferred background work
- Design for predictable failure semantics and recoverability

Transactions and consistency:

- Define transaction boundaries explicitly; distinguish strongly consistent from eventually consistent
- Keep transactional writes small and bounded; identify compensating actions for multi-step workflows
- Avoid mixing database writes, HTTP calls, and message publishing without a consistency strategy
- Prefer outbox-like patterns when DB changes and message publication must remain aligned

Credits / ledger architecture:

- Append-only transaction tables; never mutate past financial transactions
- Derive balances from transaction history; ensure idempotent credit mutations
- Use database transactions for credit adjustments; avoid mutable balance columns without ledger backing

Concurrency and locking:

- Prefer optimistic concurrency by default; pessimistic locking only when correctness requires it
- Define versioning or compare-and-swap strategies for concurrent modification risk
- Design double-submit and double-processing prevention explicitly where relevant

Idempotency, deduplication, and replay safety:

- Identify all flows that may be retried, replayed, or delivered more than once
- Design idempotency for payments, webhooks, message handlers, background jobs, and user actions with side effects
- Prefer durable idempotency keys or deduplication records; do not assume exactly-once delivery

Performance and efficiency:

- Avoid chatty service boundaries, unnecessary database round-trips, and unnecessary HTTP calls
- Prefer batching, projection, efficient query shaping, and bounded list endpoints
- Design hot paths explicitly; use caching only when justified

Validation and contracts:

- Validate at the boundary; prefer schema-driven validation over ad-hoc checks
- Distinguish transport validation from business-rule validation
- Keep contracts explicit, stable, and deterministic

Error handling and reliability:

- Design expected failure behavior explicitly; avoid broad catch-all handling
- Ensure retries, idempotency, deduplication where side effects exist
- Design modules so failures can be diagnosed without guesswork

Payments, balances, and money movement:

- Treat money movement as a high-risk domain; prefer ledger-like modeling over mutable balance-only modeling
- Design idempotent payment, refund, payout, and webhook handling
- Distinguish intent, authorization, capture, settlement, refund, and failure states
- Preserve immutable financial history; design reconciliation flows
- Prefer explicit money value types over raw floating-point values

Anti-patterns to avoid:

- God-services, god-modules, sync-over-async, blocking I/O in async flows
- Mixing validation, persistence, HTTP, integration, and business rules in one place
- Leaking persistence models into API responses; hidden side effects
- Speculative architecture; one generic model trying to satisfy database, domain, API, and UI

Observability:

- Follow existing logging/telemetry patterns; design for failure localization
- Avoid noisy logs; never leak secrets into logs or responses

Feature flags and rollout safety:

- Identify features needing staged rollout or kill switches
- Prefer explicit feature-flag boundaries for risky integrations and payment flows

Auditability and traceability:

- Identify actions requiring immutable audit history
- Distinguish operational logs from business audit records
- Preserve who, what, when, and why; prefer append-friendly audit records

Type modeling:

- Strong types over weakly typed dictionaries; keep shared contracts/DTOs in dedicated files
- Move non-trivial types into colocated type files; do not centralize unrelated types
- Use advanced type features for safety, not cleverness; avoid any and weak typing

Validation and schemas:

- Prefer Zod in TS/JS backends; schema-first modeling with derived types
- In .NET, prefer the project's established validation approach

API and transport design:

- Explicit request/response contracts; stable, predictable, bounded API shape
- Do not return persistence entities directly; design transport contracts around use cases

Persistence strategy:

- Use the project's established persistence technology
- Design explicitly for both correctness and query efficiency
- Distinguish persistence strategy for write-heavy vs read-heavy flows

.NET persistence:

- EF Core default; DbContext directly; no wrapper repositories without business value
- Prefer projection, AsNoTracking for reads; design to prevent entity leakage into API contracts
- Dapper for query-heavy read paths; parameterized queries; complex SQL in dedicated modules

TypeORM (Node.js/NestJS/Bun):

- Follow existing patterns; QueryBuilder for complex queries
- Do not leak ORM entities through API contracts
- Transaction-scoped entity manager; keep ORM usage aligned with feature boundaries

Inline SQL rules:

- No large inline SQL in handlers; complex queries in dedicated modules
- Small parameterized queries acceptable when readable; never concatenate user input

Database design principles:

- Design tables around real business ownership and lifecycle rules
- Explicit PKs, FKs, unique constraints, indexes, bounded nullability
- Prefer normalized models for writes; explicit read models/projections when read needs differ
- Design for efficient filtering, sorting, paging; avoid N+1 pressure from weak schema design

PostgreSQL / Supabase:

- Explicit schema ownership and tenant isolation; RLS enforcement at database layer
- Tenant keys (brand_id) on every tenant-scoped table; indexes include tenant filter columns
- Default deny-all until explicit RLS policies defined; database-enforced isolation preferred
- RLS policies for: authenticated user, service role, admin, system internal operations

Database and persistence:

- Efficient queries, explicit boundaries, explicit transaction boundaries
- Avoid excess data loading; prefer projection at the database
- Avoid N+1 patterns; pagination for list endpoints; design schema and access patterns together

Migration and schema evolution:

- Design schema changes for safe evolution; prefer backward-compatible changes
- Distinguish additive, breaking, and data migration changes
- Plan backfills and re-indexing; consider deployment ordering for code+schema evolution

Retention, archival, and deletion:

- Distinguish soft delete, hard delete, archival, and retention expiration
- Preserve financial, audit, and reconciliation history where deletion would break traceability
- Design cleanup flows for high-volume tables and job history

Background jobs and messaging:

- Focused handlers; validate payloads at boundary; prefer idempotent handlers
- Handle retries, deduplication, timeout, cancellation, and partial failures
- Design background execution, retry, and failure ownership explicitly
- Consider outbox patterns when side effects must remain reliable

Streaming and real-time:

- Distinguish request-response from real-time delivery (polling, websocket, SSE, SignalR)
- Design explicit lifecycle states for long-running jobs
- Define replay, reconnect, and missed-event handling where reliability matters

External integrations:

- Focused integration services; validate external payloads at boundary
- Explicit timeout, retry, and error handling; normalize provider data at the boundary
- Design third-party failure and degraded-mode behavior explicitly

File storage and large payloads:

- Avoid large binaries in transactional tables; separate metadata from content storage
- Design upload, download, retention, access control, and cleanup deliberately

Security:

- Validate all external input at boundary; never trust raw payloads
- Explicit authorization checks; keep sensitive operations auditable
- Design trust boundaries explicitly

Rate limits, quotas, and abuse boundaries:

- Identify endpoints needing rate limiting, quotas, or cost protection
- Avoid architectures allowing unbounded retries, exports, streaming, or expensive queries

Multi-tenant and boundary isolation:

- Make tenant and ownership boundaries explicit in contracts, persistence, and authorization
- Avoid cross-tenant reads/writes; tenant-safe indexes and constraints
- brand_id on every tenant-scoped table; background jobs and admin flows respect isolation

External auth and identity mapping:

- Distinguish identity provider user id from internal user record id
- Ensure tenant and user claims required for RLS are explicit

.NET / ASP.NET Core non-negotiable rules:

- Async all the way; no sync-over-async; use CancellationToken where relevant
- Do not leak EF entities through API contracts
- No business logic in controllers when a service boundary is warranted
- Explicit validation at the boundary; modern .NET APIs preferred
- Map architecture decisions into implementation-ready project structure

Node.js / Bun:

- Explicit module boundaries; no hidden mutable process-wide state
- Do not block the event loop; explicit async error handling
- Zod for validation and schema modeling
- Map architecture into implementation-ready route, service, validation, and integration structure

NestJS non-negotiable rules:

- No heavy business logic in controllers; no unnecessary providers/modules
- Explicit validation at the boundary; narrow testable services
- Design module boundaries so they remain implementable without over-fragmenting

Bun / Elysia non-negotiable rules:

- No unnecessary architectural weight for small features
- Schema-first request validation; colocated route contracts and handlers
- Map design into implementation-ready route modules, contracts, and query boundaries

Implementation mapping:

- Translate architecture into implementation-ready modules, folders, handlers, services, contracts, persistence models, and query paths
- Make clear which parts are write-path, read-path, background-path, and integration-path
- Make clear where validation, orchestration, persistence, and side effects happen
- Architecture output should be directly convertible into estimates, tasks, and implementation steps

Database schema output requirements:

For each table include:

- purpose, columns with types, primary key, foreign keys
- unique constraints, indexes
- table classification (tenant-global / brand-scoped / user-scoped / system-internal / admin-only)
- RLS policy strategy, ownership model, write pattern, mutability model
- who can SELECT / INSERT / UPDATE / DELETE and access scope

Output requirements:

- Start with a short architecture summary
- Identify the main modules, domain concepts, and boundaries
- Define recommended contracts, persistence strategy, schema, and query strategy
- Define recommended background jobs, integration flows, and reliability considerations
- Map the design into implementation-ready structure for the target stack
