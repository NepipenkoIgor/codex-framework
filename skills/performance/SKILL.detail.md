# performance — Extended Patterns (detail file)
# Load on demand — not injected by default

Query optimization:

- Detect N+1 query patterns; batch or join related data
- Add missing indexes based on query plans (EXPLAIN/EXPLAIN ANALYZE)

Example -- detecting and fixing an N+1 query in EF Core:

```csharp
// BAD: N+1 -- executes 1 query for orders + N queries for customer names
var orders = await db.Orders.ToListAsync();
foreach (var order in orders)
{
    var customer = await db.Customers.FindAsync(order.CustomerId);
    order.CustomerName = customer.Name; // N extra queries
}

// GOOD: single query with projection -- no N+1, no entity tracking overhead
var orders = await db.Orders
    .AsNoTracking()
    .Select(o => new OrderListDto
    {
        Id = o.Id,
        Total = o.Total,
        Status = o.Status,
        CustomerName = o.Customer.Name, // translated to JOIN
        CreatedAt = o.CreatedAt,
    })
    .OrderByDescending(o => o.CreatedAt)
    .Take(50)
    .ToListAsync();
```

Example -- same pattern in Prisma (Node.js):

```typescript
// BAD: N+1 -- fetches orders then loops to fetch each customer
const orders = await prisma.order.findMany();
for (const order of orders) {
  order.customer = await prisma.customer.findUnique({ where: { id: order.customerId } });
}

// GOOD: single query with include
const orders = await prisma.order.findMany({
  include: { customer: { select: { name: true } } },
  orderBy: { createdAt: 'desc' },
  take: 50,
});
```
- Use projection to select only needed columns
- Avoid loading full entity graphs when partial data suffices
- .NET EF Core: use AsNoTracking for reads, explicit Includes, compiled queries for hot paths
- TypeORM: use QueryBuilder with select, optimize relations loading
- Monitor slow query logs; set query timeout budgets

Connection and resource management:

- Configure connection pooling for workload; avoid connection leaks
- .NET: verify DbContext scoping and disposal; Node.js: verify pool config and connection release
- Monitor active connections under load

Caching strategies:

- In-memory caching for hot, stable, bounded datasets
- Distributed cache (Redis) for shared state across instances
- HTTP caching with proper Cache-Control, ETag, Last-Modified headers
- Cache invalidation strategy; prefer TTL with event-based bust over manual purge
- Avoid caching unbounded or user-specific data without eviction policy

Async and parallel execution:

- Parallelize independent I/O operations
- .NET: Task.WhenAll for independent async work; avoid await in loops
- Node.js: Promise.all for independent async calls; avoid sequential awaits
- Avoid blocking the event loop (Node.js) or thread pool starvation (.NET)
- Use streaming for large payloads instead of buffering

Memory profiling:

- .NET: dotnet-counters, dotnet-dump, Visual Studio diagnostics; check LOH pressure, gen2 collections
- Node.js: --inspect with Chrome DevTools heap snapshots; check growing object counts
- Identify allocation-heavy hot paths; check for static/singleton caches growing without bounds

Response optimization:

- Paginate all list endpoints; no unbounded result sets
- Use cursor-based pagination for large or real-time datasets
- Apply field projection; return only what the client needs
- Enable response compression (gzip/brotli)
- Minimize serialization overhead; avoid serializing navigation properties or circular graphs

General methodology:

Profiling tools by context:

- Browser: Chrome DevTools Performance/Memory/Network/Lighthouse
- Angular: Angular DevTools, source-map-explorer
- React: React DevTools Profiler, why-did-you-render
- Vue: Vue DevTools performance tab
- .NET: dotnet-trace, dotnet-counters, BenchmarkDotNet, MiniProfiler
- Node.js: clinic.js, autocannon, 0x flame graphs
- Database: EXPLAIN plans, pg_stat_statements, slow query logs

Performance budgets:

- Define measurable targets before optimizing (e.g., LCP under 2.5s, API p95 under 200ms, bundle under 200KB)
- Track budgets in CI when possible; prioritize optimizations by user impact, not code elegance

Benchmark design:

