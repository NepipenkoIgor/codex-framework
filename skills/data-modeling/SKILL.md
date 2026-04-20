---
name: data-modeling
description: Design database data models with ERD design, relationship patterns, normalization strategies, indexing, temporal data, soft deletes, and audit trails
metadata:
  version: 1.3
  argument-hint: "database type (relational/NoSQL), entities to model, relationship complexity (one-to-many/many-to-many), special features (soft deletes/audit/temporal), scale expectations"
---

Design the data model for $ARGUMENTS.

## Documentation

> Use available docs lookup tools or official docs for current PostgreSQL, SQL Server, MongoDB, or Redis docs when you need specific type syntax, function names, or extension behavior. Do not rely on training data for database-specific syntax.

## Modeling Phases

- **Conceptual**: Identify entities and relationships from business requirements; ERD with cardinality
- **Logical**: Define attributes, data types, keys; resolve many-to-many via junction tables; apply normalization; define constraints
- **Physical**: Map to specific engine features; choose data types per engine; define indexes, partitioning; plan for data volume

## Primary Key Strategies

| Strategy | Use when |
|----------|----------|
| UUID v4 | Distributed systems, public IDs |
| ULID | Need time-ordered UUIDs |
| Auto-increment integer | Single database, internal IDs |
| Composite key | Junction tables, natural keys |

- PostgreSQL: `uuid` with `gen_random_uuid()`; SQL Server: `uniqueidentifier` with `NEWSEQUENTIALID()` for clustered indexes
- Never expose auto-increment IDs externally

## Relationship Patterns

### One-to-Many

```sql
create table projects (
  id uuid default gen_random_uuid() primary key,
  org_id uuid not null references organizations(id) on delete cascade,
  name text not null
);
create index idx_projects_org_id on projects(org_id);
```

Always index foreign key columns. Choose ON DELETE behavior explicitly: CASCADE (owned children), SET NULL (optional references), RESTRICT (mandatory references).

### Many-to-Many

Use a composite primary key on the junction table. Add metadata columns (role, joined_at). Index both FK columns for lookups from either direction.

### Self-Referential

Use for trees (categories, org charts, comments). Store `depth` or materialized path for efficient queries. Consider `ltree` extension in PostgreSQL.

## Normalization vs Denormalization

**Normalize (3NF) when**: data integrity is critical; write-heavy; accessed through many query patterns.

**Denormalize when**: read-heavy with join bottlenecks; reporting/analytics; document databases where embedding is natural.

Denormalization patterns: computed columns (`GENERATED ALWAYS AS ... STORED`), materialized views with `REFRESH CONCURRENTLY`, summary columns maintained by triggers or application logic.

## Indexing Strategy

- Index every foreign key column
- Index columns in WHERE clauses of frequent queries
- Index columns in ORDER BY for sorted queries
- Composite indexes: most selective column first
- Partial indexes for filtered subsets: `WHERE status = 'active'`
- Unique indexes for business constraints at database level
- Use `CONCURRENTLY` for index creation on live tables

| Type | Use case | PostgreSQL |
|------|----------|------------|
| B-tree | Equality, range, sorting (default) | `CREATE INDEX` |
| GIN | Arrays, JSONB, full-text search | `USING gin` |
| GiST | Geometry, range types | `USING gist` |
| BRIN | Large sequential data (timestamps) | `USING brin` |

Anti-patterns: over-indexing; indexing low-cardinality columns alone; redundant indexes.

## Temporal Data

### Effective Dating

Use `effective_from`/`effective_to` columns for price history, SLA windows. Use EXCLUSION constraints to prevent overlapping periods: `exclude using gist (product_id with =, tstzrange(effective_from, effective_to, '[)') with &&)`.

### SCD Type 2

Track historical records with `valid_from`, `valid_to`, `is_current`. Partial index on `WHERE is_current = true` for performance.

## Soft Delete

```sql
alter table projects add column deleted_at timestamptz;
create index idx_projects_active on projects(org_id, created_at desc) where deleted_at is null;
-- Unique email only among active records
create unique index idx_users_email_active on users(email) where deleted_at is null;
```

Set a retention policy: hard-delete records older than N days via scheduled job.

## Audit Trail

Key columns: `table_name`, `record_id`, `action` (INSERT/UPDATE/DELETE), `old_data jsonb`, `new_data jsonb`, `performed_by`, `performed_at`, `ip_address`.

Rules:
- Audit tables containing business-critical or regulated data
- Store old and new values for UPDATE operations
- Partition audit tables by date for manageability
- Retention: 1-7 years depending on regulatory requirements
- Never allow UPDATE or DELETE on audit_log (append-only)

## JSONB Columns (PostgreSQL)

When to use: schema-flexible metadata, event payloads, configuration data with varying shape.

When NOT to use: data needing relational integrity; frequently filtered columns; primary query targets.

```sql
create index idx_products_metadata on products using gin(metadata);
create index idx_products_color on products((metadata->>'color'));
```

Use JSONB over JSON (binary storage, indexable). Validate shape at application level (Zod, JSON Schema).

## MongoDB Document Design

| Pattern | Use when |
|---------|----------|
| Embed | Always accessed together, bounded size (order with line items) |
| Reference | Accessed independently, unbounded growth (user with posts) |
| Hybrid | Embed summary, reference full data (comment with embedded author name) |

Index fields used in queries, sorts, and aggregations. Use `{ unique: true }` for business uniqueness. Use partial indexes with `partialFilterExpression`.

## Redis Data Structure Design

| Structure | Use case |
|-----------|----------|
| String | Cache, counters |
| Hash | Object with fields |
| List | Queue, recent items |
| Set | Tags, unique membership |
| Sorted Set | Leaderboard, time-series |
| Stream | Event log, message queue |

Key naming: `entity:id:field` with namespace prefixes (`cache:`, `session:`, `lock:`). Set TTL on every key unless persistent state.

## Constraints and Validation

Enforce at the database level, not just the application level:
- NOT NULL for required values
- CHECK for enums, ranges, format validation
- UNIQUE (partial for soft-delete scenarios)
- EXCLUSION for non-overlapping ranges
- FOREIGN KEY with explicit ON DELETE behavior

## Anti-Patterns

- EAV for structured data — use JSONB or proper schema instead
- FLOAT for monetary values — use NUMERIC/DECIMAL
- Nullable boolean columns — three-state logic is a persistent source of bugs
- Missing ON DELETE behavior on foreign keys
- No constraints at the DB level

## Output Format

For each data model:
- Primary key strategy with rationale
- Relationships with explicit ON DELETE behavior
- Index types and partial index filters
- Constraints (NOT NULL, CHECK, UNIQUE, EXCLUSION)
- Temporal/audit/soft-delete approach
- Expected access patterns and how the model supports them
- Data type choices with rationale (especially dates, money, identifiers)
