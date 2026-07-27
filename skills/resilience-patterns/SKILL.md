---
name: resilience-patterns
description: Implement dependency resilience through deadlines, retry, rate/concurrency limiting, circuit breaking, bulkheads, fallback, and hedging with explicit side-effect and ownership semantics. Use when a concrete call path must tolerate transient failure; do not use for queue delivery, distributed locks, or broad architecture design.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "call path, operation semantics, dependency contract, latency/error evidence, resource owner, fallback policy"
---

# Resilience Patterns

Implement `$ARGUMENTS` from observed failure modes and end-to-end budgets rather than a universal middleware stack.

## Workflow

1. Inspect manifests/lockfiles, installed resilience/client libraries and client runtime, call graph, operation semantics, provider SLA/quotas, timeout and cancellation propagation, existing retries at every hop, connection/thread/pool limits, health checks, telemetry, and tests. Preserve pins; verify APIs and default predicates/order against installed types/config and matching versioned official documentation, and record the exact package/runtime version plus source used for the capability decision.
2. Classify each operation as safe/idempotent, conditionally repeatable through a durable idempotency key, or non-repeatable. Record ambiguous outcomes and reconciliation. Never retry or hedge a side effect merely because its transport failed.
3. Allocate one caller-visible deadline across queueing, attempts, backoff, connection, response, and cleanup. Propagate cancellation/deadline where supported and stop work after caller abandonment when safe. A timeout bounds waiting; it does not prove the dependency canceled the operation.
4. Retry only errors proven transient for this operation. Bound attempts and total elapsed time, add desynchronization, and honor valid provider guidance. HTTP `Retry-After` can be either an HTTP-date or delay-seconds; parse both, account for clock skew, cap by remaining deadline/policy, and reject malformed or absurd values safely.
5. Place a circuit breaker around the dependency and operation population whose failures it measures. Exclude caller/validation/business errors unless the dependency contract says otherwise. Half-open probes are bounded and must not be harmful writes.
6. Place bulkhead/rate/concurrency ownership where scarce resources are actually consumed. Size from measured concurrency, pool capacity, dependency quotas, latency, and load tests. Avoid duplicate layers that multiply queues, obscure overload, or starve unrelated tenants/operations.
7. Choose composition order from semantics: decide whether the breaker observes attempts or whole calls, whether timeout is per-attempt or total, and which layer owns queue time. Do not copy a universal order from a different library.
8. Fallback must preserve authorization, tenant, freshness, schema, and safety. Stale/default/alternate-provider responses are explicit product policy and observable; never turn a failed charge or permission lookup into success.
9. Separate liveness from readiness and dependency health. An optional downstream circuit opening should not automatically remove every healthy caller instance and cause a cascade; readiness reflects whether this instance can serve its required contract.
10. Verify with deterministic fault injection: non-idempotent ambiguous result, `Retry-After` date and seconds, malformed guidance, retry storm, deadline exhaustion, half-open concurrency, breaker window behavior, bulkhead saturation/fairness, fallback authorization/freshness, health coupling, shutdown, and recovery after each fault. Prove the dependency/circuit returns to healthy service without stale or unauthorized fallback leakage.

## Required counterexamples

- A timed-out POST that may have charged cannot be retried without operation identity and reconciliation.
- `Retry-After` is not always an integer; an HTTP-date must be parsed against a controlled clock and remaining deadline.
- Breaker and bulkhead scope must follow dependency/resource ownership, not one global singleton or one instance per request.
- Marking all instances unready because an optional downstream is open can amplify the outage.
- Library defaults, retryable status sets, pipeline order, attempt counts, thresholds, timeouts, and concurrency limits are version- and workload-dependent candidates.

## Output

Report installed capability and call-path evidence, operation repeatability, deadline budget, retry classification/provider guidance, breaker and bulkhead ownership, composition and fallback policy, health behavior, fault-injection results, telemetry, and unresolved ambiguous side effects or production-load risk.

## Provenance

- HTTP `Retry-After` semantics: https://www.rfc-editor.org/rfc/rfc9110#section-10.2.3
- .NET resilience guidance and unsafe-method retry warning: https://learn.microsoft.com/en-us/dotnet/core/resilience/http-resilience
