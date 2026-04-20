---
name: performance-budgets
description: Implement performance budgets and Real User Monitoring (RUM) including bundle size budgets, Core Web Vitals thresholds, LCP/FID/CLS tracking, CI performance gates, Lighthouse integration, and RUM dashboards
metadata:
  version: 1.4
  argument-hint: "framework (Next.js/Vue/Angular), target metrics (LCP/CLS/INP), CI tool, RUM backend"
---

Implement performance budgets and monitoring for $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

## Budget Types

| Budget type | Typical threshold | Tool |
|---|---|---|
| Bundle size (JS) | <200KB gzipped initial | size-limit, bundlesize, webpack-bundle-analyzer |
| Bundle size (CSS) | <50KB gzipped initial | size-limit |
| Transfer size (total) | <500KB gzipped | Lighthouse CI, WebPageTest |
| Core Web Vitals | LCP <2.5s, INP <200ms, CLS <0.1 | web-vitals, Lighthouse, CrUX |
| Time to Interactive | <3.5s (3G), <1.5s (4G) | Lighthouse |
| Request count | <50 initial | Lighthouse, WebPageTest |
| Image weight | <500KB initial viewport | Lighthouse, custom |
| Third-party JS | <100KB, <5 scripts | Lighthouse, bundlewatch |
| Font weight | <100KB | size-limit, custom |

## Setting Budgets

**Baseline first:** `npx lighthouse https://your-app.com --output=json > baseline.json` and `npx size-limit --json > bundle-baseline.json`.

**Budget calculation:**
1. Measure current state (baseline)
2. Set target: baseline or better — never worse
3. Add 10% buffer for acceptable variance
4. Warning at 90% of budget, error at 100%
5. Review and tighten quarterly

**`performance-budgets.json`:**
```json
{
  "budgets": {
    "javascript": {
      "initial": { "warning": "180KB", "error": "200KB" },
      "perRoute": { "warning": "50KB", "error": "75KB" }
    },
    "css": { "initial": { "warning": "40KB", "error": "50KB" } },
    "images": {
      "initialViewport": { "warning": "400KB", "error": "500KB" },
      "heroImage": { "warning": "100KB", "error": "150KB" }
    },
    "fonts": { "total": { "warning": "80KB", "error": "100KB" } },
    "coreWebVitals": {
      "LCP": { "good": "2.5s", "poor": "4.0s" },
      "INP": { "good": "200ms", "poor": "500ms" },
      "CLS": { "good": "0.1", "poor": "0.25" }
    },
    "requests": { "initial": { "warning": 40, "error": 50 } }
  }
}
```

## Core Web Vitals Targets

| Metric | Good | Needs Improvement | Poor | Measures |
|---|---|---|---|---|
| LCP | <2.5s | 2.5–4.0s | >4.0s | Loading performance |
| INP | <200ms | 200–500ms | >500ms | Interactivity |
| CLS | <0.1 | 0.1–0.25 | >0.25 | Visual stability |
| FCP | <1.8s | 1.8–3.0s | >3.0s | Perceived load start |
| TTFB | <800ms | 800–1800ms | >1800ms | Server response |

**Per page type:**
| Page | LCP | INP | CLS |
|---|---|---|---|
| Landing | <2.0s | <100ms | <0.05 |
| Product | <2.5s | <150ms | <0.1 |
| Dashboard | <3.0s | <200ms | <0.1 |
| Checkout | <2.0s | <100ms | <0.05 |

## CI Integration

### Lighthouse CI

