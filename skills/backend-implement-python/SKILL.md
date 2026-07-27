---
name: backend-implement-python
description: Implement Python backend behavior using the repository's pinned interpreter, FastAPI/Django or other framework, validation, sync/async, persistence, auth, logging, and test conventions. Use when Python-specific server behavior dominates; do not use for non-Python or testing-only work.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.1
  domain: backend
  keywords: [python, fastapi, django, sqlalchemy, pydantic, alembic, async]
---

# Backend Implement - Python

## Establish capability

1. Read instructions, interpreter/runtime files, dependency manifest/lock, framework/config, ASGI/WSGI deployment, validation/serialization, ORM/migrations, auth, jobs, logging and nearby tests.
2. Generate stack context. Preserve the pinned interpreter and installed FastAPI/Django/Pydantic/SQLAlchemy/async-driver compatibility. Verify APIs from installed objects/types/CLI and matching official docs; runtime, Pydantic, ORM, package-manager or sync/async migration is separate.
3. Preserve the repository's framework, package manager, typing strictness, settings, error and response contracts. Do not mandate uv, pytest, Pydantic, SQLAlchemy, `response_model`, JSON logging, or one auth library when the project uses another supported contract.

## Implementation invariants

- Validate untrusted request/event/provider data at the boundary and preserve public serialization/error schemas. Static annotations are not runtime validation.
- Match sync/async handlers to actual dependencies. Do not block an event loop, create nested loops, share sessions across requests, or parallelize operations whose transaction/order/connection semantics require sequencing.
- Authenticate and authorize actor, tenant and target resource server-side; claims and route dependencies do not alone prove current ownership.
- Reject interpolated/string-built SQL and use bound ORM/query parameters with explicit transaction/concurrency boundaries. Make consequential retries idempotent, derive attempt and elapsed-time bounds from operation evidence, and reconcile timeout-after-commit/effect.
- Use the installed migration path for schema changes; do not replace it with metadata creation or an incidental ORM migration.
- Bound provider calls, cancellation and retries; redact structured logs and responses.

## Verification

Run focused and affected repository checks for typing/lint/tests/migrations/build or packaging. Cover invalid input, unauthenticated, forbidden resource/tenant, sync/async cancellation, duplicate/concurrent mutation, conflict, timeout-after-effect and transaction rollback. Use isolated test dependencies; no real production database/provider.

Report pins/capability, contracts changed, async/transaction/auth/idempotency decisions, commands/results, and residual deployment/provider risk.
