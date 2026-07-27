---
name: backend-implement
description: Implement backend behavior when no sharper language or framework specialization owns the task, preserving repository contracts, validation, persistence, auth, reliability, observability, documentation, and tests. Use for genuinely generic server work; route Node, NestJS, Python, or .NET-dominant tasks to their specialization.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.1
  argument-hint: "feature/acceptance, runtime/framework, API/event and persistence contracts, auth/tenant and failure model"
---

# Backend Implement

## Route first

Use `backend-implement-node`, `backend-implement-nestjs`, `backend-implement-python`, or `backend-implement-dotnet` when that runtime/framework dominates. Use this generic skill only when no sharper specialization applies or the change is framework-neutral. Testing-only work routes to `backend-test` or its specialization.

## Workflow

1. Read instructions, manifests/lockfiles/runtime files, target and callers, API/event schemas, validation/errors, persistence/migrations, auth/tenant model, jobs/providers, telemetry, tests and deployment commands.
2. Generate stack context and preserve repository runtime/framework/language/package manager and installed capability. Do not choose a framework, validator, ORM, logger, architecture or latest version by default.
3. Define caller-visible success/error behavior and durable invariants across invalid input, authentication, target-resource authorization, duplicate/concurrent mutation, conflict, retry, cancellation and timeout-after-effect.
4. Implement the smallest vertical change with existing boundaries and update authoritative schemas/docs when contracts change.

## Invariants

- Validate untrusted transport/event/provider/config data at the boundary; enforce domain/database constraints where authority lives.
- Authenticate and authorize actor, tenant and target resource server-side. Client fields, claims without current ownership and UI gating are insufficient.
- Define transaction/concurrency boundaries and stable server-side idempotency for consequential retryable work. Reconcile ambiguous timeout after commit/effect.
- Bound payloads, queries, files, downstream timeout/retry, queues and concurrency. Derive automated retry attempts and total elapsed time from operation/provider semantics, request/job deadlines and observed recovery evidence; persist an unresolved state after exhaustion rather than inventing constants. Propagate cancellation only through supported APIs.
- Preserve public error compatibility and structured redacted telemetry; never expose secrets, stack traces, provider or database internals.

## Verification

Run focused and affected repository checks. Exercise invalid/401/resource-tenant 403, duplicate/concurrent calls, conflict, rollback, cancellation and timeout-after-effect as relevant. Verify response plus persisted/effect outcome; command success alone is not proof.

Report specialization decision, installed capability, contracts/files/migrations changed, checks/results and unverified provider/deployment risk.
