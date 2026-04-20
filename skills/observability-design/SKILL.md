---
name: observability-design
description: Design observability architecture covering structured logging, metrics, distributed tracing, alerting, dashboards, error tracking, health checks, and log aggregation
metadata:
  version: 2.2
  argument-hint: "tech stack, services count, traffic volume, required metrics and thresholds"
---

Design the observability architecture for $ARGUMENTS.

Stacks: Serilog (.NET), Winston/Pino (Node.js), structlog (Python) | Prometheus, Datadog, CloudWatch, OpenTelemetry Metrics | OpenTelemetry, Jaeger, Zipkin, AWS X-Ray, Datadog APM | Grafana, Datadog, CloudWatch Dashboards | PagerDuty, OpsGenie, Grafana Alerting | Sentry, Datadog Error Tracking | ELK, Grafana Loki, CloudWatch Logs | ASP.NET Health Checks, Kubernetes probes.

## Core Principles

Observability is the ability to answer questions you did not predict. Three pillars: logs, metrics, traces — use each where it excels. Alert on symptoms (SLOs), not causes. Structured logging from day one. Correlation IDs across all services. Dashboards are for understanding; alerts are for action. Instrument at boundaries: HTTP handlers, DB calls, queue consumers, external integrations.

## Design Workflow

1. Identify system topology, service boundaries, communication patterns
2. Define logging conventions: levels, structured fields, correlation strategy
3. Define metric taxonomy: application, infrastructure, business metrics
4. Design distributed tracing: span hierarchy, context propagation, sampling
5. Define SLIs and SLOs for business-critical paths
6. Design alerting rules with severity levels and escalation
7. Design dashboards for operational awareness and incident investigation
8. Define error tracking integration and grouping strategy
9. Design health check endpoints
10. Define log aggregation pipeline and query patterns
11. Plan cost: sampling, retention, volume controls

## Structured Logging

Log levels: TRACE (fine-grained, disabled in prod by default) | DEBUG (internal flow, enabled during investigation) | INFO (significant events, request lifecycle, state transitions) | WARN (recoverable issues, approaching limits) | ERROR (failed operations, include error context) | FATAL (system-level failure, cannot continue).

Conventions: every log entry is a structured object; include standard fields on every entry: `timestamp`, `level`, `service`, `version`, `correlation_id`; contextual fields: `user_id`, `tenant_id`, `request_id`, `operation`; consistent field naming (pick snake_case or camelCase); never log secrets/tokens/passwords/PII/full bodies; log at boundaries; include `duration_ms` on all timed operations.

Correlation: generate `correlation_id` at entry point; propagate via `X-Correlation-ID` or `traceparent` header; include in every log, metric tag, and trace span; carry in async message metadata; support parent-child for fan-out.

**Serilog (.NET):**
```csharp
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .Enrich.WithProperty("Service", "OrderApi")
    .WriteTo.Console(new RenderedCompactJsonFormatter())
    .WriteTo.Seq("http://localhost:5341")
    .CreateLogger();
// Usage: logger.LogInformation("Order {OrderId} placed in {DurationMs}ms", order.Id, sw.ElapsedMilliseconds);
```

**Pino (Node.js):**
```typescript
const logger = pino({ level: process.env.LOG_LEVEL ?? 'info',
  base: { service: 'order-api', env: process.env.NODE_ENV },
  redact: ['req.headers.authorization', 'body.password'] });
// Per-request child: req.log = logger.child({ correlationId: req.headers['x-correlation-id'] });
```

Framework notes: Serilog — use enrichers, `LogContext.PushProperty` for scoped correlation, `@` destructuring for complex objects. Pino — use `child()` for request-scoped context, configure serializers for redaction, pino-http for Express/Fastify. structlog (Python) — configure JSON renderer for prod, bound loggers for context propagation.

## Metrics

Types: **Counter** (monotonic: requests served, errors) | **Gauge** (point-in-time: active connections, queue depth) | **Histogram** (distribution: latency, response size — prefer over Summary for aggregation flexibility).

**RED method** (request-driven services): Rate (requests/sec by endpoint/method/status) | Errors (error rate by endpoint/type/status) | Duration (latency distribution p50/p95/p99).

