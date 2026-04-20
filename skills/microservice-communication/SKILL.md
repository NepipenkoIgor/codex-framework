---
name: microservice-communication
description: Implement microservice communication patterns including gRPC, REST inter-service calls, service discovery, circuit breakers, API gateways, sidecar proxy, and request/response vs event-driven patterns
metadata:
  version: 1.3
  argument-hint: "pattern (REST/gRPC/async messaging), services involved, SLO latency/availability, synchronous vs eventual consistency"
---

Implement microservice communication for $ARGUMENTS with reliable, resilient service-to-service interaction patterns.


## Communication Pattern Decision Table

| Pattern | Latency | Coupling | Use when |
|---------|---------|----------|----------|
| Synchronous REST | Medium | High (temporal) | Simple CRUD, real-time response needed, low call depth |
| gRPC | Low | High (temporal) | Internal services, high throughput, streaming, strict contracts |
| Async messaging (event) | High | Low | Event notifications, eventual consistency acceptable |
| Async messaging (command) | Medium | Medium | Delegated work, fire-and-forget with delivery guarantee |
| Request/reply over queue | Medium | Medium | Async request needing a response, decoupled caller |

Decision: need immediate response -> sync (REST or gRPC). Internal high-throughput typed contracts -> gRPC. Public API -> REST. Tolerate eventual consistency -> async messaging. Broadcast state changes -> events. Complex multi-service client query -> API gateway aggregation.

## gRPC Implementation

### Protobuf Definition

```protobuf
syntax = "proto3";
package orders.v1;
option csharp_namespace = "Orders.Grpc.V1";
import "google/protobuf/timestamp.proto";

service OrderService {
  rpc GetOrder (GetOrderRequest) returns (OrderResponse);
  rpc CreateOrder (CreateOrderRequest) returns (OrderResponse);
  rpc StreamOrderUpdates (StreamOrdersRequest) returns (stream OrderEvent);
}

message GetOrderRequest { string order_id = 1; }
message CreateOrderRequest {
  string customer_id = 1;
  repeated OrderItem items = 2;
  string idempotency_key = 3;
}
message OrderItem { string product_id = 1; int32 quantity = 2; int64 price_cents = 3; }
message OrderResponse {
  string order_id = 1; string status = 2; int64 total_cents = 3;
  google.protobuf.Timestamp created_at = 4;
}
```

### .NET gRPC Client (Grpc.Net.Client)

```csharp
builder.Services.AddGrpcClient<OrderService.OrderServiceClient>(o =>
    o.Address = new Uri(builder.Configuration["Services:Orders:GrpcUrl"]!))
.AddInterceptor<CorrelationIdInterceptor>()
.AddCallCredentials(async (context, metadata) =>
{
    var token = await tokenProvider.GetTokenAsync(context.CancellationToken);
    metadata.Add("Authorization", $"Bearer {token}");
});

// Usage: always set deadlines
var deadline = DateTime.UtcNow.AddSeconds(5);
var response = await _orderClient.CreateOrderAsync(request, deadline: deadline, cancellationToken: ct);
```

### Node.js gRPC (@grpc/grpc-js)

```typescript
import * as grpc from '@grpc/grpc-js';
import * as protoLoader from '@grpc/proto-loader';

const packageDef = protoLoader.loadSync('orders/v1/orders.proto', {
  keepCase: false, longs: String, enums: String, defaults: true,
});
const proto = grpc.loadPackageDefinition(packageDef) as any;
const client = new proto.orders.v1.OrderService('orders-service:50051', grpc.credentials.createInsecure());

function getOrder(orderId: string): Promise<OrderResponse> {
  return new Promise((resolve, reject) => {
    const deadline = new Date(Date.now() + 5000);
    client.getOrder({ orderId }, { deadline }, (err: grpc.ServiceError | null, res: any) => {
      if (err) return reject(err);
      resolve(res);
    });
  });
}
```

### gRPC Rules

