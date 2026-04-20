---
name: database-optimization
description: Optimize database performance through indexing strategies, query plan analysis, N+1 prevention, connection pooling, materialized views, and partitioning
metadata:
  version: 1.4
  argument-hint: "database type (PostgreSQL/MySQL/MongoDB), slow query signature, workload pattern (OLTP/OLAP), query plan details, baseline metrics"
---

Optimize database performance for $ARGUMENTS.

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Measurement-First Workflow

1. **Identify** -- find the slow query (logs, APM, slow query log)
2. **Measure** -- get execution time, rows scanned, and plan
3. **Analyze** -- EXPLAIN ANALYZE, identify bottleneck
4. **Fix** -- smallest change that resolves the issue
5. **Verify** -- re-run EXPLAIN ANALYZE, compare before/after
6. **Monitor** -- watch production metrics after deployment

## EXPLAIN ANALYZE

### PostgreSQL

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.id, p.name, u.email
FROM projects p JOIN users u ON u.id = p.owner_id
WHERE p.tenant_id = '...' AND p.status = 'active'
ORDER BY p.created_at DESC LIMIT 20;
```

### Reading the Plan

| Indicator | Problem | Fix |
|-----------|---------|-----|
| Seq Scan on large table | No index on filter column | Add index |
| Bitmap Heap Scan | Index found many rows | Consider covering index |
| Nested Loop with large inner | Missing index on join column | Index the join column |
| Sort (on disk) | No index matching ORDER BY | Add index with sort |
| Rows Removed by Filter >> returned | Index not selective enough | Better composite index |
| Actual rows >> planned rows | Stale statistics | Run ANALYZE |

Example: Seq Scan reading 100K rows, removing 95K by filter -> fix: `CREATE INDEX ON projects (tenant_id, status, created_at DESC)`.

For SQL Server: use `SET STATISTICS IO ON; SET STATISTICS TIME ON;` and actual execution plan.

## Index Types

### B-tree (Default)

Best for: equality, range, sorting, `LIKE 'prefix%'`. Use for PKs, FKs, WHERE columns, ORDER BY.

```sql
CREATE INDEX idx_projects_tenant_status_created
    ON projects (tenant_id, status, created_at DESC);
```

Column order: equality first -> range/inequality -> sort column last.

### Partial Index

Indexes only matching rows. Smaller, faster.

```sql
CREATE INDEX idx_active_projects ON projects (tenant_id, created_at DESC) WHERE status = 'active';
CREATE INDEX idx_pending_jobs ON jobs (created_at) WHERE processed_at IS NULL;
```

### Covering Index (INCLUDE)

Enables index-only scans (no heap fetch):

```sql
CREATE INDEX idx_projects_list ON projects (tenant_id, status, created_at DESC)
    INCLUDE (name, owner_id);
```

### GIN

For JSONB containment (`@>`, `?`), full-text search (tsvector), arrays.

## N+1 Prevention

Problem: 1 query for list + N queries for related data.

Solutions:
- **JOIN**: single SQL query with join
- **Eager loading**: Prisma `include`, EF Core `.Include()`, Drizzle `with`
- **DataLoader**: batch individual lookups into single query per tick

Detection: enable query logging, count queries per request, use APM tools, set threshold alert (>10 queries/request).

## Connection Pooling

### PgBouncer

```ini
pool_mode = transaction     # Release after each transaction (recommended)
default_pool_size = 20
min_pool_size = 5
```

### Application-Level

Node.js `pg.Pool`: max 20, min 5, idleTimeoutMillis 30000, connectionTimeoutMillis 5000. Monitor total/idle/waiting counts.
.NET EF Core: configure via `MaxPoolSize`, `MinPoolSize` on connection string.

Sizing: start with `(2 * CPU cores) + 1` for SSD. Increase if waiting count > 0 frequently.

### Connection Pool Sizing

Formula for optimal pool size per service instance:

```
pool_size = (core_count * 2) + effective_spindle_count
```

For SSDs (no spindle wait): `pool_size = (core_count * 2) + 1`. For a 4-core server: pool_size = 9. This is per-instance -- total connections = pool_size x number of instances.

**Per-service limits**: in microservices, each service gets its own pool. Total across all services must stay below `max_connections` (PostgreSQL default: 100). Reserve 5-10 connections for maintenance (pg_dump, migrations, ad-hoc queries).

```
Total connections = SUM(pool_size_per_service * instance_count_per_service) + reserved
Example: 3 services * 10 pool * 3 instances = 90. Reserve 10. max_connections >= 100.
```

**PgBouncer for connection multiplexing**: when total application connections exceed what PostgreSQL can handle efficiently (>200), put PgBouncer between application and database. PgBouncer maintains a small pool to PostgreSQL and queues excess application connections.

```ini
# PgBouncer config
[pgbouncer]
pool_mode = transaction          # release connection after each transaction
default_pool_size = 20           # connections to PostgreSQL per database
max_client_conn = 1000           # max application connections PgBouncer accepts
reserve_pool_size = 5            # emergency connections for burst traffic
reserve_pool_timeout = 3         # seconds before using reserve pool
```

**Connection limit per database role**: restrict per-role to prevent one service from consuming all connections.

```sql
ALTER ROLE api_service CONNECTION LIMIT 30;
ALTER ROLE worker_service CONNECTION LIMIT 15;
ALTER ROLE readonly_service CONNECTION LIMIT 10;
```

### Connection Leak Detection

A connection leak occurs when application code checks out a connection and never returns it (missing close/dispose, unhandled exception in transaction, forgotten `await`). Over time, the pool is exhausted and requests stall.

**Idle connection monitoring**: track connections that have been checked out but idle for longer than expected query time. Flag connections idle for >30s as potential leaks.

**Max connection lifetime**: force-close connections after a maximum age (30 min) to reclaim leaked connections and distribute load after failover.

```typescript
// Node.js pg Pool with leak detection
const pool = new Pool({
  max: 20,
  idleTimeoutMillis: 30_000,            // return idle connections after 30s
  connectionTimeoutMillis: 5_000,        // fail if no connection available in 5s
  maxLifetimeMillis: 30 * 60 * 1000,     // recycle connections after 30 min (Node pg 8.8+)
});

