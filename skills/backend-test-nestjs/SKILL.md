---
name: backend-test-nestjs
description: Add NestJS unit, module, HTTP, persistence, guard, pipe, filter, interceptor, or job tests with the repository's installed runner and harness. Use when Nest-specific executable coverage is requested; do not use for implementation without a testing deliverable.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.1
  domain: backend
  keywords: [nestjs, testingmodule, jest, vitest, supertest, guard, pipe, e2e]
---

# Backend Test - NestJS

Add tests to the repository without migrating its runner, adapter, bootstrap, validator, ORM, or application structure.

1. Read instructions, manifests/lockfiles, runner config/setup, Nest bootstrap/global providers, target module, persistence/auth/provider boundaries, nearby tests and authoritative commands.
2. Generate stack context and use installed Nest/runner/adapter APIs. Route non-Nest Node coverage to `backend-test-node`; route feature implementation to `backend-implement-nestjs`.
3. Before material setup or cleanup, resolve exact task-owned test/fixture/configuration and data targets, package/team ownership, write authority/permissions and a reversible diff plus resource recovery/cleanup path; otherwise stop.
4. Choose the smallest faithful boundary: direct provider/pipe/guard unit, TestingModule integration, real application bootstrap/HTTP adapter, persistence integration, or job/event handler.

## Boundary rules

- Minimal modules are useful for unit isolation; importing the application root is valid when proving real module graph and global bootstrap. Reproduce global pipes, filters, interceptors and guards through the same bootstrap path where their behavior matters.
- Mock injected collaborators for pure units. Use an isolated schema-compatible database when constraints, transactions, query semantics, migrations or concurrency are under test. Neither “always mock DB” nor “always real DB” is correct.
- No test may call real external networks, production databases, queues, email, payments or identity providers. Use installed interceptors/adapters, fakes, containers or isolated local services and fail on unhandled calls.
- Preserve installed Jest/Vitest and mocking libraries; do not add supertest, deep-mock packages or JWT forgery conventions universally.

Cover invalid input, unauthenticated 401, authenticated-but-forbidden resource/tenant 403 or repository-equivalent, duplicate/concurrent mutation, conflict, transaction rollback, timeout-after-effect, retry/idempotency and global pipeline parity where relevant. A race-sensitive test must use a barrier, latch or controlled interleaving at the actual idempotency/transaction boundary rather than merely firing two requests concurrently. Verify response plus persisted/effect outcome, not just controller/provider calls.

Run focused and affected suites and report tests, harness/boundary, commands/results, isolation cleanup and residual provider/deployment risk.
