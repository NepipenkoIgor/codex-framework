# Backend architecture decision notes

Use this reference to compare alternatives, not to select a fashionable topology. Exact framework, ORM, transport and hosting syntax must come from the installed stack and matching official documentation.

## Boundary choices

- Begin with current request/event/job flows, ownership, deployment coupling and failure evidence. A modular monolith is often the lower-cost baseline; independent services require independently valuable ownership, scaling, isolation or release boundaries.
- Organize by cohesive business capability and data authority. Layers, ports/adapters, vertical slices, DDD, CQRS and event sourcing are optional tools, not maturity levels.
- Define public API/event/job contracts separately from persistence models. Validate external inputs and keep authentication, tenant/resource authorization and sensitive output policy explicit at every boundary.

## Data and consistency

- Give each authoritative write a clear transaction owner. Cross-boundary effects require durable handoff, idempotent processing, ambiguity reconciliation and compensating product behavior where rollback is impossible.
- Choose optimistic, pessimistic or serialized concurrency from the invariant and contention evidence. Preserve audit/financial history according to domain rules rather than applying append-only storage everywhere.
- Define cache authority, invalidation, stale-read tolerance, replica behavior, deletion/retention and migration compatibility before adding distributed state.

## Runtime and operations

- Allocate deadlines, cancellation, capacity and backpressure across calls, jobs and queues. Retry, circuit breaking, bulkheads, fallback and feature flags need an owned failure hypothesis and recovery path.
- Model secrets, trust boundaries, service identity, least privilege, network exposure and abuse cases. Logging/tracing must preserve correlation without leaking credentials or unnecessary personal data.
- Select repository and platform patterns from installed capability. Do not mandate a particular ORM, validation library, mediator, repository wrapper, broker, cache or cloud service.

## Decision evidence

Compare at least the smallest viable change and one credible alternative across correctness, latency/capacity, operability, security, cost, team ownership, migration and reversibility. Define a mixed-version rollout, data reconciliation, canary/abort criteria, rollback and removal of transitional paths. Validate with executable contract, load/failure, authorization and migration tests before implementation commitment.