- Measure baseline before any change; control variables; test one change at a time
- Use realistic data volumes and concurrency; run multiple iterations
- Compare p50, p95, p99 -- not just averages

Common anti-patterns:

- Premature memoization without measured need
- Caching everything without eviction or invalidation
- Over-fetching then filtering in application code
- Synchronous computation blocking async pipelines
- Rendering invisible content (offscreen lists, hidden tabs)
- Multiple sequential API calls that could be parallelized or batched
- Logging or serialization in hot paths
- Unbounded in-memory collections

Framework-specific patterns:

- Angular: prefer signals and computed over RxJS chains for derived state; OnPush + trackBy; defer blocks for lazy content
- React: avoid re-render cascades from context; split providers; use React Compiler when available; avoid defensive useMemo/useCallback
- Vue: shallowRef for large objects; computed over watchers; v-once for static subtrees
- Next.js: leverage RSC and streaming; avoid client-side fetching for initial data; use ISR/SSG where appropriate

Next.js performance patterns:

Bundle analysis with @next/bundle-analyzer:

```javascript
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});
module.exports = withBundleAnalyzer({ /* next config */ });
// Run: ANALYZE=true npm run build
```

React Server Components — reducing client JS:
- Default to Server Components; only add 'use client' for interactivity
- Server Components send zero JS to the client — HTML only
- Move data fetching, heavy transforms, and large dependencies to Server Components
- Audit 'use client' boundaries: push them to leaves, not page level

Dynamic imports with next/dynamic:

```tsx
import dynamic from 'next/dynamic';

// Lazy-load heavy component — excluded from initial bundle
const HeavyChart = dynamic(() => import('@/components/HeavyChart'), {
  loading: () => <ChartSkeleton />,
  ssr: false,  // skip SSR for browser-only components (canvas, WebGL)
});
```

Image optimization with next/image:

```tsx
import Image from 'next/image';

// Always set width/height or fill to prevent CLS
<Image
  src="/hero.jpg"
  alt="Hero"
  width={1200}
  height={600}
  priority          // above-the-fold: preload, skip lazy loading
  sizes="(max-width: 768px) 100vw, 50vw"  // responsive sizing
  placeholder="blur"
  blurDataURL={blurHash}
/>
```

Key rules: always set `sizes` for responsive images; use `priority` only for LCP image; use `fill` with `object-fit` for unknown dimensions.

Font optimization with next/font:

```tsx
// app/layout.tsx — zero-layout-shift fonts
import { Inter } from 'next/font/google';

const inter = Inter({ subsets: ['latin'], display: 'swap' });

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html className={inter.className}><body>{children}</body></html>;
}
```

Streaming with Suspense boundaries:

```tsx
// app/dashboard/page.tsx — stream slow data independently
import { Suspense } from 'react';

export default function DashboardPage() {
  return (
    <div>
      <h1>Dashboard</h1>
      <Suspense fallback={<StatsSkeleton />}>
        <SlowStats />    {/* streams in when ready */}
      </Suspense>
      <Suspense fallback={<FeedSkeleton />}>
        <ActivityFeed />  {/* streams independently */}
      </Suspense>
    </div>
  );
}
```

Wrap each independent async Server Component in its own Suspense boundary. The shell renders instantly; slow sections stream in as they resolve.
- .NET: minimize allocations in hot paths; use Span/Memory for buffer operations; pool objects when justified
- Node.js: avoid blocking the event loop; use worker threads for CPU-bound work; stream large responses

Output requirements:

- Start with the measured symptom and suspected bottleneck category
- Show profiling evidence or explain what to measure if data is missing
- Explain the root cause before applying optimizations
- Produce concrete production-ready code changes
- Include before/after measurement guidance
- Follow the idioms of the detected framework
- Prefer targeted fixes over broad rewrites

Profiling workflows:

Browser profiling (Chrome DevTools):
- Performance tab: record user interaction, identify long tasks (>50ms), check main thread blocking
- Look for: layout thrashing (forced reflows), excessive paint, JavaScript execution time
- Memory tab: take heap snapshots before/after interaction, compare to find leaked objects
- Network tab: check waterfall for sequential requests, large payloads, missing compression
- Lighthouse: run in incognito with no extensions for clean Core Web Vitals baseline
- Coverage tab: identify unused CSS and JavaScript — candidates for code splitting

