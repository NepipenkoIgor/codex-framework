---
name: api-design
description: Design read-only HTTP API contracts covering resources, schemas, errors, authorization, version compatibility, pagination, idempotency, webhooks, concurrency, and lifecycle. Use when the contract is unresolved; do not use for gateway/BFF topology or direct implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.1
  argument-hint: "consumers and use cases, resources/actions, auth/tenant model, compatibility/pagination/mutation/webhook requirements"
---

# API Design

Design `$ARGUMENTS` read-only.

1. Identify consumers, use cases, protected resources/invariants, data ownership, authorization, latency/consistency, lifecycle and compatibility commitments. Inventory existing schemas/routes/clients before proposing changes.
2. Generate project stack context and preserve installed manifest/lockfile pins. For version-sensitive guidance, check applicable engine requirements, peer dependencies, compiler/framework, schema/code generator, client/test runner and deployment runtime together against installed types/configuration and matching official documentation. For explicitly authorized greenfield creation only, resolve stable/LTS components from official sources, generate manifest and lockfile, and make those artifacts authority.
3. Define canonical resource/action semantics, request/response/error media types, validation and unknown-field behavior, dates/numbers/enums/nullability, localization and observability correlation.
4. Separate API contract from gateway/BFF routing, edge policy and service topology; route those decisions to the gateway skill.

## Contract boundaries

- Authenticate and authorize actor, tenant and target resource per operation; object IDs, hidden fields and client-provided tenant IDs are not authority.
- Version only when compatibility requires it. Define additive/breaking rules, tolerant consumers, deprecation/sunset, mixed-version rollout and generated schema/client checks; URL versioning is not universal.
- Pagination must define stable deterministic ordering and cursor/filter/sort snapshot semantics under concurrent inserts/deletes. Offset, cursor, page sizes and totals are use-case decisions, not fixed defaults.
- Consequential retryable mutations need stable client operation identity, server-side idempotency scope/retention, request-fingerprint conflict behavior and timeout-after-commit reconciliation. POST is not automatically non-retryable or idempotent.
- Before a material mutation is implemented, resolve exact targets, authority/permissions and ownership, then define effect-appropriate rollback, compensation, disablement or forward recovery; an API schema rollback alone cannot undo an external or monetary effect.
- Define optimistic concurrency/version preconditions where lost updates matter.
- Webhooks need authenticated integrity, replay protection, stable event ID/version, at-least-once duplicates, ordering scope, retries, timeout, disable/recovery, endpoint rotation, SSRF-safe registration and consumer reconciliation.
- Keep errors stable and machine-readable with safe human detail; do not leak stack, provider, database or authorization-sensitive existence information.

## Verification and output

Test schema compatibility, unknown fields, auth/resource enumeration, pagination under mutation, duplicate/concurrent idempotency, conflict/timeout reconciliation, webhook forgery/replay/duplicates/reorder and deprecation with real consumer fixtures.

Output resource/action and schema contracts, auth matrix, errors, pagination/concurrency/idempotency/webhooks, compatibility/version lifecycle, examples/OpenAPI changes, verification plan, alternatives and residual risk.
