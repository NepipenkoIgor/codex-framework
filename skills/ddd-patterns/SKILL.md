---
name: ddd-patterns
description: Design domain boundaries, language, aggregates, invariants, repositories, domain events, and integration contracts only where business complexity justifies them. Use when domain modeling decisions are unresolved; do not use to force layers onto simple CRUD or for direct implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-09-09"
  version: 1.6
  argument-hint: "business capabilities/invariants, ambiguity/change rate, transaction and integration boundaries, existing model"
---

# Domain-Driven Design Patterns

Design `$ARGUMENTS` read-only.

Inspect manifests/lockfiles and generate project stack context before version-sensitive framework/ORM/event guidance. Preserve installed runtime and capability pins, verify matching official documentation, and treat upgrades as separate migrations; read-only greenfield design hands version selection to authorized project setup.

Identify the applicable repository target, governing instructions and implementation owner. For any proposed later mutation, state the required write authority and effect-appropriate recovery or rollback before handing the design to an implementation workflow.

1. Gather business language, policies, invariants, ownership, change hotspots and integration pain from domain experts and repository behavior. Show concrete complexity that a domain model would reduce.
2. If behavior is simple CRUD with stable language and no meaningful invariants, recommend a simpler modular model. DDD does not require entities/value objects/repositories/services/events or layered/hexagonal architecture everywhere.
3. Define bounded contexts by language, ownership and consistency, not tables, teams or deployment count. Document context relationships and translation/anti-corruption needs.

## Model contracts

- An aggregate is the smallest consistency/concurrency boundary needed to enforce invariants. Choose root, identity and transaction scope from business rules; avoid giant aggregates and arbitrary one-aggregate-per-transaction dogma when the store supports a justified atomic invariant.
- Enforce authorization outside and inside domain operations where actor/resource policy affects invariants. Tenant scope is part of identity and repository queries where applicable.
- Use optimistic/pessimistic concurrency and database constraints according to conflict semantics; define retry versus user-visible conflict.
- Repositories represent meaningful aggregate persistence when useful, not mandatory ORM wrappers. Domain services exist for domain operations that fit no entity/value object, not miscellaneous orchestration.
- Domain events describe committed facts. When publishing across a transaction boundary, define outbox/CDC, at-least-once duplicates, idempotent consumers, schema compatibility and timeout/reconciliation; in-memory dispatch is not reliable integration. If the requested design explicitly publishes after commit, do not evade its failure boundary by removing the event path or declaring integration tests inapplicable: either provide the durable design or report the requested in-memory design as unsafe.
- Sagas/compensation and event sourcing are optional and require explicit long-running or historical/replay value.

## Verification and output

Test aggregate invariants, concurrent commands, constraint conflicts, tenant/resource authorization, transaction rollback, outbox crash window, duplicate/reordered events and context translation with executable examples or model scenarios. Whenever the design publishes an event after commit, the executable plan must include inputs, actions and observable assertions for the crash window, idempotent duplicate delivery, reordering and reconciliation; do not defer those cases as conditionally inapplicable.

Report evidence for/against DDD, ubiquitous language, contexts/map, aggregates/invariants/concurrency, persistence/events/integration, simpler alternatives rejected, verification and residual ambiguity.
