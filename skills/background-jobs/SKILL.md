---
name: background-jobs
description: Implement background job processing using BullMQ, Agenda, node-cron, Hangfire, or framework-native job systems
metadata:
  version: 1.5
  argument-hint: "job type (email/batch/scheduled), framework/platform (BullMQ/Hangfire/Agenda), retry strategy, concurrency limits, monitoring requirements"
---

Implement background job processing for $ARGUMENTS.

## Tool Integration

- **Language diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone


## Queue Technology Selection

| Technology | Runtime | Best for | Backing store |
|------------|---------|----------|---------------|
| BullMQ | Node.js | General purpose, high throughput | Redis |
| Hangfire | .NET | Full-featured, dashboard, recurring | SQL Server / Redis |
| pg-boss | Node.js | PostgreSQL-native queue | PostgreSQL |
| BackgroundService | .NET | Simple hosted services | In-memory |
| MassTransit | .NET | Message bus with sagas | RabbitMQ / Azure SB |

Decision: Redis available -> BullMQ/Hangfire. PostgreSQL only -> pg-boss. Simple cron -> node-cron/BackgroundService. Sagas -> MassTransit.

## Job Patterns

**Fire-and-forget**: enqueue, worker processes when available. Best for emails, reports, uploads.

**Delayed**: execute after specified delay. Best for reminders, follow-ups, cooldowns.

**Recurring**: cron schedule. Best for daily reports, cleanup, sync jobs.

**Chaining**: sequential jobs where each depends on previous. Use BullMQ FlowProducer or Hangfire ContinueJobWith.

**Priority**: lower number = higher priority. For paid-tier processing, urgent notifications.

```typescript
// BullMQ examples
await queue.add('send-welcome', { userId, email, templateId: 'welcome' });
await queue.add('send-reminder', { userId }, { delay: 30 * 60 * 1000 });
await reportQueue.upsertJobScheduler('daily-report', { pattern: '0 9 * * *' }, { name: 'generate-daily-report' });
await queue.add('process', data, { priority: 1 }); // high priority
```

```csharp
// Hangfire examples — inject IBackgroundJobClient and IRecurringJobManager via DI (preferred over static API)
public class OrderController(IBackgroundJobClient jobs, IRecurringJobManager recurring)
{
    public IActionResult CreateOrder([FromBody] CreateOrderDto dto)
    {
        jobs.Enqueue<IEmailService>(s => s.SendWelcome(dto.UserId));
        jobs.Schedule<IReminderService>(s => s.Send(dto.UserId), TimeSpan.FromMinutes(30));
        recurring.AddOrUpdate<IReportService>("daily", s => s.Generate(), Cron.Daily(9, 0));
        return Ok();
    }
}
// Broker storage: SQL Server (default), Redis, or PostgreSQL via Hangfire.PostgreSql package.
// PostgreSQL: builder.Services.AddHangfire(c => c.UsePostgreSqlStorage(connStr));
```

## Worker Design

Every handler: validate payload -> check idempotency -> execute logic -> mark processed -> update progress.

```typescript
const worker = new Worker('email', async (job) => {
  const payload = emailJobSchema.parse(job.data);
  if (await isDuplicate(job.id)) return;
  await emailProvider.send({ to: payload.email, template: payload.templateId });
  await markProcessed(job.id);
}, { connection: redis, concurrency: 5, limiter: { max: 10, duration: 1000 } });
```

Concurrency: CPU-bound = core count, I/O-bound = 5-20, memory-intensive = 2-4.

Payloads: keep small (IDs, not full objects). Fetch current data inside handler.

## Retry Strategies

```typescript
await queue.add('process', data, { attempts: 5, backoff: { type: 'exponential', delay: 1000 } });
```

| Error type | Retry? | Strategy |
|------------|--------|----------|
| Transient (timeout, 503) | Yes | Exponential backoff, 5 attempts |
| Rate limited (429) | Yes | Respect Retry-After |
| Validation (400) | No | DLQ immediately |
| Auth (401/403) | No | DLQ, alert ops |
| Server error (500) | Yes | Backoff, 3 attempts |

## Dead Letter Queues

Capture jobs that exhausted retries. Preserve data for debugging and replay.

```typescript
worker.on('failed', async (job, err) => {
  if (job && job.attemptsMade >= job.opts.attempts!) {
    await dlqQueue.add('failed-job', { originalQueue: 'email', jobId: job.id, payload: job.data, error: err.message });
    await alertService.notify({ severity: 'warning', message: `Job ${job.id} moved to DLQ` });
  }
});
```

Review DLQ daily, provide replay mechanism, set 30-day retention, track growth rate.

## Idempotency

Jobs may be delivered more than once (worker crash, network partition, manual retry).

```typescript
async function processWithIdempotency(jobId: string, handler: () => Promise<void>) {
  const key = `processed:${jobId}`;
  if (!await redis.set(key, '1', 'EX', 86400, 'NX')) return; // already done
  try { await handler(); }
  catch (err) { await redis.del(key); throw err; } // allow retry on failure
}
```

For financial operations: use database transactions with unique constraints.

## Monitoring

| Metric | Alert threshold |
|--------|----------------|
| Queue depth | >1000 sustained 10 min |
| Processing rate | Drop >50% from baseline |
| Error rate | >5% of processing rate |
| Processing duration | P95 > 2x baseline |
| DLQ size | >0 (alert on any entry) |

Dashboard: BullMQ -> `bull-board`/`arena`. Hangfire -> built-in `/hangfire`.

## Graceful Shutdown

```typescript
async function gracefulShutdown() {
  await worker.close();
  const timeout = setTimeout(() => process.exit(1), 30_000);
  clearTimeout(timeout);
  process.exit(0);
}
process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);
```

.NET: propagate `CancellationToken` in `ExecuteAsync`, re-enqueue on `OperationCanceledException`. Set Kubernetes `terminationGracePeriodSeconds` to match.

## Testing

- Unit test handlers in isolation with mocked dependencies
- Test idempotency: already-processed job skips execution
- Integration: real Redis, enqueue -> wait completion -> verify side effects
- Test retry and DLQ routing
- Recurring: verify cron produces expected times, test handler independently

## Anti-Patterns

- Non-idempotent handlers producing duplicates on retry
- Large payloads instead of IDs -- bloats queue storage and complicates replay
- No DLQ -- failed jobs vanish silently with no recovery path
- Shared queue for unrelated job types -- one noisy job starves others
- Sensitive data in job payloads (visible in queue dashboards and logs)
- In-memory queues in production -- data loss on restart or crash

## Output Format

```
Job:               [name and purpose]
Queue:             [BullMQ / Hangfire / pg-boss]
Pattern:           [fire-and-forget / delayed / recurring / chained]
Schedule:          [cron or delay, if applicable]
Concurrency:       [worker setting]
Retry:             [strategy, max attempts, backoff]
Idempotency:       [Redis key / DB constraint]
DLQ:               [configuration]
Monitoring:        [metrics and thresholds]
Shutdown:          [graceful shutdown approach]
```

## Done Criteria

- Jobs process reliably outside request-response cycle
- Handlers idempotent and safe under retry
- Retry strategy matches error type (transient vs permanent)
- DLQ captures permanently failed jobs with context
- Queue depth, error rate, duration monitored
- Graceful shutdown prevents stuck jobs on deployment
- Payloads minimal (IDs) and schema-validated
- Concurrency and rate limits respect external API constraints
- Workers shut down cleanly on SIGTERM
- Recurring jobs run on schedule
