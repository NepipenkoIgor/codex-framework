---
name: caching-strategy
description: Implement caching patterns using Redis, node-cache, MemoryCache, CDN configuration, and HTTP cache headers for .NET, Node.js, or NestJS backends
metadata:
  version: 2.1
  argument-hint: "data type (user session/API response/computed data), cache layer (Redis/in-memory/CDN), TTL/eviction policy, invalidation strategy, backend framework"
---

Implement caching for $ARGUMENTS with appropriate patterns for the use case. Measure before caching — never cache speculatively.

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Cache Layer Selection

| Use case | Layer | Tool | TTL guidance |
|----------|-------|------|-------------|
| Repeated DB queries within request | Request-scoped | DataLoader, per-request Map | Request lifetime |
| Frequent reads, rare writes | Application cache | Redis, node-cache, MemoryCache | 1-60 min |
| Static assets, CDN | HTTP cache | Cache-Control headers, CDN | 1 year (immutable) |
| API responses | HTTP cache | ETag, Last-Modified, Cache-Control | 1-15 min |
| Computed/aggregated data | Background cache | Redis + background refresh | 5-60 min |
| Session data | Distributed cache | Redis, Memcached | 30 min idle, 24h absolute |
| Configuration | Long-lived cache | In-memory with file/env reload | Until changed |
| User permissions/roles | Application cache | Redis or in-memory | 5-15 min with event invalidation |
| Rate limit counters | Distributed cache | Redis | Window duration |

## Multi-Tier Caching (L1/L2/L3)

**L1 (in-process memory):** fastest (no serialization, no network); per-instance (inconsistency risk after writes); keep under 100MB to avoid GC pressure; .NET IMemoryCache, Node.js node-cache/lru-cache.

**L2 (distributed Redis):** shared across all instances; network hop + serialization overhead; best for session, shared state, frequently accessed entities; .NET IDistributedCache.

**L3 (CDN/edge):** closest to user; best for static assets, public API responses; invalidation via purge API or surrogate keys.

Multi-tier lookup: `L1 HIT → return | MISS → L2 HIT → populate L1 → return | MISS → Source → populate L2 (TTL) → populate L1 (shorter TTL) → return`. L1 TTL shorter than L2 (e.g., L1: 1min, L2: 10min). Invalidation must clear both L1 and L2; cross-instance L1 invalidation requires pub/sub or short TTL acceptance.

## Cache Patterns

**Cache-aside (lazy loading):** check cache → miss → load from source → store → return. Caller's responsibility. Best for read-heavy with brief staleness tolerance. Risk: thundering herd.

```typescript
// Cache-aside: redis.get(key) → hit: return parsed → miss: fetch() → redis.set(key, json, 'EX', ttl)
async function getUserById(id: string): Promise<User> {
  const cached = await redis.get(`user:${id}`);
  if (cached) return JSON.parse(cached);
  const user = await db.users.findById(id);
  if (user) await redis.set(`user:${id}`, JSON.stringify(user), 'EX', 300);
  return user;
}
```

**Read-through:** cache fetches from source on miss (CDN origin, cache wrappers). **Write-through:** write cache + source simultaneously (consistent, slower writes). **Write-behind:** write cache immediately, async flush to source (high throughput, data loss risk).

## Cache Invalidation Patterns

**TTL-based:** set expiry on every entry; simplest and least bug-prone; choose TTL by change frequency + staleness tolerance.

**Event-driven:** invalidate on write/update/delete; publish events (`cache.invalidate('user:123')`); use pub/sub for cross-instance. Fresher data, more complex.

**Tag-based:** tag entries with groups, invalidate all by tag: `cache.set(key, data, { tags: ['products'] })` then `cache.invalidateByTag('products')`.

**Version-based:** key includes version/hash; new version = new key; old expires via TTL. Good for assets, config.

**Selective/Cascade invalidation:** maintain dependency graph (entity → cache keys that include that entity); invalidate all dependent keys when entity changes.

