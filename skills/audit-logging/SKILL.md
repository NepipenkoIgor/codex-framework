---
name: audit-logging
description: Implement immutable audit logging for compliance tracking including who-what-when-why recording, PII redaction, retention policies, query and search patterns, legal hold, and SOC2/HIPAA/GDPR audit trail requirements
metadata:
  version: 1.3
  argument-hint: "system type, events to audit, retention policy, compliance standard (SOC2/HIPAA/PCI)"
---

Implement audit logging for $ARGUMENTS.


## Audit Event Schema

```typescript
interface AuditEvent {
  id: string;               // UUID
  timestamp: string;        // ISO 8601 UTC
  sequence_number: number;  // monotonically increasing per tenant

  actor: { id: string; type: 'user' | 'system' | 'api_key' | 'service'; email?: string; name?: string; ip_address?: string; user_agent?: string; };
  action: string;           // verb: 'created', 'updated', 'deleted', 'exported', 'viewed', 'logged_in'
  category: string;         // domain: 'auth', 'billing', 'data', 'admin', 'security'
  resource: { type: string; id: string; name?: string; };

  context: { tenant_id: string; request_id?: string; session_id?: string; source: string; environment: string; };
  changes?: { before: Record<string, unknown>; after: Record<string, unknown>; diff: FieldChange[]; };
  metadata?: Record<string, unknown>;
  reason?: string;
}

interface FieldChange { field: string; old_value: unknown; new_value: unknown; redacted: boolean; }
```

## Database Schema (PostgreSQL)

```sql
CREATE TABLE audit_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id UUID NOT NULL,
  sequence_number BIGINT GENERATED ALWAYS AS IDENTITY,
  actor_id TEXT NOT NULL,
  actor_type TEXT NOT NULL CHECK (actor_type IN ('user', 'system', 'api_key', 'service')),
  actor_email TEXT, actor_ip TEXT,
  action TEXT NOT NULL, category TEXT NOT NULL,
  resource_type TEXT NOT NULL, resource_id TEXT NOT NULL, resource_name TEXT,
  request_id TEXT, session_id TEXT,
  source TEXT NOT NULL DEFAULT 'web', environment TEXT NOT NULL DEFAULT 'production',
  changes JSONB, metadata JSONB DEFAULT '{}', reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
) PARTITION BY RANGE (created_at);

-- Partition by month, create 3 months ahead, use pg_partman for automation
CREATE TABLE audit_logs_2025_01 PARTITION OF audit_logs FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE INDEX idx_audit_tenant_created ON audit_logs (tenant_id, created_at DESC);
CREATE INDEX idx_audit_actor ON audit_logs (actor_id, created_at DESC);
CREATE INDEX idx_audit_resource ON audit_logs (resource_type, resource_id, created_at DESC);
CREATE INDEX idx_audit_action ON audit_logs (action, created_at DESC);
CREATE INDEX idx_audit_metadata ON audit_logs USING gin (metadata);
```

## Immutability

```sql
CREATE OR REPLACE FUNCTION prevent_audit_modification() RETURNS TRIGGER AS $$
BEGIN RAISE EXCEPTION 'Audit log records cannot be modified or deleted'; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_no_update BEFORE UPDATE ON audit_logs FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();
CREATE TRIGGER audit_no_delete BEFORE DELETE ON audit_logs FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();
```

Application: expose only `log()` and `query()` — no `update()` or `delete()`.

For tamper-proof long-term retention: S3 Object Lock (Compliance mode) or Azure Immutable Blob Storage. Export monthly partitions before dropping.

## PII Redaction

```typescript
const PII_FIELDS = new Set(['email', 'actor_email', 'phone', 'ssn', 'ip_address', 'actor_ip', 'address', 'date_of_birth']);

function redactPII(value: unknown, fieldName: string): unknown {
  if (!PII_FIELDS.has(fieldName)) return value;
  if (typeof value !== 'string') return '[REDACTED]';
  if (fieldName === 'email') { const [local, domain] = value.split('@'); return `${local[0]}***@${domain}`; }
  if (fieldName === 'ip_address' || fieldName === 'actor_ip') return value.replace(/\.\d+$/, '.***');
  return '[REDACTED]';
}
```

