---
name: distributed-coordination
description: Implement distributed coordination patterns including distributed locks, leader election, job deduplication, and coordinated scheduling for .NET and Node
metadata:
  version: 1.3
  argument-hint: "coordination pattern (lock/leader election/deduplication), backend framework (Node.js/ASP.NET), coordination backend (Redis/etcd), scale/cluster size, consistency requirements"
---

Implement distributed coordination for $ARGUMENTS.


## Pattern Selection

| Problem | Pattern | Tool |
|---------|---------|------|
| Only one instance processes a resource at a time | Distributed lock | Redis (Redlock), PostgreSQL advisory locks |
| Only one instance runs a scheduled job | Leader election | Redis, PostgreSQL, Kubernetes lease |
| Prevent processing the same event twice | Idempotency / deduplication | Redis SET NX, database unique constraint |
| Only one instance runs a cron job | Single-leader scheduling | Database-claimed jobs, Redis lock |
| Coordinate shutdown across instances | Graceful coordination | Redis pub/sub, health check deregistration |
| Partition work across instances | Work distribution | Consistent hashing, queue-based partitioning |

Decision guide:
- Short operation (<30s), mutual exclusion → Redis distributed lock
- Mutual exclusion with DB transaction → PostgreSQL advisory lock
- Ongoing single-leader responsibility → Leader election
- Prevent duplicate event processing → Idempotency key (SET NX or DB constraint)
- Single cron instance → Single-leader scheduling
- No Redis → PostgreSQL advisory locks cover most cases

## Distributed Locks

### Redis Distributed Lock (Single Instance)

```typescript
async function acquireLock(options: { key: string; ttlMs: number; retryCount?: number; retryDelayMs?: number }): Promise<{ acquired: boolean; token: string }> {
  const token = crypto.randomUUID();
  const { key, ttlMs, retryCount = 3, retryDelayMs = 200 } = options;

  for (let attempt = 0; attempt <= retryCount; attempt++) {
    const result = await redis.set(`lock:${key}`, token, 'PX', ttlMs, 'NX');
    if (result === 'OK') return { acquired: true, token };
    if (attempt < retryCount)
      await new Promise((r) => setTimeout(r, retryDelayMs + Math.random() * retryDelayMs));
  }
  return { acquired: false, token: '' };
}

async function releaseLock(key: string, token: string): Promise<boolean> {
  const script = `if redis.call("get",KEYS[1])==ARGV[1] then return redis.call("del",KEYS[1]) else return 0 end`;
  return (await redis.eval(script, 1, `lock:${key}`, token)) === 1;
}

async function processExclusively(resourceId: string, handler: () => Promise<void>): Promise<void> {
  const lock = await acquireLock({ key: `resource:${resourceId}`, ttlMs: 30_000 });
  if (!lock.acquired) throw new Error(`Could not acquire lock for: ${resourceId}`);
  try { await handler(); } finally { await releaseLock(`resource:${resourceId}`, lock.token); }
}
```

### Lock Renewal

For operations exceeding initial TTL: acquire lock, renew every TTL/3 via atomic script check (verify token before extending), release in finally. Cancel renewal on failure to extend (lock lost).

### Fencing Tokens

Prevent stale lock holders from making writes after their lock expired.

```typescript
async function acquireLockWithFence(key: string, ttlMs: number): Promise<{ token: string; fenceToken: number } | null> {
  const token = crypto.randomUUID();
  const fenceToken = await redis.incr(`fence:${key}`);
  const acquired = await redis.set(`lock:${key}`, `${token}:${fenceToken}`, 'PX', ttlMs, 'NX');
  return acquired === 'OK' ? { token, fenceToken } : null;
}

async function writeWithFence(resourceId: string, fenceToken: number, data: unknown): Promise<boolean> {
  const result = await db.query(
    'UPDATE resources SET data=$1, fence_token=$2, updated_at=NOW() WHERE id=$3 AND fence_token<$2',
    [data, fenceToken, resourceId],
  );
  return result.rowCount > 0;
}
```

Rules:
- Use fencing tokens when locked operation writes to external store
- External store must reject writes where fence token < last seen token
- Without fencing, a slow lock holder can overwrite data after lock expired

### Redis Redlock (Multi-Instance)

```typescript
import Redlock from 'redlock';
const redlock = new Redlock([redisClient1, redisClient2, redisClient3], { driftFactor: 0.01, retryCount: 3, retryDelay: 200, retryJitter: 200 });

async function processWithRedlock(resourceId: string): Promise<void> {
  const lock = await redlock.acquire([`resource:${resourceId}`], 30_000);
  try { await processResource(resourceId); } finally { await lock.release(); }
}
```