// Log potential leaks: connections checked out for too long
pool.on('acquire', (client) => {
  (client as any)._acquiredAt = Date.now();
});
pool.on('remove', (client) => {
  const held = Date.now() - ((client as any)._acquiredAt ?? Date.now());
  if (held > 60_000) logger.warn(`Connection held for ${held}ms — potential leak`);
});
```

```csharp
// .NET connection string with leak detection equivalent
// Minimum Pool Size=5; Maximum Pool Size=20; Connection Lifetime=1800; Connection Timeout=5;
// EF Core: log warnings for long-held DbContext
services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(connectionString)
           .EnableSensitiveDataLogging()
           .LogTo(msg => {
               if (msg.Contains("connection") && msg.Contains("timeout"))
                   logger.LogWarning(msg);
           }));
```

**HikariCP-style leak detection** (Java pattern, applicable conceptually): set `leakDetectionThreshold` (e.g., 60s). If a connection is not returned within that threshold, log a stack trace of where it was acquired. Implement in Node.js by capturing `Error().stack` at acquire time and logging it if connection is not returned within threshold.

### Connection Monitoring

Track these metrics for every connection pool:

| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| Active connections | <70% max | 70-85% max | >85% max |
| Idle connections | >20% max | 10-20% max | <10% max |
| Waiting requests | 0 | 1-5 | >5 sustained |
| Pool utilization % | <70% | 70-85% | >85% |
| Connection wait time P95 | <50ms | 50-500ms | >500ms |
| Connection errors/min | 0 | 1-3 | >3 |

```sql
-- PostgreSQL: current connection status
SELECT state, COUNT(*) FROM pg_stat_activity GROUP BY state;

-- Connections per application/role
SELECT usename, application_name, COUNT(*)
FROM pg_stat_activity WHERE backend_type = 'client backend'
GROUP BY usename, application_name ORDER BY COUNT(*) DESC;

-- Connections waiting for locks
SELECT COUNT(*) FROM pg_stat_activity WHERE wait_event_type = 'Lock';

-- Max connections vs current usage
SELECT max_conn, used, max_conn - used AS available
FROM (SELECT setting::int AS max_conn FROM pg_settings WHERE name = 'max_connections') mc,
     (SELECT COUNT(*) AS used FROM pg_stat_activity) uc;
```

**Alerting thresholds**: alert when pool utilization >85% for >2 min, when wait time P95 >500ms, when connection errors spike. Dashboard: show active/idle/waiting over time, overlay with request throughput to correlate pool exhaustion with traffic spikes.

## Materialized Views

For expensive aggregations that tolerate staleness (dashboards, reports, leaderboards):

```sql
CREATE MATERIALIZED VIEW tenant_dashboard_stats AS
SELECT tenant_id, COUNT(*) AS total_projects,
    COUNT(*) FILTER (WHERE status = 'active') AS active_projects
FROM projects GROUP BY tenant_id;

