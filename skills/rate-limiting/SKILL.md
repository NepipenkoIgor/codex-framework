---
name: rate-limiting
description: Design and architecture for API rate limiting — algorithm selection, key patterns, storage decisions, and SaaS tier structures
metadata:
  version: 1.4
  argument-hint: "requirements (per-user/per-tenant), traffic pattern, SaaS tiers if applicable"
---

Design rate limiting for $ARGUMENTS using appropriate algorithms and architecture patterns.

## Algorithm Selection

| Algorithm | How it works | Best for | Drawback |
|-----------|-------------|----------|----------|
| Fixed Window | Count per fixed time window | Simple quotas, dashboard display | Burst at window boundary (2x) |
| Sliding Window Log | Track timestamps, count within window | Precise limiting, audit trail | Memory-heavy for high-volume |
| Sliding Window Counter | Weighted current + previous window | Balance of precision and efficiency | ~0.003% approximation error |
| Token Bucket | Tokens refill at fixed rate | Bursty traffic with sustained rate | Allows initial burst up to capacity |
| Leaky Bucket | Queue at fixed output rate | Smoothing traffic, constant rate | Delays instead of rejects |

### Decision Guide

- Simple per-user quota (100 req/min) -> **Sliding Window Counter** (efficient, accurate)
- Allow short bursts, enforce sustained rate -> **Token Bucket**
- Strict constant-rate processing (payment webhooks) -> **Leaky Bucket**
- Quick implementation, low traffic -> **Fixed Window**
- Audit trail needed -> **Sliding Window Log**

## Storage Architecture

| Storage | Deployment | Trade-off |
|---------|-----------|----------|
| Redis (distributed) | Multi-instance, replicated | Atomic operations, distributed coordination |
| In-memory (single instance) | Development, single pod | Simplicity, no external dependency; no cross-instance sync |
| Database (audit-required) | Compliance, historical tracking | Slow, suitable for low-volume audit logging |

## Key Design Patterns

Essential principles for rate limit key design:

- **Dimensions:** Include all relevant: user ID, tenant ID, endpoint, IP
- **Format:** Consistent, predictable: `rl:user:{userId}:endpoint:{path}:rpm`
- **TTL:** Set on every key, minimum 2x window duration to prevent unbounded growth
- **Hashing:** For long keys, hash to fixed length to keep Redis memory bounded

## Rate Limit Response Headers

Every rate-limited endpoint must set on **every** response (not just 429):

| Header | Description |
|--------|-------------|
| `X-RateLimit-Limit` | Max requests in window |
| `X-RateLimit-Remaining` | Requests remaining |
| `X-RateLimit-Reset` | Unix timestamp when window resets |
| `Retry-After` | Seconds to wait (429 only) |

## SaaS Tier-Based Architecture

Multi-layer limiting structure:

```
Layer 1: Per-user per-minute (burst protection) — Token Bucket
Layer 2: Per-org per-day (daily quota) — Fixed Window
Layer 3: Monthly credit consumption — Database transaction
```

### Billing Tier Limits

| Tier | Req/min | Req/day | Credits/month |
|------|---------|---------|---------------|
| Free | 10 | 1,000 | 10,000 |
| Pro | 100 | 50,000 | 500,000 |
| Enterprise | 1,000 | 500,000 | 5,000,000 |

## Load Shedding Priority

When system is under load, shed in this order:

| Priority | Traffic type | Action |
|----------|-------------|--------|
| Critical | Health checks, auth, webhooks | Never shed |
| High | Authenticated requests | Third to shed |
| Normal | Public API, search | Second to shed |
| Low | Analytics, bulk exports | First to shed |

## Client-Side Retry Strategy

Clients must:
1. Check `Retry-After` header first (server's authoritative answer)
2. Implement exponential backoff with jitter (prevent thundering herd)
3. Cap retries at 3-5 attempts, max delay at 30-60 seconds

## Common Pitfalls to Avoid

1. **Race conditions:** Never GET-then-SET without atomicity (Lua scripts, transactions)
2. **Fixed window only:** Allows 2x burst at boundaries; use sliding window or token bucket
3. **No tenant isolation:** One tenant's spike impacts others; key by tenant
4. **Failing closed on Redis down:** Design explicit fail-open or fail-closed policy
5. **Rate limiting health checks:** Breaks load balancer probes; skip health endpoints

## Anti-Patterns

- GET-then-SET without atomicity
- Fixed window only for distributed systems
- No per-tenant isolation
- No fallback when Redis is unavailable
- Rate limiting health check endpoints

## Implementation Workflow

1. Identify requirements: per-user, per-tenant, per-IP, per-endpoint
2. Select algorithm based on traffic pattern
3. Choose storage: Redis for distributed, in-memory for single-instance, DB for audit
4. Design key format with all relevant dimensions
5. Choose middleware/guard pattern for your framework
6. For SaaS: design multi-layer limits (burst, daily, monthly)
7. Plan client-side retry with exponential backoff + Retry-After

## Output Format

```
Algorithm:         [token bucket / sliding window / fixed window]
Storage:           [Redis / in-memory / database]
Dimensions:        [which dimensions key includes: user/tenant/endpoint/IP]
Key Pattern:       [rl:user:{id}:endpoint:{path}]
Limits:            [per-user, per-tenant, per-endpoint values]
Layers:            [1-minute burst, daily, monthly if SaaS]
Headers:           [X-RateLimit-Limit, Remaining, Reset, Retry-After]
Fallback:          [fail-open / fail-closed when storage unavailable]
Monitoring:        [which metrics to track and alert on]
```

## Architecture Done Criteria

- Algorithm matches traffic pattern (bursty vs sustained)
- Key design includes all relevant dimensions with consistent format
- Storage choice justified (Redis for distributed, in-memory for single, DB for audit)
- TTL strategy prevents unbounded growth
- Multi-layer limits configured for SaaS tiers (if applicable)
- Client retry strategy documented (exponential backoff + Retry-After)
- Fallback behavior defined when storage is unavailable
- Load shedding priorities assigned to traffic types

> For extended implementation patterns, ask to invoke `/rate-limiting-implement` on demand.