- Always set deadlines -- no unbounded waits
- Field numbers are immutable once deployed -- never reuse or renumber
- Version packages: `orders.v1`, `orders.v2`; deploy side by side
- Use headless Kubernetes services for gRPC client-side load balancing (HTTP/2 multiplexing defeats L4 balancers)

## REST Inter-Service Calls

### .NET Typed HttpClient with Refit + Polly

```csharp
public interface IInventoryApiClient
{
    [Get("/api/v1/products/{productId}/stock")]
    Task<StockResponse> GetStockAsync(string productId, CancellationToken ct = default);

    [Post("/api/v1/products/{productId}/reserve")]
    Task<ReservationResponse> ReserveStockAsync(
        string productId, [Body] ReserveStockRequest request, CancellationToken ct = default);
}

builder.Services.AddRefitClient<IInventoryApiClient>()
    .ConfigureHttpClient(c => {
        c.BaseAddress = new Uri(config["Services:Inventory:BaseUrl"]!);
        c.Timeout = TimeSpan.FromSeconds(10);
    })
    .AddResilienceHandler("inventory", b => b
        .AddRetry(new HttpRetryStrategyOptions {
            MaxRetryAttempts = 3, BackoffType = DelayBackoffType.Exponential,
            Delay = TimeSpan.FromMilliseconds(200), UseJitter = true,
        })
        .AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions {
            HandledEventsAllowedBeforeBreaking = 5,
            BreakDuration = TimeSpan.FromSeconds(30),
        }));
```

### Node.js with native fetch + Retry

> Node.js 18+ includes native `fetch` — prefer it for inter-service HTTP. `got` v12+ is ESM-only (breaks NestJS CJS). For connection pooling, use `undici`.

```typescript
import { fetch } from 'undici'; // or globalThis.fetch (Node 18+); undici for connection pooling

async function fetchWithRetry(url: string, options: RequestInit, retries = 3): Promise<Response> {
  const retryable = [408, 429, 500, 502, 503, 504];
  for (let attempt = 1; attempt <= retries; attempt++) {
    const correlationId = asyncLocalStorage.getStore()?.correlationId;
    const res = await fetch(url, {
      ...options,
      signal: AbortSignal.timeout(5000),
      headers: {
        ...options.headers,
        ...(correlationId ? { 'x-correlation-id': correlationId } : {}),
      },
    });
    if (!retryable.includes(res.status) || attempt === retries) return res;
    await new Promise((r) => setTimeout(r, attempt * 200));
  }
  throw new Error('Max retries exceeded');
}
```

### tRPC for Type-Safe Internal APIs (Node.js)

```typescript
// Server: define typed router
const appRouter = router({
  order: router({
    getById: publicProcedure.input(z.object({ orderId: z.string().uuid() }))
      .query(async ({ input }) => orderRepo.findById(input.orderId)),
  }),
});
export type AppRouter = typeof appRouter;

// Client: fully typed, no codegen
const orderClient = createTRPCClient<AppRouter>({ links: [httpBatchLink({ url: `${ORDER_SERVICE_URL}/trpc` })] });
const order = await orderClient.order.getById.query({ orderId: '123' }); // typed result
```

## Service Discovery

| Pattern | Pros | Cons | Use when |
|---------|------|------|----------|
| Kubernetes DNS | Zero config, automatic | K8s only | Default for Kubernetes |
| Consul | Multi-platform, health checks | Extra infrastructure | Non-Kubernetes, hybrid |
| Client-side (registry) | No extra hop, flexible LB | Complex client, stale cache | gRPC load balancing |

Kubernetes DNS: `http://order-service.production.svc.cluster.local:8080`. Use headless services for gRPC. Cache discovery results 30-60s.

## API Gateway as Communication Hub

| Gateway does | Gateway does NOT |
|-------------|-----------------|
| Authentication (JWT validation) | Business logic |
| Rate limiting | Database access |
| Request routing | Data transformation beyond protocol translation |
| Protocol translation (REST -> gRPC) | Service orchestration |
| Correlation ID injection | Caching mutable data |
| TLS termination | |

.NET: YARP reverse proxy. Node.js: Express/Fastify with `http-proxy-middleware`.