```typescript
// Redis tag sets for dependency tracking
async function cacheWithDeps(key: string, data: any, deps: string[], ttl: number) {
  const pipeline = redis.pipeline();
  pipeline.set(key, JSON.stringify(data), 'EX', ttl);
  for (const dep of deps) {
    pipeline.sadd(`dep:${dep}`, key);
    pipeline.expire(`dep:${dep}`, ttl + 60);
  }
  await pipeline.exec();
}
async function invalidateEntity(entityKey: string) {
  const dependentKeys = await redis.smembers(`dep:${entityKey}`);
  if (dependentKeys.length > 0) await redis.del(...dependentKeys, `dep:${entityKey}`);
}
```

Cascade levels: single (entity → entity cache + list caches) | multi (parent → parent + children + aggregates) | bounded (max depth 2-3; deeper deps rely on TTL to prevent invalidation storms).

## Thundering Herd Prevention

### Mutex / Distributed Lock
First request acquires Redis SETNX lock (with TTL), fetches from source, populates cache. Others wait and retry. Lock TTL slightly longer than expected fetch time (10-30s). Limit retries to 3-5. Combine with stale-while-revalidate for very hot keys.

```typescript
// getWithLock: redis.set(lockKey, '1', 'EX', 10, 'NX') → acquired: fetch + cache → not acquired: sleep(100) + retry
```

### Probabilistic Early Expiration (XFetch)
Random chance of refresh before TTL expires; probability increases as expiry approaches. No coordination needed — eliminates exact-moment stampede.

```typescript
// shouldRefresh(storedAt, ttl, beta=1.0): return Math.random() < Math.exp(-remaining / (ttl * beta))
// beta: 0.5=conservative (near expiry), 2.0=aggressive (early refresh)
```

### Request Coalescing (Single-Flight)
Multiple concurrent requests for same key → collapse into single source fetch; others await the same Promise.

```typescript
const inFlight = new Map<string, Promise<any>>();
// getCoalesced: if inFlight.has(key) → return inFlight.get(key); else inFlight.set(key, loader().then(cache+cleanup))
```
Best for same-instance dedup. For distributed: combine with distributed lock. Go: `golang.org/x/sync/singleflight`.

Strategy selection: moderate traffic, single hot key → mutex | very high traffic, many hot keys → XFetch | same-instance concurrent requests → coalescing | extreme load on critical keys → coalescing + XFetch + stale fallback.

**Stale-while-revalidate:** serve stale immediately, trigger background refresh. After soft-expiry: stale + async refresh. After hard-expiry: block and fetch. HTTP: `Cache-Control: max-age=60, stale-while-revalidate=300`.

## Cache Warming

Strategies: **startup** (pre-populate top-N accessed entities as background task on app start) | **scheduled** (cron job refreshes before TTL expires; distributed lock to prevent parallel warming) | **predictive** (based on user behavior: open list → warm details; login → warm permissions).

**Warm on deploy:** background job fetches top-N accessed keys from `cache_access_log` (last 1 hour, top 500), batches in groups of 50. Use distributed lock so only one instance warms. Don't block readiness probe.

**SWR with two TTLs:** soft TTL triggers background refresh while serving stale; hard TTL forces blocking fetch. Store `{ data, storedAt }` in Redis hash (`swr:${key}`).

**Warm from read replica:** connect warming job to read replica to avoid adding load to primary; acceptable staleness = replication lag (<1s sync, <10s async).

## HTTP Caching

Cache-Control by content type: hashed assets → `public, max-age=31536000, immutable` | images/fonts → `public, max-age=86400` | public API lists → `public, max-age=60, stale-while-revalidate=300` | authenticated API → `private, max-age=0, must-revalidate` | sensitive data → `no-store` | HTML pages → `no-cache`.

ETag: generate from content hash or last-modified; return 304 on match (If-None-Match/If-Modified-Since); use weak ETags (`W/"..."`) for semantic equivalence.

Vary: `Vary: Accept-Encoding` (compressed) | `Vary: Authorization` (prevent cross-user sharing) | `Vary: Accept-Language` (localized). Incorrect Vary causes cache pollution.

## Redis Implementation

Key design: prefix for namespacing (`cache:users:123`); include all query params; hash complex keys (`sha256(queryParams)`); TTL on every key.

Operations: SETNX for locks; pipeline/MULTI for batches; SCAN (not KEYS) in production; HSET for structured data; sorted sets for time-based expiry.