**GDPR Right to Erasure**: redact PII fields in-place (UPDATE actor_email = '[ERASED]'), never delete the audit record itself. Record the erasure as its own audit event. Keep action/resource/timestamp intact.

**Tokenization** (full PII removal): store encrypted value in separate `audit_pii_tokens` table, replace field with `pii:<uuid>` token. Detokenize only for authorized compliance queries.

## Retention Policies

| Framework | Hot (DB) | Cold (Archive) | Total |
|-----------|----------|----------------|-------|
| SOC2 | 1 year | +2 years | 3 years |
| HIPAA | 1 year | +5 years | 6–7 years |
| PCI DSS | 1 year | +2 years | 3 years |
| SOX | 1 year | +6 years | 7 years |
| General SaaS | 90 days | +2 years | 2–3 years |

Drop partitions (instant, no locks) rather than DELETE for retention. Archive to S3 with Object Lock before dropping. Category-based policies: security 7yr, billing 7yr, auth 3yr, data 2yr.

## Async Writing (Never Block Requests)

```typescript
class AuditBatchWriter {
  private buffer: AuditEventInput[] = [];
  private readonly batchSize = 100;

  async log(event: AuditEventInput): Promise<void> {
    this.buffer.push(event);
    if (this.buffer.length >= this.batchSize) await this.flush();
  }

  async flush(): Promise<void> {
    if (!this.buffer.length) return;
    const batch = this.buffer.splice(0);
    try {
      await this.db.query(`INSERT INTO audit_logs (...) SELECT * FROM unnest($1::uuid[], ...)`, transposeToArrays(batch));
    } catch (err) {
      await writeFallback(batch); // file or secondary queue — never lose events
    }
  }
}
```

For >1000 events/sec: queue-based (BullMQ/Redis). Never add >5ms latency to user requests. Always have a fallback. Never fail the user's request because audit logging failed.

## Middleware / Interceptors

**Node.js**: intercept `res.finish`, log on 2xx only. Never throw in audit middleware.

```typescript
// Usage
app.delete('/api/projects/:id', authMiddleware,
  auditMiddleware({ category: 'data', action: 'deleted', resourceExtractor: (req) => ({ type: 'project', id: req.params.id }) }),
  deleteProjectHandler);

// Auto-audit all mutations
const action = { POST: 'created', PUT: 'updated', PATCH: 'updated', DELETE: 'deleted' }[req.method]!;
```

**.NET Action Filter**:
```csharp
[Audit(Action = "deleted", Category = "data", ResourceType = "project", ResourceIdParam = "id")]
[HttpDelete("projects/{id}")]
public async Task<IActionResult> DeleteProject(Guid id, CancellationToken ct) { ... }
```

## Change Tracking

```typescript
function computeChanges(before: Record<string, unknown>, after: Record<string, unknown>): AuditChanges {
  const allKeys = new Set([...Object.keys(before), ...Object.keys(after)]);
  const diff: FieldChange[] = [];

  for (const key of allKeys) {
    if (['updated_at', 'version', 'etag'].includes(key)) continue;
    if (JSON.stringify(before[key]) === JSON.stringify(after[key])) continue;
    diff.push({ field: key, old_value: redactPII(before[key], key), new_value: redactPII(after[key], key), redacted: PII_FIELDS.has(key) });
  }

  return { before: redactObject(before), after: redactObject(after), diff };
}
```

.NET: use reflection over `typeof(T).GetProperties()`, skip ignored fields, compare with `Equals()`.

## Query Patterns

