---
name: webhook-reliability
description: Implement reliable webhook delivery and consumption including idempotency, exponential backoff, event log and replay, dead letter queues, signature verification, and delivery guarantees
metadata:
  version: 1.4
  argument-hint: "webhook direction (incoming/outgoing), event types, delivery guarantee SLO, signature algorithm"
---

Implement reliable webhook infrastructure for $ARGUMENTS.

## Tool Integration

- **Type diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Webhook Delivery Architecture (Producer Side)

### Event Pipeline

```
Domain Event → Event Store (append-only) → Delivery Queue (per-subscription fan-out)
  → Delivery Worker (sign, send, record attempt)
    → Success (2xx)             → mark delivered, record latency
    → Retryable (5xx/timeout)   → exponential backoff retry
    → Permanent failure (4xx≠429) → DLQ after max retries
    → Circuit open              → skip, queue for later
```

### Schemas

```sql
CREATE TABLE webhook_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  sequence_number BIGINT GENERATED ALWAYS AS IDENTITY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  metadata JSONB DEFAULT '{}'
);
CREATE INDEX idx_webhook_events_type ON webhook_events (event_type);
CREATE INDEX idx_webhook_events_resource ON webhook_events (resource_type, resource_id);
CREATE INDEX idx_webhook_events_created ON webhook_events (created_at);

CREATE TABLE webhook_subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  url TEXT NOT NULL,
  secret TEXT NOT NULL,
  events TEXT[] NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  circuit_state TEXT NOT NULL DEFAULT 'closed',
  circuit_opened_at TIMESTAMPTZ,
  failure_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
CREATE INDEX idx_webhook_subs_status ON webhook_subscriptions (status) WHERE status = 'active';

CREATE TABLE webhook_deliveries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES webhook_events(id),
  subscription_id UUID NOT NULL REFERENCES webhook_subscriptions(id),
  status TEXT NOT NULL DEFAULT 'pending',
  attempt_count INT DEFAULT 0,
  next_retry_at TIMESTAMPTZ,
  last_attempt_at TIMESTAMPTZ,
  last_response_status INT,
  last_response_body TEXT,
  last_error TEXT,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
CREATE INDEX idx_webhook_deliveries_pending ON webhook_deliveries (next_retry_at) WHERE status = 'pending';
CREATE INDEX idx_webhook_deliveries_event ON webhook_deliveries (event_id);
```

## Idempotency Keys and Deduplication

### Consumer-Side Deduplication

```typescript
async function handleWebhook(req: Request): Promise<Response> {
  const idempotencyKey = req.headers.get('x-webhook-idempotency-key');
  if (!idempotencyKey) return new Response('Missing idempotency key', { status: 400 });

  const isNew = await redis.set(`webhook:processed:${idempotencyKey}`, '1', 'EX', 172800, 'NX');
  if (!isNew) return new Response('Already processed', { status: 200 });

  try {
    await processEvent(req);
    return new Response('OK', { status: 200 });
  } catch (err) {
    await redis.del(`webhook:processed:${idempotencyKey}`);
    throw err;
  }
}
```

Rules:
- Producer: generate idempotency key at event creation time; store with UNIQUE constraint
- Consumer: check key before processing; return 200 for duplicates (not an error)
- Dedup window: 48 hours minimum
- Financial operations: use database unique constraints instead of Redis

## Exponential Backoff with Jitter

### Retry Schedule

| Attempt | Base Delay | With Jitter (range) |
|---------|-----------|---------------------|
| 1 | 30 seconds | 15–30s |
| 2 | 2 minutes | 1–2m |
| 3 | 15 minutes | 7.5–15m |
| 4 | 1 hour | 30m–1h |
| 5 | 4 hours | 2–4h |
| 6 | 12 hours | 6–12h |
| 7 | 24 hours | 12–24h |

```typescript
function calculateRetryDelay(attempt: number): number {
  const base = 30_000;
  const max = 24 * 60 * 60 * 1000;
  const exp = Math.min(base * Math.pow(4, attempt - 1), max);
  return Math.round(exp * (0.5 + Math.random() * 0.5));
}

async function scheduleRetry(deliveryId: string, attempt: number, maxAttempts: number): Promise<void> {
  if (attempt >= maxAttempts) { await moveToDLQ(deliveryId); return; }
  await db.webhookDeliveries.update({
    where: { id: deliveryId },
    data: { next_retry_at: new Date(Date.now() + calculateRetryDelay(attempt)), attempt_count: attempt },
  });
}
```

