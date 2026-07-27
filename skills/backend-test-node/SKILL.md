---
name: backend-test-node
description: Add Node.js, Bun, Express, Fastify, Elysia, or framework-neutral backend tests with the repository's installed runner, application harness, persistence, auth, and provider boundaries. Use when executable non-Nest Node coverage is requested; do not migrate the stack or implement unrelated features.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.1
  domain: backend
  keywords: [nodejs, bun, vitest, jest, supertest, integration, api test, database]
---

# Backend Test - Node

1. Read instructions, manifests/lockfiles/engines, runner/setup, server/app factory, schemas, auth, persistence/migrations, jobs/providers, nearby tests and authoritative commands.
2. Generate stack context. Preserve installed runtime, runner, module system, HTTP injection/client and mock/interceptor libraries. Route NestJS coverage to `backend-test-nestjs` and feature implementation to the matching backend implementation skill.
3. Choose pure unit, in-process HTTP, persistence integration, contract, job/event, or concurrency test by the behavior boundary.

## Test invariants

- Mock injected dependencies for pure logic. Use an isolated schema-compatible database when proving migrations, constraints, transactions, query behavior, locking or concurrency. Do not universally mock or require a real DB.
- Use the framework's installed injection or HTTP harness; supertest is optional. Preserve Jest/Vitest/Bun test and timer semantics rather than migrating.
- Block real external network and production resources. Use installed request interception, provider adapters/fakes, containers or local isolated services; fail unhandled calls and reset mutable globals, timers, modules and handlers.
- Seed explicit tenant/actor/resource ownership. Cover 401 and resource-level 403/wrong-tenant paths, not merely missing token. When auth semantics matter, exercise the repository's installed authentication harness or pipeline rather than injecting or spoofing a principal past the boundary under test.
- For consequential work cover duplicate and concurrent invocation, database conflict, retry, effect-before-ack, timeout-after-commit, and transaction failure/rollback with no partial persisted or external-effect outcome. Verify persisted outcome and dedupe identity; mock call count is insufficient.
- Avoid arbitrary sleeps; use controllable clocks, barriers/latches, deferred promises or database synchronization to make races deterministic.

Run focused and affected repository suites plus relevant type/lint/build/migration checks. Report tests, installed harness, isolated resources/cleanup, commands/results, and untested provider/deployment risk.
