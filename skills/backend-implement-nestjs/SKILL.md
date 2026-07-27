---
name: backend-implement-nestjs
description: Implement NestJS backend behavior using the repository's installed modules, adapter, validation, persistence, auth, configuration, error, logging, and test conventions. Use when Nest-specific structure dominates; do not load a generic Node implementation skill for the same task.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.1
  domain: backend
  keywords: [nestjs, nodejs, typescript, controller, provider, guard, pipe, interceptor]
---

# Backend Implement - NestJS

## Establish capability

1. Read instructions, manifests/lockfiles/engines, Nest and TypeScript config, HTTP adapter, bootstrap/global pipeline, feature modules, persistence/migrations, auth, config/logging and nearby tests.
2. Generate stack context and verify installed Nest/Node/TypeScript/adapter/ORM APIs from types, schemas/CLI and matching official docs. Preserve the compatibility set; dependency, decorator, module-system, adapter, validator or ORM migration is separate.
3. Follow the repository's module/provider/controller conventions. Do not impose one-feature-module, global ConfigModule, class-validator, Prisma, TypeORM, REST pluralization, serializer, or Problem Details recipes universally.

## Implementation invariants

- Keep transport concerns at controller/pipe/filter/guard boundaries and domain/persistence behavior in cohesive providers where separation improves ownership; do not create ceremonial layers.
- Validate every untrusted body/param/query/event with the installed validation integration and preserve transformation semantics. TypeScript types alone are not runtime validation.
- Authenticate and authorize actor, tenant and target resource server-side for every path. Guard metadata does not replace current resource ownership checks.
- Preserve adapter-specific lifecycle and error behavior. Centralize expected error mapping where established; do not expose stack traces or silently change public error schemas.
- Use explicit transaction/concurrency boundaries for multi-step mutations. Stable idempotency and persisted outcome reconciliation are required when duplicate delivery or timeout-after-commit is possible.
- Keep request/tenant mutable state out of singleton providers. Derive bounded downstream retry/reconciliation attempts and elapsed time from provider or operation semantics and request/job deadlines. If an outcome remains ambiguous, persist pending/unknown state and hand off to bounded asynchronous reconciliation or operator review instead of waiting or retrying indefinitely. Redact logs.

## Verification

Run repository-authoritative focused tests and affected type/lint/build/integration/migration checks. Cover global bootstrap parity, invalid input, 401, 403/wrong tenant or resource, duplicate/concurrent requests, conflict, provider timeout-after-effect and rollback. Verify persisted outcomes, not only controller calls or status codes.

Report installed capability, module/contract changes, validation/auth/transaction/idempotency choices, commands/results, and untested deployment/provider risk.