```javascript
// lighthouserc.js
module.exports = {
  ci: {
    collect: {
      url: ['http://localhost:3000/', 'http://localhost:3000/products'],
      startServerCommand: 'npm run start',
      numberOfRuns: 3,
    },
    assert: {
      assertions: {
        'categories:performance': ['error', { minScore: 0.9 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
        'total-blocking-time': ['error', { maxNumericValue: 300 }],
        'first-contentful-paint': ['error', { maxNumericValue: 1800 }],
        'interactive': ['warn', { maxNumericValue: 3500 }],
        'resource-summary:script:size': ['error', { maxNumericValue: 200000 }],
        'resource-summary:stylesheet:size': ['warn', { maxNumericValue: 50000 }],
      },
    },
    upload: { target: 'temporary-public-storage' },
  },
};
```

### GitHub Actions

```yaml
name: Performance Budget
on:
  pull_request:
    branches: [main]

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci && npm run build
      - uses: treosh/lighthouse-ci-action@v12
        with:
          configPath: ./lighthouserc.js
          uploadArtifacts: true
          temporaryPublicStorage: true

  bundle-size:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci && npm run build
      - uses: andresz1/size-limit-action@v1
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          skip_step: build
```

### size-limit / bundlesize

```javascript
// .size-limit.js
module.exports = [
  { name: 'Initial JS', path: 'dist/assets/*.js', limit: '200 KB', gzip: true },
  { name: 'Initial CSS', path: 'dist/assets/*.css', limit: '50 KB', gzip: true },
  { name: 'Home page', path: 'dist/chunks/home-*.js', limit: '50 KB' },
  { name: 'Dashboard', path: 'dist/chunks/dashboard-*.js', limit: '75 KB' },
  { name: 'Shared chunks', path: 'dist/chunks/vendor-*.js', limit: '120 KB' },
];
```

```json
// package.json bundlesize
{ "bundlesize": [
  { "path": "dist/assets/index-*.js", "maxSize": "100 KB", "compression": "gzip" },
  { "path": "dist/assets/vendor-*.js", "maxSize": "120 KB", "compression": "gzip" }
]}
```

### Bundle Visualization

Next.js: `ANALYZE=true npm run build` via `@next/bundle-analyzer`.

Vite / SvelteKit / Nuxt:
```typescript
// vite.config.ts
import { visualizer } from 'rollup-plugin-visualizer';
export default defineConfig({
  plugins: [process.env.ANALYZE && visualizer({ open: true, gzipSize: true })].filter(Boolean),
  build: { rollupOptions: { output: { manualChunks: { vendor: ['react','react-dom'] } } } },
});
```

## Performance Regression Detection

```typescript
function comparePerformance(
  baseline: Record<string, number>,
  current: Record<string, number>,
  thresholds: Record<string, { warn: number; fail: number }>
): PerformanceComparison[] {
  return Object.entries(current).map(([metric, value]) => {
    const base = baseline[metric] ?? value;
    const deltaPercent = base > 0 ? ((value - base) / base) * 100 : 0;
    let status: 'pass' | 'warn' | 'fail' = 'pass';
    if (thresholds[metric]) {
      if (value > thresholds[metric].fail) status = 'fail';
      else if (value > thresholds[metric].warn) status = 'warn';
    }
    return { metric, baseline: base, current: value, delta: value - base, deltaPercent, status };
  });
}
```

**PR comment** (GitHub Actions step after Lighthouse CI): post metric table with Pass/Fail per LCP, CLS, TBT, Performance score using `actions/github-script` and `.lighthouseci/manifest.json`.

**Alert thresholds:**
- CI fails (blocking): bundle size exceeds error threshold
- CI warns (non-blocking): warning threshold hit or Lighthouse score drops >5 points
- Slack: production RUM p75 degrades for 2+ consecutive hours
- PagerDuty: LCP p75 >4s or CLS p75 >0.25 for 15+ minutes

## RUM Implementation

```typescript
import { onLCP, onINP, onCLS, onFCP, onTTFB } from 'web-vitals';

function sendToAnalytics(metric: WebVitalMetric): void {
  navigator.sendBeacon('/api/rum/vitals', JSON.stringify({
    name: metric.name, value: metric.value, rating: metric.rating,
    delta: metric.delta, id: metric.id,
    url: window.location.pathname,
    connectionType: (navigator as any).connection?.effectiveType,
    timestamp: Date.now(),
  }));
}

onLCP(sendToAnalytics); onINP(sendToAnalytics); onCLS(sendToAnalytics);
onFCP(sendToAnalytics); onTTFB(sendToAnalytics);
```