- Single instance: sufficient when Redis has Sentinel/managed failover
- Redlock (3–5 independent instances): when lock loss during Redis failover is unacceptable

### PostgreSQL Advisory Locks

Use `pg_advisory_xact_lock()` within a transaction for DB-level mutual exclusion. Guaranteed release on connection drop; no TTL needed. Best when: lock guards DB transaction; no Redis available.

### .NET: DistributedLock Library

```csharp
// Redis or PostgreSQL provider
var lockProvider = new RedisDistributedSynchronizationProvider(ConnectionMultiplexer.Connect("localhost").GetDatabase());
// or: new PostgresDistributedSynchronizationProvider(connectionString);

await using var handle = await lockProvider.TryAcquireLockAsync($"resource:{resourceId}", timeout: TimeSpan.FromSeconds(10), cancellationToken: ct);
if (handle == null) throw new InvalidOperationException("Could not acquire lock");
await ProcessResourceAsync(resourceId, ct);
// Released automatically via IAsyncDisposable
```

## Leader Election

### Redis-Based Leader Election

Attempt election every TTL/3. On election (SET NX succeeds): trigger onElected callback. On renewal failure or TTL expiry: trigger onDemoted. Release leadership on shutdown with atomic script check. On SIGTERM: call stop() to resign leadership gracefully.

### PostgreSQL-Based Leader Election

Use UPSERT with TTL check: INSERT, ON CONFLICT UPDATE where expires_at < NOW() or instance_id matches. Attempt election every TTL/3. Benefits: no external store; integrated with transaction.

### Kubernetes Lease (.NET BackgroundService)

```csharp
public class LeaderElectionService : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        await _election.RunAsync(async leaderCt =>
        {
            while (!leaderCt.IsCancellationRequested)
            {
                await RunScheduledJobsAsync(leaderCt);
                await Task.Delay(TimeSpan.FromMinutes(1), leaderCt);
            }
        }, ct);
    }
}
```

## Job Deduplication

### Job Deduplication Patterns

**Redis SET NX**: fast dedup with TTL (86400s). SET fails if key exists → duplicate. On success, run handler in try/finally; delete key on error to allow retry.

**Database unique constraint**: INSERT processed_events with PRIMARY KEY on event_id; ON CONFLICT DO NOTHING. Query first to return cached result. Survives Redis loss.

**Idempotency key API**: cache full response (status + body) in Redis via idempotency-key header. Return cached response if hit. TTL >= 24 hours.

## Coordinated Scheduling

### Single-Leader Cron

```typescript
election.start('cron-leader', 15_000,
  () => { cron.schedule('0 9 * * *', generateDailyReport); cron.schedule('*/5 * * * *', processStaleJobs); },
  () => { cron.getTasks().forEach((t) => t.stop()); },
);
```

### Database-Claimed Jobs

Query scheduled_jobs where enabled AND next_run_at <= NOW() AND (claimed_by IS NULL OR claimed_at < NOW()-5m). UPDATE to claim with instanceId. Multiple instances run same loop every 30s; each claims different jobs. No leader election needed — one-per-job mutual exclusion via claimed_by. After execution, reset claimed_by and compute next_run_at.

## Consensus Patterns

### When You Need Consensus
- Distributed state machine replication (Raft, Paxos)
- Strongly consistent distributed configuration (etcd, ZooKeeper)
- Building a custom distributed database

### When You Do NOT Need Consensus

| Problem | Use Instead |
|---------|-------------|
| Mutual exclusion | Distributed lock (Redis, PostgreSQL) |
| Single leader | Leader election (Redis, PostgreSQL, K8s lease) |
| Event ordering | Message queue with partition key (Kafka) |
| Duplicate prevention | Idempotency keys (Redis SET NX, DB unique constraint) |
| Configuration | Config service (SSM, Vault) or shared database |

Rules:
- Prefer Redis/PostgreSQL coordination over consensus protocols for application-level problems
- Use etcd or ZooKeeper only for infrastructure-level consensus
- Raft/Paxos are for building distributed systems, not application features

## Common Pitfalls

