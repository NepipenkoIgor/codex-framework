---
name: multi-tenancy-design
description: Design multi-tenant architecture covering tenant isolation, data partitioning, row-level security, schema-per-tenant, shared database patterns, tenant provisioning, and cross-tenant operations
metadata:
  version: 1.2
  argument-hint: "isolation strategy (shared DB/schema/database), tenant count, compliance/residency requirements, SaaS tier model"
---

Design and implement multi-tenant architecture for $ARGUMENTS with proper isolation, security, and scalability.


## Isolation Strategy

| Strategy | Isolation | Cost | Best for |
|----------|----------|------|----------|
| Shared DB + RLS | Low-medium | Lowest | Most SaaS, startups, rapid scaling |
| Schema-per-tenant | Medium-high | Medium | Compliance needs, moderate count |
| DB-per-tenant | Highest | Highest | Regulated industries, enterprise |
| Hybrid | Variable | Variable | Mixed tiers (free=shared, enterprise=isolated) |

Decision: starting SaaS -> shared DB + RLS. Compliance isolation (SOC2, HIPAA) -> schema or DB per tenant. Mixed tiers -> hybrid. >100 tenants -> shared DB or schema (DB-per-tenant gets expensive).

## Shared Database with RLS

### Schema Design

Every tenant-scoped table includes `tenant_id`:

```sql
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_projects_tenant_id ON projects (tenant_id);
CREATE INDEX idx_projects_tenant_created ON projects (tenant_id, created_at DESC);
```

### PostgreSQL RLS

```sql
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON projects
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid);
CREATE POLICY tenant_insert ON projects FOR INSERT
    WITH CHECK (tenant_id = current_setting('app.current_tenant_id')::uuid);
CREATE POLICY service_bypass ON projects
    USING (current_setting('app.role', true) = 'service');
```

For Supabase: use `auth.jwt() ->> 'tenant_id'` instead of `current_setting`. Service role key bypasses RLS by default.

### Setting Tenant Context

Node.js: `SET LOCAL app.current_tenant_id = '...'` per connection.
.NET: use `DbCommandInterceptor` to prepend `SET LOCAL` before each command.

## Tenant Context Propagation

### Middleware (Node.js / NestJS)

Resolve tenant from JWT claim, custom header, or subdomain. Attach to request. Reject if missing.

### AsyncLocalStorage (Node.js)

```typescript
export const tenantStore = new AsyncLocalStorage<TenantContext>();

// Middleware: tenantStore.run(context, next);
// Access: tenantStore.getStore() anywhere in the request
```

### .NET Scoped Provider

```csharp
public interface ITenantProvider { Guid GetCurrentTenantId(); }

// Resolve from HttpContext.User claims, register as Scoped
services.AddScoped<ITenantProvider, HttpTenantProvider>();
```

## EF Core Global Query Filters

```csharp
modelBuilder.Entity<Project>()
    .HasQueryFilter(p => p.TenantId == _tenantProvider.GetCurrentTenantId());

// Apply to all ITenantScoped entities in a loop
// Bypass for admin: Set<T>().IgnoreQueryFilters()
```

## Schema-Per-Tenant

Use when: regulatory data separation needed, custom schema extensions, 10-500 tenants.

- `CREATE SCHEMA tenant_acme;` with tables inside
- `SET search_path TO tenant_acme, public;` per request
- Apply migrations to ALL schemas on deploy (iterate, handle failures per-schema without blocking others)

## Database-Per-Tenant

Use when: strictest isolation (healthcare, finance), data residency, large tenants needing dedicated resources, <50 tenants.

- Connection pool per tenant with lazy initialization
- Trade-offs: highest cost, ops burden multiplied by tenant count, cross-tenant queries require federation/ETL

## Tenant Provisioning

```
Signup -> Create tenant record -> Provision infrastructure:
  Shared DB: insert tenant_id, seed reference data
  Schema: CREATE SCHEMA, apply migrations, seed
  DB: provision database, migrations, configure access
-> Create admin user -> Apply default settings -> Welcome email
```

### Tenant Record

```sql
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    plan TEXT NOT NULL DEFAULT 'free',
    status TEXT NOT NULL DEFAULT 'active',
    settings JSONB NOT NULL DEFAULT '{}',
    limits JSONB NOT NULL DEFAULT '{"max_users": 5, "max_storage_mb": 100}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
```

Seed per tenant: default roles (admin/member/viewer), default settings (timezone, locale, notifications).

## Cross-Tenant Operations (Admin)

- Admin endpoints bypass tenant scoping with explicit admin role verification
- .NET: `IgnoreQueryFilters()` with `[Authorize(Policy = "PlatformAdmin")]`
- NestJS: `@UseGuards(AdminGuard)` with explicit tenant parameter
- Log all cross-tenant access for audit
- Never expose cross-tenant data to non-admin users

## Billing and Limits

### Usage Tracking

```sql
CREATE TABLE tenant_usage (
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    metric TEXT NOT NULL,
    value BIGINT NOT NULL,
    period_start DATE NOT NULL,
    UNIQUE (tenant_id, metric, period_start)
);
```

### Limit Enforcement

Check current usage against tenant's plan limits before allowing resource creation. Throw `PaymentRequiredError` when limit reached. Track usage asynchronously (background job), aggregate per billing period, sync to billing provider (Stripe metered billing).

## Testing

```typescript
it('tenant A cannot see tenant B projects', async () => {
  await asTenant(tenantB, () => createProject(tenantB, 'Secret'));
  const results = await asTenant(tenantA, () => db.query('SELECT * FROM projects'));
  expect(results.rows).toHaveLength(0);
});

it('tenant A cannot update tenant B data', async () => {
  const id = await createProject(tenantB, 'Protected');
  const result = await asTenant(tenantA, () =>
    db.query('UPDATE projects SET name = $1 WHERE id = $2', ['Hacked', id]));
  expect(result.rowCount).toBe(0); // RLS blocks
});
```

Checklist: A cannot read/update/delete B's data, A cannot insert with B's tenant_id, admin can cross-tenant with authorization, provisioning creates all resources, deletion prevents access but preserves data, limits enforced, background jobs respect tenant context.

## Anti-Patterns

- Application-level filtering only without DB enforcement (RLS/global query filters) -- one missed filter = data leak
- Global caches without tenant namespacing -- cache poisoning across tenant boundaries
- Storing tenant context in global/static variables -- bleeds into concurrent requests
- Bypassing RLS without an explicit admin guard -- accidental cross-tenant exposure
- Synchronous provisioning in the signup request -- slow onboarding and partial failures are hard to recover

## Output Format

```
Strategy:          [shared DB + RLS / schema-per-tenant / DB-per-tenant / hybrid]
Isolation:         [database-level enforcement mechanism]
Context:           [how tenant propagated through request]
Provisioning:      [onboarding flow and seed data]
Limits:            [per-tenant enforcement approach]
Admin Access:      [cross-tenant mechanism with audit]
Billing:           [usage tracking approach]
Testing:           [isolation test strategy]
```

## Done Criteria

- Every tenant-scoped table has tenant_id with index
- Database-level isolation enforced (RLS or global query filters)
- Tenant context propagated automatically via middleware
- No query returns other tenant's data without admin bypass
- Provisioning automated with all required resources
- Limits enforced per plan
- Cross-tenant admin ops require authorization and are logged
- Isolation tested: read, write, update, delete across boundaries
- Caches, queues, background jobs include tenant context
- Soft delete prevents access without losing data
