---
name: backend-implement-node
description: Implement non-Nest Node.js, Bun, Express, Fastify, or Elysia backend behavior with the repository's pinned runtime, framework, validation, persistence, auth, logging, and error conventions. Use when JavaScript or TypeScript server specifics dominate; route NestJS to its specialization.
metadata:
  owner: backend
  reviewed: "2026-07-27"
  version: 2.1
  domain: backend
  keywords: [nodejs, bun, express, fastify, elysia, typescript, api]
---

# Node Backend Implementation

1. Read instructions, manifests/lockfiles/engines/runtime files, module system and build, server bootstrap/lifecycle, framework/plugins, validation/errors, persistence/migrations, auth, providers, tests and deployment config. If the target is NestJS, stop and route it to `backend-implement-nestjs` rather than applying this generic recipe.
2. Generate stack context. Preserve pinned Node/Bun/TypeScript/framework compatibility and native addon/container/runtime support. Verify APIs from installed types/CLI and matching official docs; runtime, framework, module-system or compiler migration is separate.
3. Use the established framework and conventions. Do not force Express, Fastify, Elysia, TypeScript, ESM, Zod, an ORM, security middleware or architectural layers.

## Runtime and correctness

- Validate untrusted HTTP/event/provider/config data at runtime and authorize current actor, tenant and target resource server-side.
- Handle async errors through the installed framework's exact lifecycle. Never leave rejected promises, fire-and-forget work or response-after-abort paths unobserved.
- Propagate `AbortSignal`/cancellation where installed APIs support it. Any executable plan that permits an application, worker, client, or provider retry must state both a bounded attempt count and a bounded total elapsed time derived from the operation/provider evidence; an idempotency check alone is not a retry bound. Distinguish client disconnect from committed server outcome.
- Use explicit transaction/concurrency constraints and stable idempotency for retryable effects; reconcile timeout-after-commit/provider-effect.
- Avoid event-loop blocking and unbounded concurrency, body/query/file size or buffering. Parallelize only independent operations with failure/cancellation semantics defined.
- Implement graceful shutdown for the actual runtime: stop admission, drain bounded in-flight HTTP/jobs, abort remaining work, close server/pools/consumers and respect orchestrator deadline/readiness. Do not copy fixed signal/time thresholds.
- Keep request/tenant mutable state out of process singletons; redact structured logs and errors.

## Verification

Run focused and affected type/lint/test/build/start checks. Cover invalid/401/resource-tenant 403, rejected async handler, abort during downstream work, duplicate/concurrent mutation, conflict/rollback, timeout-after-effect and shutdown with in-flight work. Verify persisted/effect outcome.

Report pins/capability, lifecycle/auth/transaction decisions, changes/checks and residual runtime/provider risk.