| Pitfall | Mitigation |
|---------|-----------|
| **Split-brain** — two leaders simultaneously | Fencing tokens; short TTLs with TTL/3 renewal; monitor for dual-leader |
| **Lock expiry during processing** — another instance starts | Lock renewal; fencing tokens; TTL ≥ 3× expected processing time |
| **Clock skew** — affects TTL decisions | NTP sync; use server-side time (Redis PEXPIRE, PostgreSQL NOW()); add Redlock drift factor |
| **Thundering herd** — all waiters retry at once | Jitter on retry delay; exponential backoff; queue-based distribution |
| **Stale lock on crash** — lock never released | Always set TTL; session-level PG advisory locks auto-release; `finally` blocks |

## Monitoring

| Metric | Alert Threshold | Description |
|--------|----------------|-------------|
| Lock acquisition time P95 | > 1s | Waiting too long to acquire |
| Lock hold time P95 | > 80% of TTL | Processing too long vs TTL |
| Lock contention rate | > 20% fail | Too much competition |
| Leader failover count | > 1/hour | Instability indicator |
| Dedup hit rate | Monitor trend | High rate = upstream retry storm |
| Lock expiry during processing | > 0 | Critical: lock lost while running |
| Dual-leader events | > 0 | Critical: split-brain |

```typescript
app.get('/health', (req, res) => res.json({ status: 'ok', isLeader: election.getIsLeader(), instanceId, uptime: process.uptime() }));
```

## Testing Distributed Coordination

```typescript
describe('distributed lock', () => {
  it('acquires when free', async () => expect((await acquireLock({ key: 'r', ttlMs: 5000 })).acquired).toBe(true));
  it('fails when held', async () => {
    await acquireLock({ key: 'r', ttlMs: 5000 });
    expect((await acquireLock({ key: 'r', ttlMs: 5000, retryCount: 0 })).acquired).toBe(false);
  });
  it('releases so another can acquire', async () => {
    const first = await acquireLock({ key: 'r', ttlMs: 5000 });
    await releaseLock('r', first.token);
    expect((await acquireLock({ key: 'r', ttlMs: 5000 })).acquired).toBe(true);
  });
  it('does not release lock held by another token', async () => {
    await acquireLock({ key: 'r', ttlMs: 5000 });
    expect(await releaseLock('r', 'wrong-token')).toBe(false);
  });
});

describe('deduplication under concurrency', () => {
  it('processes event exactly once', async () => {
    let count = 0;
    const results = await Promise.all(Array.from({ length: 10 }, () => processOnce('evt-123', async () => { count++; })));
    expect(results.filter(Boolean).length).toBe(1);
    expect(count).toBe(1);
  });
});
```

## Anti-Patterns

- `SETNX` + separate `EXPIRE` (non-atomic) -- crash between the two leaves lock without TTL permanently
- Releasing lock without ownership verification -- any holder can accidentally release another's lock
- Using process PID as lock token -- PIDs are reused after crash, enabling false ownership
- No fencing tokens when writing to external stores -- stale lock holder can overwrite newer writes
- `SELECT ... FOR UPDATE` as a distributed lock across separate DB transactions -- not cross-service

## Implementation Workflow

1. Identify the coordination problem: mutual exclusion, leader election, deduplication, or scheduling
2. Choose pattern and backing store (Redis, PostgreSQL, Kubernetes)
3. Implement with TTL, ownership verification, and atomic operations
4. Add lock renewal for operations that may exceed initial TTL
5. Add fencing tokens if locked operation writes to external stores
6. Implement monitoring for contention, hold time, and failover events
7. Write tests: acquisition, release, contention, crash recovery, failover
8. Add graceful shutdown: release locks, resign leadership on SIGTERM
9. Document the coordination contract: which resources are protected, expected hold times, retry behavior

## Output Format

```
Pattern:           [distributed lock / leader election / deduplication / coordinated scheduling]
Backing Store:     [Redis / PostgreSQL / Kubernetes lease / etcd]
TTL:               [lock TTL and renewal interval]
Fencing:           [fencing token approach, if applicable]
Failover:          [how leadership or lock transfers on failure]
Monitoring:        [metrics tracked and alert thresholds]
Testing:           [concurrency and failure scenarios tested]
```

## Done Criteria

- Locks have TTL and are released in `finally` blocks
- Lock release verifies ownership atomically
- Leader election handles failover within 1–2 TTL cycles
- Deduplication prevents double-processing under concurrent attempts
- Fencing tokens protect external writes from stale lock holders
- Monitoring tracks lock contention, hold time, and leader failover events
- Graceful shutdown releases locks and resigns leadership
- Tests cover: acquisition, contention, crash recovery, concurrent deduplication
- No possibility of permanent deadlock (all locks have TTL)
- Clock skew accounted for with drift factor or server-side timing