Eviction policies: `allkeys-lru` (general-purpose, safe default) | `allkeys-lfu` (hot/cold separation, read-heavy) | `volatile-lru` (mixed cache + persistent) | `volatile-ttl` (time-sensitive). Set `maxmemory` at 70-80% RAM. High evictions = undersized cache.

Monitoring: track hit rate (>90%), miss rate (<10%), P99 latency (<5ms), eviction rate (~0), memory (<80% maxmemory), connection count (stable), key count (bounded growth). Wrap operations with metrics: latency per get/set, hit/miss counters, expose via Prometheus/OpenTelemetry.

## Framework-Specific Implementation

**.NET:** IMemoryCache (L1), IDistributedCache + Redis (L2), OutputCache (.NET 7+) for HTTP.
```csharp
// cache.GetOrCreateAsync(key, async entry => { entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5); return await fetch(); })
```

**Node.js / NestJS:** `lru-cache` (L1, actively maintained TypeScript-native; prefer over `node-cache` which is unmaintained), `ioredis` (L2). NestJS: use `@nestjs/cache-manager`; `CacheInterceptor` or inject `CACHE_MANAGER` directly. `@Cacheable()` is not built-in.

**Next.js (4 layers):**
```typescript
// Request dedup: export const getUser = cache(async (id) => db.users.findUnique({ where: { id } }))
// fetch: { cache: 'force-cache' } (SSG) | { cache: 'no-store' } (fresh) | { next: { revalidate: 60 } } (ISR) | { next: { tags: ['products'] } }
// unstable_cache for non-fetch: getCachedData = unstable_cache(fn, ['key'], { revalidate: 300, tags: ['products'] })
// Invalidation: revalidateTag('products') | revalidatePath('/products') | revalidatePath('/dashboard', 'layout')
```

Decision: static content → `revalidate: 3600` or `force-cache` | product listings → ISR `revalidate: 300` + `revalidateTag` on update | user-specific → `cache: 'no-store'` | dashboard aggregates → `unstable_cache` + tag.

**Angular:** `HttpInterceptorFn` for response caching; `TransferState` for SSR hydration (prevents re-fetch on client); signal-based cache map in singleton services.

**Vue/Nuxt:**
```typescript
// useAsyncData with getCachedData for SWR pattern
// routeRules: { '/products/**': { swr: 300 }, '/blog/**': { isr: 3600 } }
// Invalidation: clearNuxtData('products') | refreshNuxtData('products')
```

**SvelteKit:** `setHeaders({ 'Cache-Control': 'public, max-age=60, stale-while-revalidate=300' })` in `+page.server.ts`; `depends('app:products')` + `invalidate('app:products')` for fine-grained control; server-side in-memory Map with TTL in a server module.

**Blazor:** `IMemoryCache.GetOrCreateAsync` (L1), `IDistributedCache` with Redis (L2), `OutputCache` middleware (.NET 7+). For .NET 9+ authenticated routes: use `VaryByValue` with userId to prevent cross-user cache sharing.

## Anti-Patterns

Cache key missing query params — different inputs return same cached response | caching errors without short TTL (single backend failure → prolonged outage) | identical TTL on all keys (synchronized expiration → thundering herd) | user-specific data in shared CDN without `Vary` header (cross-user data leaks) | `KEYS` in production Redis (O(n), blocks instance).

## Implementation Workflow

1. Measure bottleneck (latency, query count, throughput)
2. Select layer (L1/L2/L3), pattern, key design
3. Choose invalidation, add herd protection for hot keys
4. Add monitoring, test invalidation correctness

## Output Format

```
Cache Target:      [what data is cached]
Layer:             [L1 / L2 / L3 / multi-tier]
Pattern:           [cache-aside / read-through / write-through / write-behind]
TTL:               [expiration and rationale]
Invalidation:      [TTL / event-driven / tag-based / version-based]
Herd Protection:   [mutex / PER / stale-while-revalidate / none]
Key Design:        [key pattern with parameters]
Monitoring:        [metrics tracked]
Warming:           [startup / scheduled / predictive / none]
```

## Done Criteria

- Measurable latency/load reduction, no stale data bugs
- TTL on all entries, deterministic keys with all params, explicit invalidation tested
- Monitoring in place (hit/miss rate, latency, evictions), herd protection for hot keys
- Memory bounded with eviction policy