```sql
-- By actor
SELECT * FROM audit_logs WHERE actor_id = $1 AND created_at > NOW() - INTERVAL '30 days' ORDER BY created_at DESC LIMIT 50;
-- By resource
SELECT * FROM audit_logs WHERE resource_type = $1 AND resource_id = $2 ORDER BY created_at DESC LIMIT 50;
-- Security events
SELECT * FROM audit_logs WHERE tenant_id = $1 AND category = 'security'
  AND action IN ('login_failed', 'permission_changed', 'data_exported', 'mfa_disabled')
  AND created_at > NOW() - INTERVAL '7 days' ORDER BY created_at DESC;
-- JSONB field diff
SELECT * FROM audit_logs WHERE changes @> '{"diff": [{"field": "status"}]}';
```

API: `GET /api/audit-logs?actor_id=&resource_type=&action=&from=&to=&cursor=&limit=50`

Use **cursor-based pagination** (not offset) for append-only data:
```typescript
// Cursor: { timestamp, id } — WHERE (created_at, id) < ($cursor.timestamp, $cursor.id)
const limit = Math.min(filter.limit ?? 50, 200);
const hasMore = rows.length > limit;
const nextCursor = hasMore ? { timestamp: items.at(-1).created_at, id: items.at(-1).id } : null;
```

## Activity Feed

```sql
SELECT a.action, a.resource_type, a.resource_name, u.name AS actor_name,
  u.avatar_url, a.changes->'diff' AS changes, a.created_at
FROM audit_logs a LEFT JOIN users u ON u.id = a.actor_id::uuid
WHERE a.tenant_id = $1 AND a.resource_type = 'project' AND a.resource_id = $2
  AND a.action NOT IN ('viewed')
ORDER BY a.created_at DESC LIMIT 20;
```

Format: `'{actor} created project "{resource_name}"'` — template per action type.

## Legal Hold

```sql
CREATE TABLE legal_holds (id UUID PRIMARY KEY, tenant_id UUID NOT NULL, name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', hold_criteria JSONB NOT NULL,
  created_by TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT now(), released_at TIMESTAMPTZ);

CREATE TABLE legal_hold_records (id UUID PRIMARY KEY,
  legal_hold_id UUID NOT NULL REFERENCES legal_holds(id),
  audit_log_id UUID NOT NULL, UNIQUE (legal_hold_id, audit_log_id));
```

Rules: legal holds override retention — held records are never deleted. Only legal/compliance roles can create/release. Releasing doesn't delete — it allows normal retention. Check `legal_hold_records` before dropping any partition.

## Compliance Event Mapping

**SOC2**: CC6.1 → login/logout/login_failed/mfa_enabled | CC6.2 → user_created/role_assigned | CC7.1 → setting_changed/deployment_completed

**HIPAA**: All PHI access (viewed/created/updated/exported) + all modifications with before/after + all transmissions/exports

**GDPR**: consent_granted/withdrawn | data_access_request_* | data_erased/pii_redacted | data_export_* | breach_detected/reported

Compliance report: for each criteria, query event counts in period, flag gaps where required events have zero records.

## Anti-Patterns

- Using row DELETE for retention -- drops individual rows instead of partition-level cleanup
- No legal hold mechanism -- retention policies delete records under active investigation
- No indexes on tenant_id, actor_id, resource -- compliance queries become full table scans
- No fallback when audit write fails -- request succeeds but the action goes unrecorded
- Synchronous audit writes blocking request path -- adds latency to every mutating operation

## Workflow

1. Design event schema for target compliance frameworks
2. Create partitioned table with immutability triggers
3. Implement service with batch writing and queue fallback
4. Add PII redaction; build middleware/interceptors for automatic audit on mutations
5. Implement change tracking (before/after diff)
6. Query API with cursor pagination; retention policies + archival; legal hold
7. Compliance report generator; monitor write latency/volume/failures

Done: ✓ records immutable (UPDATE/DELETE blocked at DB) ✓ every mutation creates audit record ✓ before/after snapshots with computed diffs ✓ PII redacted/tokenized ✓ retention hot/cold/archive lifecycle ✓ legal hold prevents deletion ✓ cursor-based pagination ✓ audit writes <5ms latency ✓ fallback prevents data loss