**USE method** (resource-driven): Utilization (% capacity: CPU, memory, connections) | Saturation (work queued: queue depth, thread pool) | Errors (resource-level: disk errors, connection failures).

Standard application metrics:
- `http_request_duration_seconds` (histogram, labels: method/route/status_code)
- `http_requests_total` (counter, labels: method/route/status_code)
- `db_query_duration_seconds` (histogram, labels: operation/table)
- `external_call_duration_seconds` (histogram, labels: service/operation/status)
- `background_job_duration_seconds` (histogram, labels: job_type/status)
- `cache_hit_total` / `cache_miss_total` (counter, labels: cache_name)

Business metrics: `orders_placed_total`, `payments_processed_total`, `user_signups_total` — include dimensions: plan_tier, region, feature. Enable alerting on business impact, not just system failure.

Naming: snake_case with unit suffix (`_seconds`, `_bytes`, `_total`); prefix with service/domain; never use user_id/request_id/unbounded values as labels; cardinality <100 unique values per label; document every custom metric.

## SLIs and SLOs

SLI types: **Availability** (successful requests / total) | **Latency** (requests completing within threshold) | **Correctness** (correct results, measure with canary checks) | **Freshness** (data age for pipelines/caches/replicas).

SLO definition: express per critical user journey; "99.9% of checkout requests complete successfully within 2 seconds over a 30-day window"; error budget = 0.1% of requests per window; burn rate alerts over static thresholds.

Multi-window burn rate (Prometheus example):
```yaml
# Fast burn: 14.4x budget in 1h → page immediately
- alert: CheckoutSLOFastBurn
  expr: slo:checkout:error_ratio5m > (14.4 * 0.001)
  for: 2m; labels: { severity: critical }
  annotations: { runbook: "https://wiki.internal/runbooks/checkout-slo" }

# Slow burn: 6x budget in 6h → page during business hours
- alert: CheckoutSLOSlowBurn
  expr: slo:checkout:error_ratio5m > (6 * 0.001)
  for: 15m; labels: { severity: warning }
```

Record SLI metrics at boundary closest to user; alert on burn rate; review SLOs monthly.

## Distributed Tracing

Architecture: every inbound request starts/continues a trace; every significant operation creates a span; spans form parent-child tree; context propagates via W3C Trace Context (`traceparent` header).

Span design: name after operation (`HTTP GET /api/orders`, `DB SELECT orders`); include attributes: `http.method`, `http.route`, `http.status_code`, `db.system`, `db.statement` (parameterized); record span status OK/ERROR; add events for significant moments; avoid spans for trivial operations.

OpenTelemetry: use as instrumentation layer, export to any backend via OTLP; auto-instrument HTTP/DB/messaging; manual instrumentation for business-critical ops; export to Jaeger/Zipkin/Datadog/Grafana Tempo/X-Ray.

Sampling strategies: head-based (decide at trace start, simple, may miss interesting traces) | tail-based (decide after completion, captures errors/slow requests, requires collector) | always sample errors + high-latency + specific user segments | 1-10% probabilistic for normal traffic.

Context propagation: HTTP via `traceparent`/`tracestate` | gRPC via metadata | message queues via message headers | background jobs via serialized context in job payload.

## Alerting

Principles: alert on user-facing symptoms, not internal causes. Every alert must be actionable. Every alert must have a runbook. Prefer SLO burn rate over static thresholds. Reduce noise — too many alerts → alert fatigue.

Severity: P1/Critical (user-facing outage, data loss, security breach — page immediately) | P2/High (significant degradation, partial outage, SLO burn — page business hours) | P3/Medium (elevated errors, performance degradation — notify in channel) | P4/Low (informational, trend anomaly — ticket or dashboard).

Alert rule patterns: error rate spike | latency degradation (p99 > SLO threshold sustained) | SLO burn rate (14.4x 1h or 6x 6h) | queue depth exceeding threshold | resource saturation (CPU/memory/connections) | external dependency errors | heartbeat/deadman (expected signal not received).

Alert routing: P1/P2 → PagerDuty/OpsGenie with escalation policy; P3 → Slack channel + dashboard link; P4 → ticket or dashboard only. Escalation: P1 not acknowledged in 5min → escalate.

