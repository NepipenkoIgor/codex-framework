---
name: resilience-patterns
description: Implement resilience patterns — retry with exponential backoff, circuit breaker, timeout, bulkhead isolation, fallback, and hedging
metadata:
  version: 1.2
  argument-hint: "failure modes, dependencies involved, timeout budgets, fallback availability"
---

Implement resilience patterns for $ARGUMENTS with appropriate strategies for the failure modes.


## Pattern Selection

| Pattern | Failure mode | What it does |
|---------|-------------|--------------|
| Retry | Transient (timeout, 503) | Repeats with backoff |
| Circuit Breaker | Sustained failures | Stops calling failing service |
| Timeout | Slow responses | Fails fast instead of waiting |
| Bulkhead | Resource exhaustion | Limits concurrent calls |
| Fallback | Any failure | Returns degraded response |
| Hedging | Tail latency | Parallel redundant requests |

**Decision guide**:
- External HTTP → timeout (always) + retry (transient) + circuit breaker (outages) + fallback (optional)
- Database → timeout + connection pool (bulkhead) + retry (1–2 attempts max)
- Message queue publish → timeout + retry with idempotency key + fallback to outbox
- Third-party API → full stack: timeout + retry + circuit breaker + fallback

## Retry with Exponential Backoff + Jitter

**Retry**: 408, 429 (respect Retry-After), 500 (limit to 2–3), 502, 503, 504, network errors (ECONNRESET, ETIMEDOUT, ECONNREFUSED)

**Do NOT retry**: 400, 401, 403, 404, 409, 422 — client errors or business conflicts

### Node.js

```typescript
async function withRetry<T>(fn: () => Promise<T>, options: Partial<RetryOptions> = {}): Promise<T> {
  const opts = { maxAttempts: 3, baseDelayMs: 1000, maxDelayMs: 30_000, jitterFactor: 0.5, ...options };
  for (let attempt = 1; attempt <= opts.maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === opts.maxAttempts || !isRetryable(error)) throw error;
      // Respect Retry-After for 429
      const retryAfter = (error as any).headers?.get?.('retry-after');
      const baseDelay = retryAfter
        ? parseInt(retryAfter) * 1000
        : Math.min(opts.baseDelayMs * Math.pow(2, attempt - 1), opts.maxDelayMs);
      const delay = baseDelay * (1 - opts.jitterFactor + Math.random() * opts.jitterFactor);
      await new Promise(r => setTimeout(r, delay));
    }
  }
  throw new Error('unreachable');
}

function isRetryable(error: unknown): boolean {
  const status = (error as any).status;
  if (status) return [408, 429, 500, 502, 503, 504].includes(status);
  const code = (error as any).code;
  return ['ECONNRESET', 'ETIMEDOUT', 'ECONNREFUSED'].includes(code);
}
```

### .NET — Polly v8

```csharp
var retryPipeline = new ResiliencePipelineBuilder<HttpResponseMessage>()
    .AddRetry(new RetryStrategyOptions<HttpResponseMessage>
    {
        MaxRetryAttempts = 3, BackoffType = DelayBackoffType.Exponential,
        Delay = TimeSpan.FromSeconds(1), MaxDelay = TimeSpan.FromSeconds(30), UseJitter = true,
        ShouldHandle = new PredicateBuilder<HttpResponseMessage>()
            .HandleResult(r => r.StatusCode is HttpStatusCode.RequestTimeout or
                HttpStatusCode.TooManyRequests or HttpStatusCode.InternalServerError or
                HttpStatusCode.BadGateway or HttpStatusCode.ServiceUnavailable or HttpStatusCode.GatewayTimeout)
            .Handle<HttpRequestException>().Handle<TimeoutRejectedException>(),
    })
    .Build();
```

## Circuit Breaker

States: `CLOSED` (normal) → failure threshold exceeded → `OPEN` (fail fast) → break duration expires → `HALF-OPEN` (probe) → probe succeeds → `CLOSED` / probe fails → `OPEN`.

### Node.js