**Custom marks:**
```typescript
performance.mark('search-started');
const results = await searchApi.query(term);
performance.mark('search-completed');
performance.measure('search-duration', 'search-started', 'search-completed');
```

**PerformanceObserver** — observe `longtask` (duration >50ms) and `resource` (transferSize >100KB); send both to analytics.

**Sampling:**
```typescript
const SESSION_SAMPLE_RATE = 0.1; // 10%
if ((simpleHash(getOrCreateSessionId()) % 100) < SESSION_SAMPLE_RATE * 100) {
  onLCP(sendToAnalytics); onINP(sendToAnalytics); onCLS(sendToAnalytics);
}
```

**Enrich metric** with: `route` (e.g. `/products/:id`), `connectionType`, `deviceMemory`, `viewport`, `isReturningVisitor`, `deployVersion`, `country`.

**Backend endpoint** (`POST /api/rum/vitals`): validate `name` and `value`, store in time-series DB with session ID and timestamp. Return 204.

## Dashboard

**Percentile tracking — always use percentiles, not averages:**
| Percentile | Use |
|---|---|
| P50 | General health |
| P75 | Google CWV threshold (CrUX uses p75) |
| P95 | Tail latency / worst-case UX |

**Grafana panels:**
- Row 1: LCP/INP/CLS p75 time series per route; CWV pass rate %
- Row 2: JS bundle size, total transfer size, request count — per deploy
- Row 3: CWV by connection type and device; slowest resources table
- Row 4: Deploy markers overlaid on metrics; before/after comparison

**SQL (PostgreSQL):**
```sql
-- CWV p75 by route, last 24h
SELECT url, metric,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY value) AS p50,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY value) AS p75,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY value) AS p95,
  COUNT(*) AS sample_count
FROM rum_metrics
WHERE timestamp > NOW() - INTERVAL '24 hours' AND metric IN ('LCP','INP','CLS')
GROUP BY url, metric ORDER BY url, metric;
```

## Alerting

| Condition | Severity | Channel |
|---|---|---|
| LCP p75 >2.5s for 30+ min | Warning | Slack |
| LCP p75 >4.0s for 15+ min | Critical | PagerDuty |
| INP p75 >200ms for 30+ min | Warning | Slack |
| INP p75 >500ms for 15+ min | Critical | PagerDuty |
| CLS p75 >0.1 for 30+ min | Warning | Slack |
| CLS p75 >0.25 for 15+ min | Critical | PagerDuty |
| Bundle exceeds error budget | Blocking | CI fails |
| Lighthouse score drops >10 pts | Warning | PR comment + Slack |

**Trend detection:** compare current hour p75 against same hour last week; alert if >20% relative degradation; alert if any CWV crosses from "good" to "needs improvement" post-deploy.

## Framework-Specific Configuration

**Angular (`angular.json`):**
```json
{ "budgets": [
  { "type": "initial", "maximumWarning": "500kb", "maximumError": "1mb" },
  { "type": "anyComponentStyle", "maximumWarning": "6kb", "maximumError": "10kb" },
  { "type": "bundle", "name": "vendor", "maximumWarning": "300kb", "maximumError": "500kb" }
]}
```
Types: `initial`, `anyComponentStyle`, `bundle`, `anyScript`, `any`.

**Next.js:** `@next/bundle-analyzer` + `experimental.optimizePackageImports` for large icon/UI libs. `@vercel/speed-insights/next` for automatic CWV on Vercel.

**Vite / SvelteKit / Nuxt:** `rollup-plugin-visualizer` for analysis + `size-limit` for CI enforcement.

