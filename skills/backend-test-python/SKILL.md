---
name: backend-test-python
description: Add Python backend unit, HTTP, persistence, auth, job, provider, async, and concurrency tests with the repository's installed runner and framework harness. Use when Python-specific executable coverage is requested; do not migrate pytest/unittest, framework, ORM, or async mode.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.1
  domain: backend
  keywords: [python, pytest, unittest, fastapi, django, httpx, sqlalchemy, async test]
---

# Backend Test - Python

1. Read instructions, interpreter/dependency pins, runner/plugins/config, application/test clients, sync/async mode, persistence/migrations, auth/providers, fixtures and authoritative commands.
2. Generate stack context. Preserve installed pytest/unittest/Django runner, asyncio/anyio mode, HTTP client/transport, ORM and factory approach. Route implementation to `backend-implement-python`.
3. Before material setup or cleanup, resolve exact task-owned test/fixture/configuration and data targets, package/team ownership, write authority/permissions and a reversible diff plus resource recovery/cleanup path; otherwise stop.
4. Choose pure unit, framework HTTP, persistence/migration, job/event, provider-contract or concurrency boundary based on the behavior.

## Test invariants

- Direct function tests are valid for pure logic; HTTP/application tests are required when middleware, dependency injection, serialization, auth, transactions or exception mapping matter.
- Mock injected collaborators for units. Use an isolated schema-compatible database when constraints, transaction isolation, migrations, ORM query semantics or concurrency matter. SQLite, in-memory or ORM mocks are valid only when their semantic differences are outside the asserted contract.
- No real external network, production DB, queue, identity or payment calls. Reuse installed transports/interceptors/adapters/fakes and fail unhandled requests. Clean dependency overrides, event loops, tasks, DB state and globals.
- Preserve installed sync/async semantics; do not mandate `asyncio_mode`, HTTPX, factories or decorators. Avoid arbitrary sleeps; use events/barriers/controlled clocks.
- Cover invalid input, 401, current resource/tenant authorization failure, duplicate/concurrent mutation, conflict, rollback, cancellation, retry and timeout-after-effect when relevant. Verify response plus persisted/effect outcome.

Run focused and affected runner/type/lint/migration checks. Report tests, installed harness and database/provider boundary, commands/results, cleanup and residual production/provider risk.