Bundle analysis:
- webpack: webpack-bundle-analyzer or source-map-explorer
- Vite: rollup-plugin-visualizer
- Next.js: @next/bundle-analyzer
- Angular: source-map-explorer on main bundle
- Look for: duplicate dependencies, oversized packages, unused code, heavy polyfills
- Target: main bundle <200KB gzipped; lazy-loaded chunks <50KB each

.NET profiling:
- dotnet-counters: real-time CPU, memory, GC, thread pool, request rate counters
- dotnet-trace: collect detailed trace for offline analysis in Perfview or Speedscope
- dotnet-dump: capture and analyze heap dumps for memory leak investigation
- BenchmarkDotNet: microbenchmark hot paths with statistical rigor
- MiniProfiler: attach to ASP.NET requests to see SQL queries, timings, and allocation per request
- Visual Studio Diagnostics: CPU Usage, Memory Usage, and Database tools for local debugging
- Workflow: counters first (identify category) → trace (identify hot path) → benchmark (validate fix)

Node.js profiling:
- clinic.js: doctor (detect event loop delays), flame (CPU flamegraph), bubbleprof (async bottlenecks)
- autocannon: HTTP load testing with latency percentiles
- 0x: flamegraph generation from V8 profiler output
- --inspect + Chrome DevTools: CPU profile and heap snapshot
- node --prof: generate V8 profiler output for tick-processor analysis
- Workflow: autocannon baseline → clinic doctor → flame/0x for CPU → heap snapshot for memory

Database query profiling:
- PostgreSQL: EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) on slow queries
- Look for: Seq Scan on large tables (missing index), Nested Loop with high row count (N+1), Hash Join spilling to disk
- pg_stat_statements: find top queries by total_exec_time, calls, mean_exec_time
- SQL Server: SET STATISTICS IO ON, Actual Execution Plan, Query Store for regression detection
- MySQL: EXPLAIN FORMAT=JSON, slow_query_log, Performance Schema
- Monitor: query count per request, total query time per request, connection pool utilization

Load testing patterns:
- Define test scenarios matching real user behavior (not just hammering one endpoint)
- Ramp up gradually: 10 → 50 → 100 → 500 concurrent users over 5-10 minutes
- Measure at percentiles: p50, p95, p99 — averages hide tail latency
- Test with realistic data volume — empty databases don't reveal real performance
- Run soak tests (sustained load for 30-60 min) to detect memory leaks and resource exhaustion
- Tools: k6 (scripted scenarios), autocannon (simple HTTP), Artillery (YAML config), wrk (raw throughput)
- Establish performance regression baseline: run load tests in CI against staging

Optimization decision framework:
- Step 1: Is it actually slow? Measure before assuming — user perception ≠ system metric
- Step 2: Where is it slow? Profile to identify the bottleneck layer (network, CPU, I/O, rendering)
- Step 3: Why is it slow? Understand the root cause before applying a fix
- Step 4: What is the simplest fix? Prefer algorithmic improvements over caching, caching over parallelism, parallelism over rewrites
- Step 5: Did it help? Measure again — same workload, same conditions, compare percentiles

Common optimization priorities by impact:
1. Missing database index on frequently queried column → add index (huge impact, zero risk)
2. N+1 query pattern → batch load or join (large impact, low risk)
3. Unbounded list endpoint → add pagination (large impact, low risk)
4. Sequential independent I/O → parallelize with Promise.all / Task.WhenAll (medium impact, low risk)
5. Oversized bundle → code split heavy routes (medium impact, low risk)
6. Unnecessary re-renders → fix component boundaries or state placement (medium impact, medium risk)
7. Missing HTTP caching → add Cache-Control headers (medium impact, low risk)
8. Hot-path allocations → pool or reuse objects (small impact, medium risk — .NET specific)