Every P1/P2 alert must link to a runbook containing: what the alert means, likely causes, diagnostic steps, mitigation actions, escalation contacts. Review runbooks after every incident.

## Dashboards

**Service overview:** Row 1: SLO status, error budget remaining, overall availability | Row 2: request rate, error rate, latency percentiles | Row 3: dependency health (DB, cache, external) | Row 4: infrastructure (CPU, memory, pod count, restart count).

**Per-endpoint:** request rate by endpoint | error rate by type | latency distribution | slow query/dependency breakdown.

Grafana guidance: use variables for environment/service/time range; stat panels for current values, time series for trends, heatmaps for distributions; consistent colors (green = healthy, yellow = warning, red = critical); meaningful Y-axis ranges; annotations for deployments/incidents/config changes; version dashboards as code (Grafonnet/Terraform/JSON in VCS).

## Error Tracking (Sentry)

Configure SDK in every service; set environment + release tags; `before-send` hook to scrub PII; group by root cause (exception type + normalized stack trace); custom fingerprints for known patterns; separate transient (timeouts, rate limits) from persistent bugs; alert on new error types and rate spikes; attach context: `user_id`, `tenant_id`, `request_id`, feature flag state; source maps/debug symbols for readable stack traces.

## Health Checks

Types: **Liveness** (is process alive? — no dependency checks, fast, no auth) | **Readiness** (can handle traffic? — check DB/cache/config) | **Startup** (finished initialization? — for slow-starting services).

Endpoints: `/healthz` or `/health/live` (liveness) | `/health/ready` (readiness) | `/health/startup`. Response: `{ "status": "healthy", "checks": { "database": "ok", "cache": "ok" } }`. Rules: <1 second; no auth required; include degraded status for non-critical dependencies.

.NET: `services.AddHealthCheck().AddNpgSql().AddRedis()`, `app.MapHealthChecks("/health/ready")`. Node.js: check pool connectivity, Redis ping, required env vars; 200 = healthy, 503 = unhealthy.

## Log Aggregation

Pipeline: app → stdout/stderr (structured JSON) → collector (Fluentd/Fluent Bit/Vector) → aggregation backend (Elasticsearch/Loki/CloudWatch) → query interface (Kibana/Grafana/CloudWatch Insights).

Query patterns: filter by `correlation_id` to trace single request across services | filter by `level=error` + `service` | aggregate by error type and time | search by `user_id`/`tenant_id` for support investigations | log-based metrics for patterns not in application metrics.

ELK: index per service per day, ILM for retention/rollover. Loki: labels `service`/`environment`/`level` only (avoid high-cardinality), LogQL for filtering/aggregation, object store for cost-effective high-volume.

## Cost Management

Log volume: INFO in prod, DEBUG in dev; sampling for high-volume debug; avoid logging full bodies; per-namespace log level overrides; alert on unexpected volume spikes.

Metric cardinality: never use user_id/request_id/IP as labels; limit to <100 unique values per label; monitor active time series; recording rules to pre-aggregate high-cardinality queries.

Trace sampling: 100% errors and slow requests; 1-10% normal traffic; tail-based sampling at collector; monitor trace storage costs quarterly.

Retention: logs 7-30 days hot, 90 days warm, cold for compliance; metrics 15 days full resolution, 1 year downsampled (1m→5m→1h); traces 7-14 days.

## Anti-Patterns

Unstructured log messages | logging PII/secrets/tokens | alerting on every error instead of SLO burn rate | dashboard with 50 panels and no clear purpose | high-cardinality metric labels | health checks that test entire dependency tree and timeout | tracing every function call instead of meaningful operations | ignoring sampling and paying for 100% trace ingestion at scale | alerting without runbooks | mixing operational logs with business audit records.

## Output Requirements

- Short observability architecture summary
- Logging conventions with concrete structured field definitions
- Metric taxonomy with names, types, labels, and thresholds
- SLIs and SLOs for critical user journeys
- Distributed tracing strategy with span hierarchy and sampling
- Alerting rules with severity levels and escalation paths
- Dashboard specifications with panel layout and queries
- Health check endpoints with dependency checks
- Log aggregation pipeline and retention policies
- Cost management strategy