```typescript
class CircuitBreaker {
  private state: 'closed' | 'open' | 'half-open' = 'closed';
  private failureCount = 0;
  private successCount = 0;
  private lastFailureTime = 0;
  private halfOpenConcurrent = 0;

  constructor(private name: string, private opts: {
    failureThreshold: number; successThreshold: number;
    openDuration: number; halfOpenMaxConcurrent: number;
    isFailure: (e: unknown) => boolean;
    onStateChange?: (from: string, to: string) => void;
  }) {}

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'open') {
      if (Date.now() - this.lastFailureTime >= this.opts.openDuration) this.transition('half-open');
      else throw new Error(`Circuit "${this.name}" is open`);
    }
    if (this.state === 'half-open') {
      if (this.halfOpenConcurrent >= this.opts.halfOpenMaxConcurrent)
        throw new Error(`Circuit "${this.name}" is half-open, probe in progress`);
      this.halfOpenConcurrent++;
    }
    try {
      const result = await fn();
      if (this.state === 'half-open' && ++this.successCount >= this.opts.successThreshold) this.transition('closed');
      this.failureCount = 0;
      return result;
    } catch (error) {
      if (this.opts.isFailure(error)) {
        this.lastFailureTime = Date.now();
        if (this.state === 'half-open' || ++this.failureCount >= this.opts.failureThreshold) this.transition('open');
      }
      throw error;
    } finally {
      if (this.state === 'half-open') this.halfOpenConcurrent--;
    }
  }

  private transition(to: 'closed' | 'open' | 'half-open') {
    const from = this.state; this.state = to; this.successCount = 0;
    if (to === 'closed') this.failureCount = 0;
    this.opts.onStateChange?.(from, to);
  }

  getState() { return this.state; }
}

const paymentCircuit = new CircuitBreaker('payment', {
  failureThreshold: 5, successThreshold: 2, openDuration: 30_000, halfOpenMaxConcurrent: 1,
  isFailure: (err) => !(err instanceof ValidationError),
  onStateChange: (from, to) => metrics.gauge('circuit_breaker_state', to === 'open' ? 1 : 0, { service: 'payment' }),
});
```

### .NET — Polly v8

```csharp
builder.AddCircuitBreaker(new CircuitBreakerStrategyOptions<HttpResponseMessage>
{
    FailureRatio = 0.5, SamplingDuration = TimeSpan.FromSeconds(30),
    MinimumThroughput = 10, BreakDuration = TimeSpan.FromSeconds(30),
    ShouldHandle = new PredicateBuilder<HttpResponseMessage>()
        .HandleResult(r => (int)r.StatusCode >= 500).Handle<HttpRequestException>(),
});
```

## Timeout

Timeout types: connect (2–5s), read/response (5–30s), total end-to-end (10–60s).

### Node.js

```typescript
async function withTimeout<T>(fn: (signal: AbortSignal) => Promise<T>, ms: number, label = 'operation'): Promise<T> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  try {
    return await fn(controller.signal);
  } catch (error) {
    if (controller.signal.aborted) throw new Error(`${label} timed out after ${ms}ms`);
    throw error;
  } finally {
    clearTimeout(timer);
  }
}
```

**Deadline propagation**: downstream timeouts must be shorter than upstream. Pass remaining deadline via `X-Request-Deadline` header. Set a 500ms floor — don't make calls that will certainly timeout.

### .NET — Polly v8

```csharp
builder.AddTimeout(new TimeoutStrategyOptions { Timeout = TimeSpan.FromSeconds(10) });
```

## Bulkhead Isolation

Limits concurrency to prevent one dependency from exhausting all threads.

```typescript
class Bulkhead {
  private active = 0;
  private queue: Array<{ resolve: () => void; reject: (e: Error) => void }> = [];

  constructor(private name: string, private maxConcurrent: number, private maxQueue = 0) {}

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    if (this.active >= this.maxConcurrent) {
      if (this.queue.length >= this.maxQueue)
        throw new Error(`Bulkhead "${this.name}" full: ${this.active}/${this.maxConcurrent} active`);
      await new Promise<void>((resolve, reject) => this.queue.push({ resolve, reject }));
    }
    this.active++;
    try { return await fn(); }
    finally { this.active--; this.queue.shift()?.resolve(); }
  }
}
```

.NET: `.AddConcurrencyLimiter(new ConcurrencyLimiterOptions { PermitLimit = 10, QueueLimit = 5 })`

**Sizing guide**: DB → match pool size (20–50); payment → provider limit (5–10); email → tolerates queuing (10–20, queue 50); Redis → fast, no queue (50–100); external API → strict limits (3–5).

## Fallback Strategies

| Type | Use when |
|------|----------|
| Cache fallback | Slightly stale data acceptable |
| Default response | Feature is non-critical |
| Degraded mode | Partial function works |
| Alternative provider | Critical feature, redundant providers |

```typescript
async function withFallback<T>(primary: () => Promise<T>, fallback: (err: unknown) => Promise<T> | T): Promise<T> {
  try { return await primary(); }
  catch (error) { logger.warn('Primary failed, using fallback', { error }); return fallback(error); }
}

// Cache fallback
const products = await withFallback(
  () => productService.getAll(),
  async () => { const c = await redis.get('products:all'); if (c) return JSON.parse(c); throw new Error('No cache'); }
);
```