Rules:
- Always use jitter to prevent thundering herd
- Cap max delay at 24 hours; cap max attempts at 7 (~48-hour window)
- Use `next_retry_at` column with index for efficient polling

## Delivery Guarantees

**At-least-once** — exactly-once is impractical across HTTP; consumer-side idempotency is simpler and more reliable.

### Delivery Worker

```typescript
async function deliverWebhook(delivery: WebhookDelivery): Promise<void> {
  const [event, subscription] = await Promise.all([
    db.webhookEvents.findById(delivery.event_id),
    db.webhookSubscriptions.findById(delivery.subscription_id),
  ]);

  if (subscription.circuit_state === 'open') {
    await scheduleRetry(delivery.id, delivery.attempt_count + 1, MAX_ATTEMPTS);
    return;
  }

  const payload = JSON.stringify({ id: event.id, type: event.event_type, created_at: event.created_at, data: event.payload });
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const signature = signPayload(payload, timestamp, subscription.secret);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30_000);

  try {
    const response = await fetch(subscription.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Webhook-Id': event.id,
        'X-Webhook-Timestamp': timestamp,
        'X-Webhook-Signature': signature,
        'X-Webhook-Idempotency-Key': event.idempotency_key,
        'X-Webhook-Signature-Algorithm': 'hmac-sha256',
      },
      body: payload,
      signal: controller.signal,
    });
    clearTimeout(timeout);
    await recordAttempt(delivery.id, response.status, await response.text().catch(() => ''));

    if (response.ok) { await markDelivered(delivery.id); await resetCircuitBreaker(subscription.id); }
    else if (response.status === 410) { await disableSubscription(subscription.id, '410 Gone'); }
    else if (response.status === 429) {
      const retryAfter = parseInt(response.headers.get('Retry-After') ?? '60', 10);
      await scheduleRetryWithDelay(delivery.id, retryAfter * 1000);
    } else if (response.status >= 500 || response.status === 408) {
      await handleRetryableFailure(delivery, subscription);
    } else {
      await handlePermanentFailure(delivery, subscription, `HTTP ${response.status}`);
    }
  } catch (err) {
    clearTimeout(timeout);
    await handleRetryableFailure(delivery, subscription, err.name === 'AbortError' ? 'Timeout after 30s' : err.message);
  }
}
```

## Signature Verification (HMAC-SHA256)

```typescript
function signPayload(payload: string, timestamp: string, secret: string): string {
  return crypto.createHmac('sha256', secret).update(`${timestamp}.${payload}`).digest('hex');
}

function verifyWebhookSignature(payload: string, timestamp: string, signature: string, secret: string, toleranceSeconds = 300): boolean {
  const diff = Math.abs(Math.floor(Date.now() / 1000) - parseInt(timestamp, 10));
  if (diff > toleranceSeconds) return false;
  const expected = crypto.createHmac('sha256', secret).update(`${timestamp}.${payload}`).digest('hex');
  return crypto.timingSafeEqual(Buffer.from(signature, 'hex'), Buffer.from(expected, 'hex'));
}
```

**.NET:**
```csharp
public static bool VerifySignature(string payload, string timestamp, string signature, string secret, int toleranceSeconds = 300)
{
    if (!long.TryParse(timestamp, out var eventTime)) return false;
    if (Math.Abs(DateTimeOffset.UtcNow.ToUnixTimeSeconds() - eventTime) > toleranceSeconds) return false;
    using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
    var expected = Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes($"{timestamp}.{payload}"))).ToLowerInvariant();
    return CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(signature), Encoding.UTF8.GetBytes(expected));
}
```

Rules:
- Always include timestamp in signed content (replay protection)
- Reject events older than 5 minutes
- Use constant-time comparison to prevent timing attacks
- Sign raw payload string, not parsed-and-reserialized JSON
- Include `X-Webhook-Signature-Algorithm: hmac-sha256` for future rotation

## Event Log and Replay API

```
GET  /api/webhooks/events?type=order.*&after=2025-01-01&limit=100
GET  /api/webhooks/events/:eventId
POST /api/webhooks/events/:eventId/replay
POST /api/webhooks/events/replay
GET  /api/webhooks/deliveries?subscription_id=x&status=failed
POST /api/webhooks/deliveries/:deliveryId/retry
```

