---
name: serverless-patterns
description: Implement serverless handlers, event triggers, configuration, and deployment behavior using the repository's pinned provider and runtime capability. Use when repository changes are explicitly requested; do not use for provider selection/design-only or incident diagnosis without implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.3
  argument-hint: "provider, pinned runtime/tooling, trigger semantics, latency/concurrency/timeout/cost and deployment constraints"
---

# Serverless Patterns

Implement `$ARGUMENTS` in the existing repository.

## Establish installed and provider capability

1. Read instructions, manifests/lockfiles, IaC/deployment config, provider account/region/stage, runtime pins, trigger schema, IAM/service identities, nearby handlers/tests, and authoritative deployment commands.
2. Generate stack context and verify provider limits, runtime lifecycle, event source retry/batch semantics, response format, and IaC syntax from matching official documentation and installed schemas/CLI help. Never copy remembered duration, memory, concurrency, cold-start, or edge-runtime limits.
3. Preserve pins and deployed compatibility. Runtime/provider/IaC upgrades are separate migrations.

## Handler correctness

- Authenticate and authorize HTTP callers and validate all untrusted event fields; trigger authenticity alone may not authorize the referenced tenant/resource.
- Assume asynchronous/event-source delivery is at least once unless the exact provider contract proves otherwise. Use stable event/operation identity, atomic claim or transactional state transition, and idempotent effects.
- Handle timeout-after-success: an external effect or database commit can succeed before acknowledgement. Persist/reconcile outcome before retrying rather than assuming timeout means failure.
- For batches, use the exact partial-failure contract exposed by the pinned event source/runtime; avoid replaying successful items when supported and make every item independently safe.
- Bound retries/backoff, poison handling/DLQ or destination, concurrency, downstream connections, payload size, memory, duration, and cancellation. Define replay/redrive authorization and dedupe retention.
- Reuse clients only when the runtime and library make it safe; never leak request, tenant, credential, or mutable state across warm invocations.

## Performance and operations

Measure cold and warm paths in the deployed-like runtime before optimizing. Cold-start budgets and provisioned/warm strategies are workload/provider decisions, not fixed thresholds. Minimize initialization and package size only when evidence shows impact.

Use least-privilege identities, secret stores, structured redacted logs, correlation/event IDs, duration/throttle/concurrency/age/DLQ metrics, cost controls, staged rollout and rollback. Do not mutate production provider state unless explicitly authorized.

## Verification and output

Test exact provider event fixtures, malformed/unauthorized/wrong-tenant input, duplicate and concurrent delivery, timeout-after-effect, partial batches, downstream throttling, cold/warm state leakage, retry exhaustion/redrive, and deployed configuration compatibility. Local emulators are useful but not provider proof.

Report installed provider/runtime/IaC pins, triggers and guarantees, auth/resource checks, idempotency/reconciliation, limits/concurrency/retry/DLQ, cold/warm evidence, commands/results, deployed paths verified, and residual provider risk.