## Sidecar Proxy and Service Mesh

```
[Service A] <-> [Sidecar Proxy] ---- network ---- [Sidecar Proxy] <-> [Service B]
```

Each service gets a sidecar proxy (Envoy) handling mTLS, retries, timeouts, circuit breakers, and metrics. Control plane (Istio/Linkerd) configures proxies centrally.

When to use: 10+ services with multiple teams, strict mTLS requirements, complex traffic routing (canary/A/B). Start without a mesh; add when operational complexity justifies it. Mesh adds 1-5ms latency per hop.

## Request/Response vs Event-Driven

| Scenario | Pattern |
|----------|---------|
| User needs immediate result | Sync (REST/gRPC) |
| Notify others of state change | Event (async, no response needed) |
| Delegate work with delivery guarantee | Command (async) |
| Long-running process (>30s) | Async + polling/callback |
| Compensating actions on failure | Saga |

Switch sync to async when: introduce a queue, return 202 Accepted, consumer publishes result event, caller learns via callback/polling/subscription.

## Saga Pattern for Distributed Transactions

### Choreography (2-3 steps)

Each service listens for events, reacts, publishes compensating events on failure. No central coordinator.

### Orchestration (4+ steps, preferred)

Central orchestrator manages state machine, sends commands, handles responses/failures, persists saga state.

```
Orchestrator -> ReserveStock -> Inventory (success)
             -> ChargePayment -> Payment (fail)
             -> ReleaseStock -> Inventory (compensate)
             -> FailOrder -> Order
```

Rules: every step has a compensating action, compensations are idempotent, saga state persisted durably, timeouts on each step, log every transition.

## Idempotency in Inter-Service Calls

```typescript
// Client: include idempotency key
headers: { 'Idempotency-Key': `create-order-${cartId}` }

// Server: check before processing
const existing = await redis.get(`idempotency:${key}`);
if (existing) return res.status(200).json(JSON.parse(existing));
const result = await orderService.create(req.body);
await redis.set(`idempotency:${key}`, JSON.stringify(result), 'EX', 86400);
```

Every mutation across service boundaries must accept an idempotency key. Use deterministic keys: `{operation}-{entity-id}`. Store results for 24h.

## Correlation IDs and Distributed Tracing

### Node.js Propagation

```typescript
function correlationMiddleware(req: Request, res: Response, next: NextFunction) {
  const correlationId = req.headers['x-correlation-id'] as string ?? crypto.randomUUID();
  asyncLocalStorage.run({ correlationId }, () => {
    res.setHeader('x-correlation-id', correlationId);
    next();
  });
}
// Outgoing calls: read from asyncLocalStorage, add to headers
```

### .NET Propagation

```csharp
// DelegatingHandler for HttpClient
public class CorrelationIdHandler : DelegatingHandler
{
    private readonly IHttpContextAccessor _accessor;
    public CorrelationIdHandler(IHttpContextAccessor a) => _accessor = a;
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage req, CancellationToken ct)
    {
        var id = _accessor.HttpContext?.Items["CorrelationId"]?.ToString();
        if (id is not null) req.Headers.TryAddWithoutValidation("X-Correlation-Id", id);
        return base.SendAsync(req, ct);
    }
}
```

Use W3C `traceparent`/`tracestate` headers with OpenTelemetry for distributed tracing. Propagate through message queue headers too.

## Error Handling Across Service Boundaries

### Error Response Contract

```typescript
interface ServiceError {
  code: string;           // "ORDER_NOT_FOUND", "STOCK_INSUFFICIENT"
  message: string;
  service: string;
  correlationId: string;
}
```

### Error Translation

| Downstream | Upstream | Rationale |
|-----------|----------|-----------|
| 400 | 400 or 502 | 400 if caller's input wrong, 502 if downstream contract violated |
| 401/403 | 502 | Service-to-service auth failure is internal |
| 404 | Context-dependent | 404 if resource missing, 500 if misconfigured |
| 408/timeout | 504 | Propagate timeout as gateway timeout |
| 429 | 503 or retry | Retry with backoff, 503 if exhausted |
| 500 | 502 | Downstream internal error |