## Optimization Playbook (When Budget Exceeded)

**JS too large:**
1. Code-split routes and heavy components (`React.lazy`, dynamic `import()`)
2. Tree shaking: verify `sideEffects: false`, use named imports
3. Replace heavy libraries: moment→date-fns, lodash→lodash-es or native
4. `npx depcheck` — remove unused dependencies
5. Bundle analyzer — identify largest chunks

**CSS too large:**
1. Purge unused CSS — Tailwind does this automatically; verify `content` config
2. Import only used components from UI libraries
3. Extract critical CSS inline; defer the rest

**Images too large:**
1. WebP (25–35% smaller) or AVIF (50% smaller vs JPEG)
2. `srcset` with appropriate sizes; `loading="lazy"` below fold
3. Compression quality 75–85; CDN auto-optimization (Cloudinary, Imgix)

**LCP too slow:**
1. `<link rel="preload" as="image" fetchpriority="high">` for hero image
2. SSR/SSG for critical above-fold content
3. Inline critical CSS; reduce TTFB; use server components for LCP element

**INP too high:**
1. Break long tasks: `requestIdleCallback`, `scheduler.yield()`
2. Debounce/throttle input handlers (100–200ms)
3. Web Workers for heavy computation
4. Reduce re-renders; `content-visibility: auto` for off-screen sections

**CLS too high:**
1. Set `width`/`height` on images and videos
2. Reserve space for dynamic content with `min-height`
3. `font-display: swap` + preload; `size-adjust` for fallback matching
4. Use `transform` for animations — not layout properties

## Reporting

Weekly report format:
```
Core Web Vitals p75:  LCP 2.1s (good), INP 145ms (good), CLS 0.04 (good)
Bundle Size:          JS 178KB/200KB (89%), CSS 32KB/50KB (64%)
CWV Pass Rate:        87% (target >85%)
Top Regressions:      [route, metric, delta, deploy version]
Recommendations:      [actionable fix per regression]
```

Release comparison SQL: `PERCENTILE_CONT(0.75)` per `deploy_version` from `rum_metrics` where version IN ('v2.4.0', 'v2.4.1').

## Anti-Patterns

- Lab-only testing (Lighthouse) without RUM -- synthetic scores don't reflect real user network conditions
- Global CWV metrics only -- per-route breakdown required; a slow checkout hides behind a fast homepage
- Not correlating deploys with metric changes -- regressions go unattributed for weeks
- Bundle analyzer without CI enforcement -- visible bloat but no gate to prevent it shipping
- Optimizing for Lighthouse score instead of real user percentile metrics

## Implementation Workflow

1. Measure baseline (Lighthouse + RUM if available)
2. Define budgets per resource type and per CWV metric
3. Configure CI gates (size-limit, Lighthouse CI)
4. Integrate `web-vitals` for RUM collection with sampling
5. Set up RUM data pipeline (endpoint, storage, enrichment)
6. Build dashboard with percentile tracking per route and deploy markers
7. Configure alerts for threshold breaches and trend degradation
8. Document optimization playbook per budget type
9. Schedule weekly performance review
10. Tighten budgets quarterly based on progress

## Output Format

```
Budgets:       [JS size, CSS size, image weight, CWV thresholds]
CI Gates:      [Lighthouse CI, size-limit — pass/fail criteria]
RUM:           [web-vitals, sampling rate, data pipeline]
Dashboard:     [tool, panels, percentiles tracked]
Alerting:      [threshold conditions, channels]
Framework:     [framework-specific budget config]
Reporting:     [weekly format, release comparison]
Optimization:  [playbook per budget type]
```

## Done Criteria

- Budgets defined for JS, CSS, images, fonts, and CWV
- CI fails on budget breach for bundle size and Lighthouse score
- `web-vitals` tracking deployed with appropriate sampling
- Alerts fire on sustained CWV degradation
