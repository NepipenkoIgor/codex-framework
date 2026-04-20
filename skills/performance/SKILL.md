---
name: performance
description: Analyze and optimize performance for frontend and backend applications
metadata:
  version: 1.8
  argument-hint: "what is slow (endpoint/query/page/component), stack (frontend/backend/DB), target metrics"
---

Analyze and optimize $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

Frameworks and runtimes in scope:
- Frontend: Angular, React, Next.js, Vue, Nuxt, Svelte, Blazor
- Backend: .NET / ASP.NET Core, Node.js / Bun, NestJS, Elysia
- Styling: Tailwind CSS, CSS

Core principles:

- Measure before optimizing; never guess at bottlenecks
- Profile the real workload, not synthetic assumptions
- Apply the smallest targeted fix that addresses the measured bottleneck
- Preserve code clarity; reject optimizations that make code unmaintainable
- Verify improvement with before/after measurements
- Distinguish between perceived performance and actual throughput problems

Diagnostic workflow:

1. Reproduce -- confirm the performance issue with concrete numbers (response time, frame rate, bundle size, memory usage)
2. Profile -- use appropriate tooling to identify the bottleneck location
3. Analyze -- determine root cause; distinguish symptoms from causes
4. Fix -- apply targeted optimization for the confirmed bottleneck
5. Verify -- measure again; confirm improvement meets the goal
6. Document -- record what was slow, why, and what fixed it

Frontend performance:

Bundle size and loading:

- Analyze bundle composition; identify oversized dependencies
- Apply tree-shaking; remove dead code and unused exports
- Code-split routes and heavy features; lazy-load below-the-fold content
- Prefer dynamic imports for large libraries used conditionally
- Audit third-party scripts; defer or remove non-critical ones
- Check for duplicate dependencies across chunks

Rendering performance:

- Identify unnecessary re-renders using framework devtools
- Angular: check OnPush strategy, signal-based reactivity, trackBy in loops
- React: check component boundaries, key stability, avoid inline object/function creation in render
- Vue: check computed vs watcher misuse, v-once for static content, shallowRef for large objects
- Virtualize long lists; avoid rendering thousands of DOM nodes
- Detect and fix layout thrashing (forced synchronous reflows)
- Move expensive computations off the render path

Core Web Vitals:

- LCP: optimize critical rendering path; preload hero images; inline critical CSS; reduce server response time
- INP: break long tasks; yield to main thread; defer non-essential handlers; reduce input-to-paint latency
- CLS: set explicit dimensions on images/embeds; avoid injecting content above the fold; use CSS containment

Image and network optimization:

- Prefer modern formats (WebP, AVIF) with fallbacks; responsive images with srcset/sizes
- Lazy-load offscreen images; eager-load above-the-fold; size to display dimensions
- Analyze request waterfall; parallelize independent calls; eliminate sequential dependencies
- Prefetch critical resources; preconnect to required origins; enable compression

Memory leaks (frontend):

- Detect detached DOM nodes using heap snapshots
- Clean up event listeners, subscriptions, intervals on component destroy
- Angular: unsubscribe or use takeUntilDestroyed; prefer signals over subscriptions
- React: cleanup in useEffect return; avoid stale closures holding references
- Vue: cleanup in onUnmounted; watch for reactive object accumulation
- Check for growing collections, caches without eviction, circular references

Backend performance:

## Extended Patterns
For complex scenarios, self-load additional patterns:
Read `skills/performance/SKILL.detail.md`
Load only when task involves: profiling, bundle analysis, memory leak investigation, or Core Web Vitals optimization
