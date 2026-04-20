---
name: reporting-dashboards
description: Build aggregation queries, materialized views, scheduled reports, data export pipelines, dashboard data APIs, and real-time dashboard feeds
metadata:
  version: 1.3
  argument-hint: "dashboard type (operational/financial), data source, metrics to track, export formats needed"
---

Implement reporting and dashboard functionality for $ARGUMENTS.


## Architecture

```
Source Data (OLTP) -> Aggregation Layer:
  Materialized Views (pre-computed) | Live Queries (bounded) | Time-Series Tables (partitioned)
  -> Report/Dashboard API:
  Dashboard JSON | Scheduled reports (job->email/S3) | Export (CSV/Excel/PDF) | BI connectors (read replica)
```

## Aggregation Queries

### Window Functions

```sql
-- Revenue by month with running total and MoM growth
SELECT date_trunc('month', created_at) AS month,
  SUM(amount) AS revenue,
  SUM(SUM(amount)) OVER (ORDER BY date_trunc('month', created_at)) AS cumulative,
  ROUND((SUM(amount) - LAG(SUM(amount)) OVER (ORDER BY date_trunc('month', created_at)))
    / NULLIF(LAG(SUM(amount)) OVER (ORDER BY date_trunc('month', created_at)), 0) * 100, 2) AS growth_pct
FROM orders WHERE created_at >= NOW() - INTERVAL '12 months' AND status = 'completed'
GROUP BY 1 ORDER BY 1;
```

### Time-Series with Gap Filling

```sql
SELECT gs.bucket AS period, COALESCE(COUNT(o.id), 0) AS orders, COALESCE(SUM(o.amount), 0) AS revenue
FROM generate_series(date_trunc('day', NOW() - INTERVAL '30 days'), date_trunc('day', NOW()), '1 day') AS gs(bucket)
LEFT JOIN orders o ON date_trunc('day', o.created_at) = gs.bucket AND o.status = 'completed'
GROUP BY 1 ORDER BY 1;
```

### Rules

- Always include time range filter; use `date_trunc()` for bucketing, `generate_series()` for gap filling
- Use window functions (`RANK`, `LAG`, `SUM OVER`, `PERCENTILE_CONT`) over self-joins
- Index WHERE + GROUP BY columns; partial indexes for common filters

## Materialized Views

Use when: query >500ms, data changes infrequently vs reads, dashboard loads same aggregation repeatedly.

```sql
CREATE MATERIALIZED VIEW daily_metrics AS
SELECT date_trunc('day', created_at) AS day, org_id,
  COUNT(*) AS orders, SUM(amount) AS revenue, COUNT(DISTINCT customer_id) AS customers
FROM orders WHERE status = 'completed'
GROUP BY 1, 2 WITH DATA;

CREATE UNIQUE INDEX idx_daily_metrics_day_org ON daily_metrics (day, org_id);
REFRESH MATERIALIZED VIEW CONCURRENTLY daily_metrics; -- requires unique index
```

Refresh: scheduled cron (5-60 min), event-driven, or manual. Always unique index for CONCURRENTLY. Monitor refresh duration.

## Scheduled Reports

```
Cron -> Report Job (background):
  Query (matview or read replica) -> Generate (CSV/Excel/PDF) -> Store (S3) -> Deliver (email with download link) -> Audit log
```

Rules: run against read replica or matview; background job only; cap rows (100K CSV, 50K Excel); retry with backoff; respect user timezone.

## Data Export

### CSV Streaming

```typescript
res.setHeader('Content-Type', 'text/csv');
res.setHeader('Content-Disposition', `attachment; filename="${name}.csv"`);
res.write('\uFEFF'); // BOM for Excel UTF-8
res.write(columns.map(c => c.label).join(',') + '\n');
for await (const row of cursor) { res.write(columns.map(c => escapeCsvField(row[c.key])).join(',') + '\n'); }
res.end();
```

### Excel -- ExcelJS streaming writer with styled headers
### PDF -- Puppeteer for complex layouts, PDFKit for simple; max 50 pages

## Dashboard APIs

```
GET /api/dashboard/overview?period=30d&orgId=x       -> { metrics, trends }
GET /api/dashboard/metrics/:id?from=&to=&granularity= -> { data: [{period, value}], summary }
GET /api/dashboard/breakdown/:dim?metric=&limit=      -> { data: [{label, value, %}] }
```

- Cache in Redis (1-5 min TTL); always scope by org/tenant
- Support granularity: hour, day, week, month; return summary stats
- Use matviews for expensive aggregations; paginate breakdowns

## Real-Time Feeds (SSE)

```typescript
app.get('/api/dashboard/live', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  const orgId = req.user.orgId;
  const sendMetrics = async () => { res.write(`data: ${JSON.stringify(await getMetrics(orgId))}\n\n`); };
  sendMetrics();
  const interval = setInterval(sendMetrics, 10_000);
  req.on('close', () => clearInterval(interval));
});
```

SSE for server-push; 10-30s intervals; cache intermediate results.

## Role-Based Access

- Every query includes org/tenant scope; role determines visible columns
- Viewer: basic counts. Manager: + revenue. Admin: all columns.
- Export and scheduling permissions separate from viewing
- BI tool access via dedicated read-only DB user with RLS

## BI Connectors

- **Metabase**: read replica, dedicated RO user, collections by team, native query + question builder
- **Grafana**: operational dashboards, variables for filtering, alert rules
- **PowerBI**: views/matviews as source, DirectQuery for real-time, RLS via roles

Rules: always read replica; dedicated DB user per tool; monitor BI query perf; document data model.

## Performance

- `EXPLAIN ANALYZE` for slow queries; covering indexes; partition large tables by time
- Matviews for >500ms queries; pre-aggregate for >100M rows
- Read replica with PgBouncer; acceptable lag <5s, alert at >30s

## Anti-Patterns

- Aggregating in app memory instead of the database — defeats query planner optimizations for large datasets
- Sync Excel/PDF generation in request handlers — large reports block threads and timeout; always queue
- BI tools connecting to the primary DB — heavy analytical queries cause read contention; use a read replica
- Unbounded aggregation queries with no time-range filter — full table scans that scale with data volume

## Output Format

```
Type:           [dashboard / scheduled / export]
Source:         [live query / matview / summary table]
Caching:        [Redis TTL / HTTP cache]
Access:         [role-based scoping]
Export:         [CSV / Excel / PDF]
BI:             [Metabase / Grafana / PowerBI]
Performance:    [read replica / partitioning / indexing]
```

## Done Criteria

- Dashboard <500ms cached, <2s fresh; proper indexes and time-range filters
- Matviews refresh on schedule without blocking reads
- Scheduled reports generate/deliver on time; exports stream without OOM
- All endpoints enforce tenant + role access; BI on read replica with RLS
- Real-time feeds update at configured interval; audit trail for reports
