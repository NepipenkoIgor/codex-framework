---
name: rate-limiting
description: Design read-only admission control and quota enforcement across identities, tenants, endpoints, distributed instances, proxies, retries, and dependency failure. Use when rate-limit policy or architecture is unresolved; do not use for straightforward implementation of an approved design.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.5
  argument-hint: "protected resource, abuse model, trusted identity/proxy topology, tenant tiers/fairness, distribution and failure policy"
---

# Rate Limiting

Design `$ARGUMENTS` without changing code or infrastructure.

## Define policy before algorithm

1. Identify the resource/invariant being protected, abuse and accidental-burst model, legitimate concurrency, cost/fairness goals, scopes, exemptions, and caller recovery contract.
2. Establish trusted identity. Use authenticated user/service/API-key and tenant/resource relationships when available. Use source IP only after validating the exact trusted proxy chain and forwarded-header parsing; never trust arbitrary client-supplied forwarding headers.
3. Separate burst admission, sustained rate, concurrency, costly-operation budget, business quota, and global load shedding. They may need different enforcement points and semantics.
4. Choose fixed/sliding window, token/leaky bucket, concurrency semaphore, or provider-native limit from measured traffic and required precision. No algorithm or Redis is universal.
5. Stop before implementation when enforcement topology or measured traffic/capacity evidence is absent; do not claim the generic evaluation fixture supplies it. Once resolved, validate in shadow mode or a bounded canary before enforcing broadly, with caller-visible rollback triggers.

## Distributed correctness and fairness

- In multi-instance paths, decision and state update must be atomic at the selected consistency scope. Define clock source, TTL/eviction, replica/failover behavior, hot-key handling, partition semantics, and reconciliation; GET-then-SET is insufficient.
- Compose global, tenant, principal, route/resource and high-cost-operation budgets so one tenant or key cannot consume shared capacity unfairly. Avoid attacker-controlled high-cardinality keys and accidental double charging across retries.
- Define fail-open, fail-closed, degraded local allowance, or shed policy per traffic class from consequence and dependency risk. Health/auth/webhook exemptions are not universal; protect them with a separate availability/abuse contract.
- Rate limiting does not replace authentication, authorization, validation, billing enforcement, queue backpressure, or idempotency.

## Protocol and verification

- For HTTP, use the protocol/header contract supported by existing clients and gateways; `Retry-After` on 429 may be required by policy, while legacy `X-RateLimit-*` or standardized `RateLimit` fields must not be invented universally. State units, reset semantics and multi-policy behavior precisely.
- Define bounded client retry with jitter only for retryable operations, preserving stable operation identity for non-idempotent work.
- Verify boundary bursts, simultaneous distributed requests, tenant fairness, proxy spoofing, key cardinality, store timeout/partition/failover, clock skew, retries, exemptions, header semantics, and recovery. Load-test at the real enforcement boundary.
- Before shadow or canary activation, define privacy-safe decision/allow/deny/error/latency/store-saturation and fairness signals, logs/traces, dashboards, alert thresholds, review cadence, and an accountable responder with an executable rollback/disable path. Each rollout trigger must map to an observed signal and owned response; metric names alone are not an operational monitoring plan.

## Output

Report protected resource and identities, exact enforcement point/topology, policy layers and fairness, algorithm/state/atomicity, proxy trust, failure and load-shed behavior, response/retry contract, observability/privacy, executable tests, rollout/rollback, and residual risk. If the enforcement point/topology or measured traffic/capacity evidence is unresolved, list each as an explicit blocking input and do not present the design as implementable. Assign an accountable fallback/operations owner and concrete pre-implementation stop conditions plus measurable rollback triggers for store saturation/partition, authorization or idempotency regression, tenant unfairness and caller-visible error harm.