```typescript
async function replayEvent(eventId: string, subscriptionId?: string): Promise<void> {
  const event = await db.webhookEvents.findById(eventId);
  if (!event) throw new NotFoundError('Event not found');
  const subscriptions = subscriptionId
    ? [await db.webhookSubscriptions.findById(subscriptionId)]
    : await db.webhookSubscriptions.findMany({ where: { status: 'active', events: { hasSome: [event.event_type] } } });
  for (const sub of subscriptions) {
    await db.webhookDeliveries.create({ data: { event_id: event.id, subscription_id: sub.id, status: 'pending', next_retry_at: new Date() } });
  }
}
```

Rules:
- Replay creates new delivery records — never modifies existing ones
- Replay preserves original payload and idempotency key (consumer dedup prevents double-processing)
- Cap batch replay at 1000 events; rate-limit replay API

## Dead Letter Queue Handling

```typescript
async function moveToDLQ(deliveryId: string): Promise<void> {
  await db.webhookDeliveries.update({ where: { id: deliveryId }, data: { status: 'dlq' } });
  const delivery = await db.webhookDeliveries.findById(deliveryId, { include: { event: true, subscription: true } });
  await alertService.notify({
    severity: 'warning', channel: 'webhook-dlq',
    message: 'Webhook delivery exhausted retries',
    context: { deliveryId, eventType: delivery.event.event_type, subscriptionUrl: delivery.subscription.url, lastError: delivery.last_error, attempts: delivery.attempt_count },
  });
}
```

```sql
SELECT s.url, s.tenant_id, COUNT(*) AS dlq_count, MIN(d.created_at) AS oldest
FROM webhook_deliveries d JOIN webhook_subscriptions s ON s.id = d.subscription_id
WHERE d.status = 'dlq' GROUP BY s.id ORDER BY dlq_count DESC;
```

Rules:
- Alert on every DLQ entry — zero tolerance for silent failures
- Provide manual retry from DLQ via API; review DLQ daily
- 30-day retention before archival; track DLQ depth as a key metric

## Circuit Breaker for Failing Endpoints

### State Machine
```
CLOSED → (5 consecutive failures) → OPEN → (5 min cooldown) → HALF-OPEN → (success) → CLOSED
                                                                           → (failure) → OPEN
```

```typescript
const CIRCUIT_FAILURE_THRESHOLD = 5;
const CIRCUIT_COOLDOWN_MS = 5 * 60 * 1000;

async function handleRetryableFailure(delivery: WebhookDelivery, subscription: WebhookSubscription): Promise<void> {
  const newCount = subscription.failure_count + 1;
  if (newCount >= CIRCUIT_FAILURE_THRESHOLD && subscription.circuit_state === 'closed') {
    await db.webhookSubscriptions.update({
      where: { id: subscription.id },
      data: { circuit_state: 'open', circuit_opened_at: new Date(), failure_count: newCount },
    });
    await alertService.notify({ severity: 'warning', message: 'Circuit breaker opened', context: { subscriptionId: subscription.id, url: subscription.url } });
  } else {
    await db.webhookSubscriptions.update({ where: { id: subscription.id }, data: { failure_count: newCount } });
  }
  await scheduleRetry(delivery.id, delivery.attempt_count + 1, MAX_ATTEMPTS);
}

async function checkCircuitState(subscription: WebhookSubscription): Promise<'deliver' | 'skip'> {
  if (subscription.circuit_state === 'closed') return 'deliver';
  if (subscription.circuit_state === 'open') {
    const elapsed = Date.now() - subscription.circuit_opened_at!.getTime();
    if (elapsed >= CIRCUIT_COOLDOWN_MS) {
      await db.webhookSubscriptions.update({ where: { id: subscription.id }, data: { circuit_state: 'half-open' } });
      return 'deliver';
    }
    return 'skip';
  }
  return 'deliver'; // half-open: allow test delivery
}
```

## Webhook Consumer Patterns

```typescript
// 1. Verify signature first (use raw body)
const rawBody = await req.text();
if (!verifyWebhookSignature(rawBody, req.headers.get('x-webhook-timestamp')!, req.headers.get('x-webhook-signature')!, WEBHOOK_SECRET))
  return new Response('Invalid signature', { status: 401 });

// 2. Parse and validate
const event = webhookEventSchema.safeParse(JSON.parse(rawBody));
if (!event.success) return new Response('Invalid payload', { status: 400 });

// 3. Check idempotency
if (await isAlreadyProcessed(req.headers.get('x-webhook-idempotency-key')!))
  return new Response('OK', { status: 200 });

// 4. Respond 200 immediately, process async
await webhookQueue.add('process', { event: event.data, idempotencyKey });
return new Response('OK', { status: 200 });
```