Never expose downstream error details to external clients. Log full errors with correlation ID; return sanitized versions.

### Partial Failure

Use `Promise.allSettled` (Node.js) or parallel tasks (C#) for non-critical enrichments. Return degraded response with available data rather than failing entirely.

## Timeout and Deadline Propagation

```
Client (10s) -> Gateway (9s) -> Order Service (8s) -> Inventory (7s)
```

Each service subtracts processing overhead from remaining deadline. Never set downstream timeout longer than your own remaining budget. gRPC propagates deadlines automatically.

## Health Checks and Readiness Probes

- `/health`: full dependency check for dashboards
- `/ready`: critical deps only for load balancer routing
- `/live`: lightweight process-alive check for orchestrator restarts

Do not include non-critical downstream services in readiness -- one degraded service should not take you offline.

## Contract Testing with Pact

```typescript
// Consumer test
provider.given('order 123 exists')
  .uponReceiving('a request for order 123')
  .withRequest({ method: 'GET', path: '/api/v1/orders/123' })
  .willRespondWith({ status: 200, body: { orderId: like('123'), status: like('confirmed') } });

// Provider verification
const verifier = new Verifier({
  providerBaseUrl: 'http://localhost:8080',
  pactUrls: ['pacts/checkout-order.json'],
  stateHandlers: { 'order 123 exists': async () => { await seedOrder('123'); } },
});
```

Test strategy: contract tests (fast, catch breaking API changes), component tests (single service, mocked deps), integration tests (real DB, mocked externals via WireMock), E2E (critical paths only).

## Migration Patterns

### Strangler Fig

Route traffic through API gateway. New endpoints go to microservice, old to monolith. Gradually migrate by changing routes. Remove monolith code once fully migrated.

### Anti-Corruption Layer (ACL)

Place in the new service to translate between legacy and new domain models. Replace with direct integration when legacy is decommissioned.

```typescript
class LegacyOrderAdapter implements OrderPort {
  async getOrder(orderId: string): Promise<Order> {
    const legacy = await this.legacyClient.fetchOrder(orderId);
    return { id: legacy.order_num, status: mapLegacyStatus(legacy.state_code),
      totalCents: Math.round(legacy.total_amount * 100) };
  }
}
```

### Branch by Abstraction

1. Create interface for functionality to migrate
2. Implement with existing code
3. Build new implementation behind same interface
4. Feature flag to switch implementations
5. Remove old implementation once validated

## Anti-Patterns

- Distributed monolith: services deployed together sharing a database -- no actual decoupling
- Chatty services: many fine-grained sync calls instead of coarse-grained APIs
- Sync chains without timeout budgets: one slow service cascades failures through the chain
- No contract testing: breaking API changes discovered in production after deployment
- Sagas without persisted state: in-progress saga lost on crash with no compensation triggered

## Output Format

```
Services:          [services involved and roles]
Communication:     [REST / gRPC / async per interaction]
Contracts:         [proto files / OpenAPI / event schemas]
Discovery:         [DNS / Consul / mesh]
Resilience:        [timeout, retry, circuit breaker config]
Saga:              [choreography / orchestration, steps, compensations]
Tracing:           [correlation ID / OpenTelemetry]
Gateway:           [routing, protocol translation]
Testing:           [contract tests, integration tests]
Migration:         [strangler fig / ACL / branch by abstraction]
```

## Done Criteria

- Every sync call has timeout, retry, and circuit breaker
- Idempotency keys on all cross-service mutations
- Correlation IDs propagated and logged through all calls
- Health check endpoints return accurate liveness, readiness, and dependency status
- Contract tests pass in CI for consumer and provider
- gRPC protos versioned; REST clients typed with error handling
- Saga compensating actions defined, implemented, and tested
- Error responses use consistent contract with machine-readable codes
- Timeout budgets cascade correctly through call chains
- Distributed tracing shows end-to-end request flow
