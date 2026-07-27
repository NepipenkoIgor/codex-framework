---
name: caching-strategy
description: Implement measured caching and HTTP freshness behavior with explicit authorization, tenant partitioning, invalidation, stampede, dependency-failure, and stale-data semantics. Use when repository cache changes are requested; do not use for diagnosis-only or generic distributed locking.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.2
  argument-hint: "measured source bottleneck, data sensitivity/ownership, freshness budget, invalidation and failure model, installed cache layers"
---

# Caching Strategy

1. Measure the source latency/load and identify the exact read contract, owners, sensitivity, tenant/resource scope, consistency and maximum tolerated staleness. Do not cache speculatively.
2. Read instructions, manifests/lockfiles, installed framework/cache/CDN capability, auth path, data mutations, deployments and tests. Generate stack context before version-sensitive APIs; preserve pins.
3. Choose request coalescing, in-process, distributed, database/materialized, HTTP/browser or CDN caching only where its failure and consistency model fits.

## Correctness and security

- Derive keys from canonical server-side actor/tenant/resource authorization context plus every representation-changing input. Never key shared protected data by raw bearer token, cookie, API secret or attacker-controlled string; hash only non-secret canonical components when length/privacy requires it.
- A cache hit never bypasses current authorization, revocation, account/tenant status or resource ownership checks. Public, private and shared caches need explicit `Cache-Control` and `Vary` semantics.
- Define source of truth, freshness budget, negative/error caching, invalidation triggers, write race behavior, cross-instance propagation, deployment/schema/version keys and recovery after missed invalidation.
- Protect hot misses with bounded single-flight, lock/lease, early refresh, stale-while-revalidate or admission policy as appropriate. Define lock ownership/expiry and source outage behavior; no fixed TTL/retry/memory/hit-rate threshold is universal.
- Define fail-open stale serve, fail-closed, source fallback, or load shedding per data consequence. Security/permission data usually needs stricter revocation semantics than public content.

## Verification

Test cross-user/tenant cache poisoning, authorization revocation on hit, representation variants, concurrent cold misses, write/invalidation races, stale and hard expiry, source/cache timeout/partition, eviction/restart/deploy version change, negative/error recovery and bounded memory/cardinality. Compare caller-visible freshness and source load before/after.

Report measurement, layer/key/partition, freshness/invalidation/stampede/failure contracts, auth/privacy handling, rollout/rollback, metrics, commands/results and residual stale-data risk.