Rules:
- Verify signature before any other processing
- Respond 200 fast — process asynchronously
- Return 200 for already-processed (not an error); 400 for permanently invalid; 500 for transient failures

## Ordering Guarantees

- Include `sequence_number` (IDENTITY column) per resource in the webhook payload
- Consumers track last processed sequence per `resource_type:resource_id`
- Buffer out-of-order events; request replay for detected gaps
- For most use cases: design consumers to tolerate out-of-order rather than enforcing strict order

## Monitoring and Alerting

| Metric | Alert Threshold |
|--------|----------------|
| Delivery success rate | < 95% |
| Delivery latency P95 | > 30s |
| Retry rate | > 20% |
| DLQ depth | > 0 |
| DLQ growth rate | > 10/hour |
| Circuit breaker trips | > 0 |
| Queue depth | > 1000 sustained |

```sql
SELECT
  COUNT(*) FILTER (WHERE status = 'delivered') * 100.0 / COUNT(*) AS success_rate,
  COUNT(*) FILTER (WHERE status = 'dlq') AS dlq
FROM webhook_deliveries WHERE created_at > NOW() - INTERVAL '24 hours';

SELECT
  percentile_cont(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM delivered_at - created_at)) AS p95_seconds
FROM webhook_deliveries WHERE status = 'delivered' AND created_at > NOW() - INTERVAL '24 hours';
```

## Secret Rotation

1. Generate new secret, store as `new_secret` on subscription
2. Dual-sign outgoing webhooks with both secrets for 72 hours: `v1=<current>,v1_prev=<previous>`
3. Consumer accepts either signature during rotation window
4. Remove old secret after rotation period

```typescript
function signPayloadDualSecret(payload: string, timestamp: string, secrets: { current: string; previous?: string }): string {
  const cur = signPayload(payload, timestamp, secrets.current);
  if (secrets.previous) return `v1=${cur},v1_prev=${signPayload(payload, timestamp, secrets.previous)}`;
  return `v1=${cur}`;
}
```

## Webhook Testing

```bash
ngrok http 3000
stripe listen --forward-to localhost:3000/api/webhooks/stripe
```

Debug endpoint: `GET /api/webhooks/deliveries/:id/debug` → returns event, subscription, delivery state, and attempt history.

## Anti-Patterns

- Storing parsed-and-reserialized JSON on the producer side — invalidates the HMAC signature
- Symmetric secrets shared across multiple consumers — one compromise exposes all
- Trusting client-provided timestamps in signature verification — enables replay attacks
- Infinite retries without circuit breaker -- hammers a failing endpoint indefinitely
- Processing synchronously before responding 200 -- delivery appears failed, triggering retries

## Implementation Workflow

1. Design event store schema with idempotency keys and sequence numbers
2. Implement subscription management with secret generation
3. Build delivery worker with signature, timeout, and retry logic
4. Add circuit breaker for failing endpoints
5. Implement DLQ with alerting and manual retry
6. Build replay API for missed event recovery
7. Add consumer verification helpers
8. Set up monitoring dashboards and alerts
9. Document webhook API with payload schemas and verification examples
10. Test with local tunneling and test endpoint

## Output Format

```
Feature:          [what webhook functionality was built]
Direction:        [producer / consumer / both]
Events:           [event types with payload schemas]
Delivery:         [at-least-once with retry schedule]
Signature:        [HMAC-SHA256 with timestamp]
Idempotency:      [dedup key strategy]
Retry:            [exponential backoff schedule, max attempts]
DLQ:              [dead letter queue with alerting]
Circuit Breaker:  [failure threshold, cooldown, half-open test]
Replay:           [event log and replay API]
Monitoring:       [metrics tracked and alert thresholds]
```

## Done Criteria

- Events stored immutably in event store with idempotency keys and sequence numbers
- Delivery worker signs payloads with HMAC-SHA256 including timestamp
- Consumer SDK verifies signatures with constant-time comparison and replay protection
- Exponential backoff with jitter retries failed deliveries up to 7 times over 48 hours
- DLQ captures permanently failed deliveries with alerting
- Circuit breaker stops hammering endpoints after 5 consecutive failures
- Replay API allows re-delivery of individual events or filtered batches
- Delivery success rate, latency, DLQ depth, and circuit breaker state monitored
- Consumer deduplication prevents duplicate processing on retry or replay
- Secret rotation supported with dual-signing during transition period