.NET: `.AddFallback(new FallbackStrategyOptions<T> { ShouldHandle = ..., FallbackAction = async args => { ... } })`

## Hedging

Send a second request after delay if the first hasn't responded. **Only for idempotent, read-only operations.**

```typescript
async function withHedging<T>(fn: (signal: AbortSignal) => Promise<T>, hedgeDelayMs: number): Promise<T> {
  const controller = new AbortController();
  const primary = fn(controller.signal);
  const hedge = new Promise<T>((resolve, reject) => {
    const t = setTimeout(() => fn(controller.signal).then(resolve).catch(reject), hedgeDelayMs);
    controller.signal.addEventListener('abort', () => clearTimeout(t));
  });
  try {
    const result = await Promise.any([primary, hedge]);
    controller.abort();
    return result;
  } catch (e) { throw (e instanceof AggregateError ? e.errors[0] : e); }
}
```

.NET: `.AddHedging(new HedgingStrategyOptions { MaxHedgedAttempts = 1, Delay = TimeSpan.FromMilliseconds(200) })`

Set hedge delay to P90–P95 latency. If >50% of requests hedge, the service needs fixing.

## Composition Order

```
Request → Timeout → Bulkhead → Circuit Breaker → Retry → Fallback → Call
```

### .NET Combined Pipeline (Polly + HttpClientFactory)

```csharp
builder.Services.AddHttpClient("payment-provider")
    .AddResilienceHandler("payment-resilience", (b, _) =>
    {
        b.AddTimeout(new TimeoutStrategyOptions { Timeout = TimeSpan.FromSeconds(30) }); // outer
        b.AddRetry(new RetryStrategyOptions<HttpResponseMessage>
        {
            MaxRetryAttempts = 3, BackoffType = DelayBackoffType.Exponential,
            Delay = TimeSpan.FromSeconds(1), UseJitter = true,
            ShouldHandle = new PredicateBuilder<HttpResponseMessage>()
                .HandleResult(r => (int)r.StatusCode >= 500).Handle<HttpRequestException>(),
        });
        b.AddCircuitBreaker(new CircuitBreakerStrategyOptions<HttpResponseMessage>
        {
            FailureRatio = 0.5, SamplingDuration = TimeSpan.FromSeconds(30),
            MinimumThroughput = 10, BreakDuration = TimeSpan.FromSeconds(30),
        });
        b.AddTimeout(new TimeoutStrategyOptions { Timeout = TimeSpan.FromSeconds(5) }); // per attempt
    });
```

## Health Check Integration

Expose circuit breaker state so load balancers can route traffic.

```typescript
app.get('/health', (req, res) => {
  const circuits = { payment: paymentCircuit.getState(), catalog: catalogCircuit.getState() };
  const degraded = Object.values(circuits).some(s => s === 'open');
  res.status(degraded ? 503 : 200).json({ status: degraded ? 'degraded' : 'healthy', circuits });
});
```

## Observability

Key metrics: `retry_attempts_total`, `circuit_breaker_state` (0=closed, 0.5=half-open, 1=open), `timeout_total`, `bulkhead_rejected_total`, `fallback_triggered_total`. Alert on: circuit opens, >5% timeout rate, sustained fallback activation.

## Anti-Patterns

- Retrying non-idempotent writes without deduplication -- each retry creates a duplicate record
- No jitter on retry backoff -- synchronized retries create a thundering herd after an outage
- Circuit breaker threshold of 1 -- flaps on single transient failure, never stabilizes
- Downstream timeout longer than upstream caller timeout -- the upstream times out before the protection fires
- Hedging non-idempotent operations -- each speculative request creates a duplicate side effect

## Workflow

1. Identify external dependencies and their failure modes
2. Add timeout to every external call
3. Add retry with backoff for transient failures (skip 4xx)
4. Add circuit breaker for dependencies that can sustain outages
5. Add bulkhead isolation for resource-constrained dependencies
6. Add fallback for non-critical features
7. Consider hedging for latency-critical idempotent reads
8. Compose in correct order (timeout > bulkhead > CB > retry > fallback)
9. Expose circuit state via health endpoint
10. Add metrics, structured logging, alerts; test with fault injection

Done: ✓ every external call has timeout ✓ transient failures retry with jitter ✓ 4xx not retried ✓ circuit breaker protects against sustained outages ✓ circuit state in health endpoint ✓ bulkhead isolates failures ✓ fallback on primary failure ✓ composition in correct order ✓ retry/circuit/timeout metrics monitored ✓ tested with fault injection
