---
name: load-testing
description: Design and implement load tests, stress tests, and performance benchmarks using k6, Artillery, or framework-native tools
metadata:
  version: 1.4
  argument-hint: "test type (smoke/load/stress/soak), VU count, duration, SLA targets (latency/error rate), baseline metrics"
---

Design and implement load tests for $ARGUMENTS.


## Test Types

| Type | VUs | Duration | When | Key output |
|------|-----|----------|------|------------|
| Smoke | 1-5 | 1 min | Every PR | Zero errors, latency within baseline |
| Load | Production-level | 5-15 min | Nightly, pre-release | p95 within SLA, error <0.1% |
| Stress | Ramp beyond expected | Multi-stage | Quarterly, pre-launch | Breaking point, failure mode |
| Spike | 0 -> peak instantly | Brief hold | Before flash events | Recovery time, auto-scaling |
| Soak | Normal load | 1-8 hours | Pre-release | Memory leaks, connection exhaustion |

Soak monitoring: memory RSS (should be flat/sawtooth, not linear growth), connection pool active vs idle, GC frequency.

## Realistic User Behavior

### Think Time

```javascript
http.get('/api/products');
sleep(randomIntBetween(2, 5));  // user browses
http.get('/api/products/123');
sleep(randomIntBetween(3, 8));  // user reads details
```

### Weighted Scenarios

```javascript
export const options = {
  scenarios: {
    browsers: { executor: 'ramping-vus', exec: 'browsingFlow', stages: [{ duration: '5m', target: 80 }] },
    buyers:   { executor: 'ramping-vus', exec: 'purchaseFlow', stages: [{ duration: '5m', target: 15 }] },
    api:      { executor: 'constant-arrival-rate', exec: 'apiFlow', rate: 100, timeUnit: '1s', duration: '5m', preAllocatedVUs: 50 },
  },
};
```

Read/write ratios: e-commerce 95:5, social 90:10, SaaS dashboard 80:20.

## k6 Complete Pattern

```javascript
import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '2m', target: 50 }, { duration: '5m', target: 50 },
    { duration: '2m', target: 100 }, { duration: '5m', target: 100 },
    { duration: '3m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.01'],
    'http_req_duration{name:GetProducts}': ['p(95)<300'],
  },
};

export function setup() {
  const res = http.post(`${__ENV.BASE_URL}/auth/login`, JSON.stringify({ email: __ENV.TEST_USER, password: __ENV.TEST_PASS }), { headers: { 'Content-Type': 'application/json' } });
  return { token: res.json('access_token') };
}

export default function (data) {
  const headers = { Authorization: `Bearer ${data.token}`, 'Content-Type': 'application/json' };
  group('Browse products', () => {
    const res = http.get(`${__ENV.BASE_URL}/api/products`, { headers });
    check(res, { 'status 200': (r) => r.status === 200 }) || errorRate.add(1);
    sleep(randomIntBetween(2, 5));
  });
}
```

Authenticated requests: login in `setup()` for shared token, or per-VU login with `SharedArray` of test users. Parameterize data with `SharedArray` + CSV.

## Test Data and Environment

- Generate realistic test data matching production distribution
- Never test with real user data; use separate test accounts
- Generate 2-10x data volume VUs will access (prevent cache artifacts)
- Clean up in `teardown()` or separate script; tag with `test_run_id`
- NEVER run load tests against production without coordination
- Dedicated performance environment mirroring production
- Mock external services that can't handle test traffic
- Warm caches before test

## Baseline and Regression Detection

1. Measure production peak: concurrent users, RPS, p50/p95/p99, error rate, resource utilization
2. Configure test to match production patterns
3. Validate: load test metrics within 20% of production

VU formula: `VUs = (target_RPS * avg_think_time_s) + (target_RPS * avg_response_time_s)`

### CI Regression Gating

```yaml
- name: Run load test
  run: k6 run --out json=results.json tests/load/api.js
- name: Compare against baseline
  run: |
    # Parse p95, compare to baseline, fail if >20% regression
- name: Update baseline (main only)
  if: github.ref == 'refs/heads/main'
  run: cp results.json tests/load/baseline.json
```

| Test | When | Duration | Pass/fail |
|------|------|----------|-----------|
| Smoke | Every PR | 1 min | Zero errors |
| Load (light) | Nightly | 5 min | Within thresholds |
| Load (full) | Pre-release | 15 min | Within SLA |
| Soak | Weekly | 2-4 hours | No memory leaks |

Store results in InfluxDB + Grafana for trend analysis. `k6 run --out influxdb=http://influxdb:8086/k6`.

## Bottleneck Identification

Check layer by layer: Network/CDN -> Web Server -> Application -> Database -> External Services.

| Resource | Signal | Tool |
|----------|--------|------|
| CPU | >85% sustained | top, container metrics |
| Memory | Swapping, OOM, frequent GC | free, GC logs |
| DB connections | Pool exhausted, wait time | Pool metrics, slow query log |
| Event loop (Node.js) | Lag >100ms | monitorEventLoopDelay, clinic.js |

PostgreSQL diagnostics: `pg_stat_activity` for active queries, lock waits query, cache hit ratio (should be >99%).

## Metrics Targets

| Metric | Target | Alert |
|--------|--------|-------|
| p50 latency | <100ms | >200ms |
| p95 latency | <300ms | >500ms |
| p99 latency | <1000ms | >2000ms |
| Error rate | <0.1% | >1% |
| CPU usage | <70% | >85% |
| Memory | Stable | Growing trend |

## Anti-Patterns

- No warm-up period -- cold cache skews latency results
- Single endpoints in isolation -- misses cascading effects and shared resource contention
- Ignoring error responses in throughput -- inflated RPS hides failures
- No baseline comparison -- no way to detect regressions between runs
- Saturated load generator -- generator CPU/network becomes the bottleneck, not the system

## Output Format

```
Tool:          k6 / Artillery / NBomber
Environment:   staging / performance
Scenarios:     [weighted user flows with VU distribution]
Thresholds:    [p95, p99, error rate, throughput targets]
Data:          [test users, data, cleanup approach]
CI:            [smoke on PR, load nightly, baseline comparison]
Baseline:      [p50, p95, p99, throughput, error rate, resource peaks]
Bottlenecks:   [identified with evidence and remediation]
```

## Done Criteria

- Tests cover critical paths with realistic behavior (think time, sessions)
- Thresholds for p95/p99, error rate, throughput
- Repeatable and CI-ready (smoke on every PR)
- Baseline comparison with regression detection
- Bottlenecks identified with evidence
- Test data managed: generated before, cleaned after
- Soak validates no memory leaks or connection exhaustion
- Results stored for trend analysis
- Load generator itself not the bottleneck
