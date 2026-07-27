---
name: backend-test
description: Add framework-neutral backend unit, integration, contract, persistence, auth, concurrency, retry, and failure tests with the repository's installed harness. Use when no sharper Node, NestJS, Python, or .NET test specialization dominates; do not implement unrelated features.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.1
  argument-hint: "behavior/contract, runtime/framework and installed runner, persistence/provider fidelity"
---

# Backend Test

This is a `repository_write` workflow.

1. Read instructions, manifests/lockfiles, runner/setup, target and public contract, persistence/migrations, auth/providers, fixtures and authoritative commands. Before material setup or cleanup, resolve exact mutable targets, authority/permissions, ownership and rollback/recovery; use only task-owned isolated state.
2. Route Node, NestJS, Python or .NET-dominant coverage to its specialization. Preserve installed runner, language, application harness and database/provider tooling.
3. Choose the smallest faithful unit, HTTP/application, persistence/migration, job/event, contract or concurrency boundary. Mock injected collaborators for pure logic; use schema/provider-compatible isolated infrastructure when constraints, transactions, locking, query or migration semantics matter.
4. Block real external networks and production databases, queues, identity, email or payment providers. Fail unhandled calls and clean task-owned state, clocks, globals and processes.
5. Cover invalid input, 401, current resource/tenant 403, duplicate/concurrent mutation, conflict/rollback, retry/idempotency and timeout-after-effect as relevant. Use deterministic barriers/clocks, not arbitrary sleeps. Verify response plus persisted/effect outcome.

Run focused and affected suites/checks. Report tests, installed harness/fidelity boundary, commands/results, cleanup and residual provider/deployment risk.