Performance monitoring in production:
- Track key metrics: p95 response time, error rate, request throughput, CPU/memory usage
- Set alerts on degradation: p95 > 2x baseline, error rate > 1%, memory growing linearly
- Use distributed tracing (OpenTelemetry) to identify slow spans across services
- Track Core Web Vitals via RUM (Real User Monitoring): CrUX, web-vitals library, or observability platform
- Compare performance before/after deployments — catch regressions early
- Dashboard key metrics by endpoint, not just aggregate — one slow endpoint hides behind healthy averages

Angular performance patterns:

- OnPush change detection: use `changeDetection: ChangeDetectionStrategy.OnPush` on every component; combine with signals for automatic dirty-marking
- Signals deep dive: `signal()` for state, `computed()` for derived values, `effect()` for side effects -- Angular skips change detection when signal values haven't changed
- `trackBy` in `@for`: `@for (item of items; track item.id)` -- prevents DOM recreation on list updates
- Lazy loading routes: `loadChildren: () => import('./feature/routes')` or `loadComponent` for standalone
- `@defer` blocks: `@defer (on viewport) { <HeavyChart /> }` with `@placeholder`, `@loading` -- lazy-loads template sections
- Zone.js optimization: `provideZoneChangeDetection({ eventCoalescing: true })` in bootstrap -- batches multiple events into one CD cycle
- Bundle analysis: `ng build --stats-json` then `npx webpack-bundle-analyzer dist/app/stats.json`

Vue / Nuxt performance patterns:

- `defineAsyncComponent`: `const Chart = defineAsyncComponent(() => import('./Chart.vue'))` -- code-splits component into separate chunk
- `<Suspense>` for async components: wrap async components with `<Suspense>` to show fallback while loading
- `v-once` / `v-memo`: `v-once` for truly static content; `v-memo="[item.id]"` to skip re-render when deps unchanged
- Nuxt `useAsyncData`: `const { data } = await useAsyncData('key', () => $fetch('/api/data'))` -- prevents waterfall by fetching during SSR
- Nuxt ISR with `routeRules`: `routeRules: { '/products/**': { isr: 3600 } }` in `nuxt.config.ts` -- stale-while-revalidate at edge
- Bundle analysis: `vite-plugin-inspect` for dev, `npx vite-bundle-visualizer` for production build analysis

SvelteKit performance patterns:

- `{#await}` blocks: `{#await promise} <Spinner /> {:then data} <List {data} /> {:catch err} <Error /> {/await}` -- declarative async rendering
- `$effect.pre` for pre-render optimization: runs before DOM update, useful for measuring/preparing layout
- Prerendering static pages: `export const prerender = true` in `+page.ts` -- generates static HTML at build time
- Full SSG: use `@sveltejs/adapter-static` with `fallback: '404.html'` for complete static site generation
- Code splitting: SvelteKit auto-splits per route; for heavy components use `{#await import('./Heavy.svelte') then module} <svelte:component this={module.default} /> {/await}`

Blazor performance patterns:

- `@key` directive: `@foreach (var item in Items) { <OrderRow @key="item.Id" Order="item" /> }` -- efficient list diffing, prevents unnecessary DOM recreation
- `ShouldRender()` override: return `false` to skip re-rendering when component state hasn't changed
```csharp
private int _lastCount;
protected override bool ShouldRender() {
    if (Items.Count == _lastCount) return false;
    _lastCount = Items.Count;
    return true;
}
```
- `Virtualize<T>`: `<Virtualize Items="@largeList" Context="item"><OrderRow Order="@item" /></Virtualize>` -- renders only visible rows, essential for 1000+ item lists
- `@rendermode` selection: use `@rendermode InteractiveServer` only for interactive sections; keep static content as SSR to reduce circuit overhead
- `StateHasChanged()` batching: avoid calling in loops; update all state first, call once; prefer `InvokeAsync(StateHasChanged)` from non-UI threads
- .NET profiling: `dotnet-counters monitor -p <pid> --counters System.Runtime` for real-time GC/CPU; `dotnet-trace collect -p <pid>` for flamegraph analysis in Speedscope

## Structured Output Contract
- **Status**: `done` | `partial` | `blocked`
- **Changed**: `[file.ext: +lines/-lines, ...]` — list every modified file
- **Notes**: blockers or non-obvious decisions only — omit if none

Do NOT return prose summaries or recaps.
