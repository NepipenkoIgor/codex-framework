---
name: backend-implement-dotnet
description: Implement ASP.NET Core and .NET backend behavior using the repository's target framework, API style, validation, persistence, auth, logging, and test conventions. Use when .NET-specific server behavior dominates; do not use for non-.NET services or testing-only work.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.1
  domain: backend
  keywords: [dotnet, csharp, aspnet core, minimal api, controller, ef core, problem details]
---

# Backend Implement - .NET

## Establish capability

1. Read instructions, solution/project files, lock/central package config, target framework/runtime deployment, API and serialization/OpenAPI setup, persistence/migrations, auth policies, logging, and nearby tests.
2. Generate stack context. Existing projects keep their target and compatible packages; use installed types/analyzers/CLI and matching official docs. SDK, TFM, ASP.NET, EF, serializer, OpenAPI, or test-stack migration is separate scope. For greenfield selection, resolve current supported SDK/runtime and cross-stack compatibility from official sources, generate the project manifest, restore a resolved lock/package graph, and treat those generated artifacts as authority before implementation.
3. Preserve established Minimal API versus controller style, validation/error contract, DI/configuration, data access, and public compatibility unless change is explicit.

## Implementation invariants

- Validate untrusted input at the transport boundary and again at domain/persistence boundaries where invariants require it. Use the repository's single intentional validation pipeline; built-in validation, DataAnnotations, FluentValidation, or endpoint filters are capability choices, not universals.
- Authenticate and authorize actor, tenant and target resource server-side. Route/group authorization helps coverage but does not replace resource-level checks.
- Use cancellation and async only through APIs that genuinely support them; avoid sync-over-async and leaking request-scoped state.
- Keep transaction boundaries explicit. Enforce concurrency with database constraints/version tokens and make consequential retries idempotent with stable operation identity; a client-disabled button is insufficient. Derive retry/reconciliation attempt and elapsed-time bounds from provider or operation semantics and request/job deadlines. If the outcome remains ambiguous, persist pending/unknown state and hand off to bounded asynchronous reconciliation or operator review instead of waiting or retrying indefinitely.
- Shape queries to required data. Tracking, projections, includes, split queries, compiled queries, repositories, Dapper and EF are workload/repository choices, not blanket rules.
- Preserve the established error media type and schema. Use Problem Details when it is the repository/public contract; do not silently replace a versioned error contract.
- Log structured, redacted context with existing telemetry; never expose secrets, tokens, PII, stack traces, or raw provider payloads.

## Verification

Run focused and affected restore/build/analyzer/test/migration-contract checks. Exercise invalid input, unauthenticated, forbidden resource/tenant, duplicate/concurrent mutation, conflict, cancellation, timeout-after-commit, retry exhaustion with pending/reconciliation handoff, and persistence rollback where relevant. Verify response plus persisted outcome; compilation alone is not proof.

Report installed capability, files/contracts changed, auth/transaction/idempotency decisions, commands/results, migration/deployment paths not exercised, and residual risk.
