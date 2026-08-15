---
name: backend-test-dotnet
description: Add .NET and ASP.NET Core unit, HTTP, persistence, auth, job, provider, and concurrency tests with the repository's installed runner and application harness. Use when .NET-specific executable coverage is requested; do not migrate xUnit, NUnit, MSTest, assertion, mocking, or database tooling.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.2
  domain: backend
  keywords: [dotnet, aspnet core, xunit, nunit, mstest, webapplicationfactory, ef core, integration test]
---

# Backend Test - .NET

1. Read instructions, solution/projects/TFMs, central package/lock config, runner and test host, application bootstrap, persistence/migrations, auth/providers, nearby tests and authoritative commands.
2. Generate stack context and preserve installed runner, assertion/mock libraries, host factory and database/container tooling. For greenfield work, generate/restore the chosen manifest and lock/package graph and make them authoritative. Route implementation to `backend-implement-dotnet`.
3. Before material setup or cleanup, resolve exact mutable targets, authority/permissions, ownership and rollback/recovery; use only task-owned isolated state.
4. Choose direct unit, service/provider integration, WebApplicationFactory or repository host, schema-compatible persistence, job/event, or concurrency test by the behavior boundary.

## Test invariants

- Use direct construction and mocks/fakes for pure services. Use the real application pipeline when filters/middleware, auth, serialization, DI lifetimes or error mapping matter.
- Use an isolated database with the semantics required by the assertion. EF InMemory/SQLite may be suitable for behavior that does not depend on relational constraints, transactions or provider SQL; use the matching provider/container for migrations, constraints, locking and concurrency. No universal Testcontainers requirement.
- Never call production databases or real external providers. Override endpoints/clients through repository seams, fail unhandled calls and isolate test credentials/config.
- Preserve xUnit/NUnit/MSTest and existing assertions; bare framework asserts are not defects. Share factories/HttpClient only according to documented thread safety and test isolation, not blanket rules.
- Seed actor, tenant and resource ownership. Cover unauthenticated, forbidden resource/tenant, invalid input, duplicate/concurrent mutation, concurrency-token conflict, rollback and cancellation. Whenever an external provider or job can accept a side effect before its response is lost, add an executable timeout-after-effect case that asserts reconciliation and retry/idempotency behavior; do not defer that case behind later inspection. Verify persisted outcome and idempotency, not only response status.

Run focused and affected `dotnet` restore/build/test/analyzer/migration-contract commands from the repository. Report the explicit invalid-input, unauthenticated, wrong-resource/tenant, duplicate/concurrent, conflict, rollback, cancellation, and timeout-after-effect coverage that is applicable, plus installed harness/provider boundary, commands/results, cleanup and unverified deployment/provider risk.