CREATE UNIQUE INDEX idx_dashboard_stats_tenant ON tenant_dashboard_stats (tenant_id);
REFRESH MATERIALIZED VIEW CONCURRENTLY tenant_dashboard_stats;
```

Refresh: scheduled (cron every 5 min), on-demand (triggered by writes), or lazy (check age on read).

## Table Partitioning

Use for >100M row tables where queries always filter by partition key.

```sql
-- Range partitioning (time-series)
CREATE TABLE events (...) PARTITION BY RANGE (created_at);
CREATE TABLE events_2025_01 PARTITION OF events FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
-- Drop old partitions for retention (instant, no DELETE overhead)
```

List partitioning for tenant-based isolation. Rules: partition key must be in PK and unique indexes, queries must include partition key for pruning.

## Query Rewriting

### Subquery to JOIN

```sql
-- Slow: correlated subquery per row
SELECT p.*, (SELECT COUNT(*) FROM tasks t WHERE t.project_id = p.id) AS task_count FROM projects p;
-- Fast: single pass
SELECT p.*, COALESCE(t.cnt, 0) FROM projects p
LEFT JOIN (SELECT project_id, COUNT(*) cnt FROM tasks GROUP BY project_id) t ON t.project_id = p.id;
```

### EXISTS over IN

```sql
-- Use EXISTS (stops at first match) instead of IN (materializes full subquery)
SELECT * FROM users u WHERE EXISTS (SELECT 1 FROM active_sessions s WHERE s.user_id = u.id);
```

### Keyset Pagination

```sql
-- Instead of OFFSET (re-scans discarded rows):
SELECT * FROM projects WHERE tenant_id = $1 AND created_at < $2
ORDER BY created_at DESC LIMIT 20;
```

### Batch Operations

```sql
UPDATE projects SET status = 'archived' WHERE id = ANY($1::uuid[]) AND tenant_id = $2;
```

## ORM Pitfalls

- EF Core: use `AsNoTracking()` for reads, `Select()` projection, avoid loading full entities for lists
- Prisma: use `select` for specific columns, `include` only needed relations, add `take`/`orderBy`
- Drizzle: filter, project, limit -- never `select().from()` without WHERE

## Monitoring

```sql
-- Enable slow query logging (PostgreSQL)
ALTER SYSTEM SET log_min_duration_statement = 100; -- >100ms

-- Top queries by total time (pg_stat_statements)
SELECT queryid, LEFT(query, 100), calls, mean_exec_time::numeric(10,2) AS avg_ms
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;

-- Cache hit ratio (should be >99%)
SELECT sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) FROM pg_statio_user_tables;

-- Unused indexes
SELECT indexname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY pg_relation_size(indexrelid) DESC;
```

Key metrics: P95 <50ms, P99 <200ms, cache hit >99%, active connections <80% max, deadlocks = 0.

## Safe Index Creation

```sql
-- PostgreSQL: CONCURRENTLY avoids table lock
CREATE INDEX CONCURRENTLY idx_projects_status ON projects (status);
-- SQL Server: WITH (ONLINE = ON)
```

Rules: always `CONCURRENTLY` in production, cannot run in transaction, check for INVALID indexes on failure, schedule during low traffic.

## Anti-Patterns

- OFFSET pagination on large datasets -- degrades linearly; use keyset pagination
- NOT IN with NULLable columns -- returns no rows when any value is NULL; use NOT EXISTS
- Too many indexes on write-heavy tables -- index maintenance overhead exceeds read benefit
- Missing indexes on foreign key columns -- slow JOINs and CASCADE operations
- Ignoring VACUUM/autovacuum -- table bloat and transaction ID wraparound

## Output Format

```
Query:             [query or endpoint being optimized]
Bottleneck:        [what EXPLAIN ANALYZE revealed]
Fix:               [index / query rewrite / eager loading / materialized view]
Before:            [execution time, rows scanned, plan type]
After:             [execution time, rows scanned, plan type]
Index:             [CREATE INDEX statement if applicable]
Production Safety: [CONCURRENTLY / ONLINE / migration approach]
```

## Done Criteria

- Slow query identified with EXPLAIN ANALYZE baseline
- Fix reduces execution time measurably (before/after documented)
- Indexes created with CONCURRENTLY/ONLINE (no table locks)
- N+1 queries eliminated (query count per request verified)
- Connection pool sized and monitored
- No unused indexes (remove after 30 days with idx_scan = 0)
- ORM-generated SQL reviewed
- Keyset pagination for large datasets
- Query timeout configured
- Slow query logging enabled
