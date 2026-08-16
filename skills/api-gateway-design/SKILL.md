---
name: api-gateway-design
description: Design an API gateway or backend-for-frontend trust boundary across routing, authenticated identity propagation, authorization, aggregation, cache partitioning, resource controls, and upstream isolation. Use when edge topology or cross-service policy is the requested design; do not use for endpoint schema design, rate limiting alone, or routine proxy configuration.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.1
  argument-hint: "clients, exposed routes, trust boundaries, identity, upstreams, aggregation, cache, failure policy"
---

# API Gateway and BFF Design

Design `$ARGUMENTS` from the deployed trust and request paths rather than from a preferred gateway product.

## Workflow

1. Inspect repository and infrastructure instructions, gateway/proxy configuration, public and internal ingress, DNS/load balancers, service discovery, auth issuers, route inventories, API contracts, cache/CDN layers, observability, and deployment topology. Identify every path that can reach an upstream, including service, pod, private load balancer, webhook, admin, and debug routes; stop when any relevant ingress or reachability path remains unknown. Generate project stack context and treat deployed gateway/runtime pins, generated configuration schema, plugin inventory, release-matched validator and matching official documentation as capability authority; adopting behavior from a newer line is a separate migration.
2. Define gateway ownership and exclusions: routing and policy enforcement at the edge; domain authorization and invariants remain with the owning service. Endpoint request/response schema design belongs to the endpoint/API owner, and quota-algorithm design belongs to the rate-limiting/capacity owner; the gateway consumes their versioned contracts and may enforce them, but must not silently invent or redefine either. Decide whether a BFF is justified by a distinct client contract, server-held token/session boundary, or aggregation need—not by a universal per-client rule.
3. Establish identity provenance. Strip all caller-supplied identity, role, tenant, scope, forwarding, and internal-auth headers before writing gateway-derived values. Bind propagated identity cryptographically or through an authenticated network/workload channel; upstreams must reject direct or unverifiable identity injection.
4. Apply authentication at the appropriate edge and authorize exact operation/resource/tenant in trusted upstream code. A validated token or gateway-injected header is not object- or function-level authorization. Public and bypass routes are explicit, narrowly matched, reviewed, and tested.
5. Define deterministic route precedence, method/host/path matching, rewrite behavior, request/body/header limits, timeout/deadline budgets, retry eligibility, and drain/failover behavior from upstream contracts. Reject ambiguous or shadowed routes before rollout.
6. For aggregation, authenticate once but authorize each upstream resource and field. Bound fan-out, concurrency, response size, and total deadline; define whether failure is atomic, partial, or stale. Never combine data for a caller merely because upstream calls succeeded.
7. Cache only when freshness, authorization, privacy, and invalidation contracts allow it. Partition keys by every representation and authorization dimension that affects the response; never use raw secrets as cache keys. Auth-sensitive or permission-changing responses default to uncacheable until proven safe.
8. Derive rate, concurrency, circuit, and load-shedding policies from measured capacity, dependency quotas, endpoint cost, tenant fairness, and abuse model. Assign breaker/bulkhead ownership to the layer that observes a coherent dependency and traffic population; avoid retry multiplication across hops.
9. Produce staged migration, shadow/diff or canary evidence, rollback, and direct-bypass closure plans. Verify externally and from every internal network path that the gateway cannot be bypassed for protected operations.

## Required counterexamples

- A request containing `X-User-Id` or tenant headers must not influence propagated identity before gateway authentication.
- An upstream reachable directly must reject forged gateway headers; network placement alone is not sufficient identity proof.
- Tenant or user data cannot share a cache entry merely by path or bearer token presence.
- An aggregated dashboard must authorize every order, account, and field and must not turn one upstream's partial failure into misleading success.
- Readiness must describe whether this instance can serve its own contract; making it fail whenever any optional upstream is degraded can create an avoidable cascading outage.
- Product defaults, plugin names, header conventions, timeouts, retry counts, thresholds, and cache TTLs are candidates only after installed capability and deployment evidence.

## Verification and output

Test forged and duplicate headers, missing/invalid/expired identity, object/function/tenant authorization, direct upstream access, route ambiguity, method mismatch, cache isolation and invalidation, aggregation fan-out/partial failure, oversized input, rate/concurrency limits, deadline propagation, retry multiplication, drain/failover, readiness, and observability correlation. Fault-inject an upstream outage with the configured circuit and bulkhead controls together; prove stale authorization or revocation never fails open, and prove tenant isolation and fair capacity remain intact while the dependency is degraded. Report topology and trust evidence, route/policy table, identity and bypass controls, aggregation/cache/failure contracts, capacity assumptions, staged rollout/rollback, checks performed, and residual direct-path or provider risk.

## Provenance

- OWASP API Security risks: https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- HTTP semantics, including cache and `Retry-After`: https://www.rfc-editor.org/rfc/rfc9110
