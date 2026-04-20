---
name: contract-testing
description: Implement consumer-driven contract testing with Pact, schema registries for event-driven systems, and API breaking-change detection
metadata:
  version: 1.2
  argument-hint: "consumer/provider service names, API type (REST/async event), contract format (Pact/OpenAPI), breaking-change detection scope"
---

Implement contract testing for $ARGUMENTS.


## Pact Consumer Tests (TypeScript)

```typescript
import { PactV4, MatchersV3 } from '@pact-foundation/pact';
const { like, eachLike, string, integer, datetime } = MatchersV3;

const provider = new PactV4({ consumer: 'OrderUI', provider: 'OrderService', dir: './pacts' });

describe('Order API contract', () => {
  it('returns order by id', async () => {
    await provider
      .addInteraction()
      .given('order 123 exists')
      .uponReceiving('a request for order 123')
      .withRequest('GET', '/api/orders/123', b => b.headers({ Accept: 'application/json' }))
      .willRespondWith(200, b =>
        b.headers({ 'Content-Type': 'application/json' }).jsonBody({
          id: string('123'),
          status: string('shipped'),
          items: eachLike({ productId: string(), quantity: integer(1), price: like(29.99) }),
          createdAt: datetime("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"),
        }),
      )
      .executeTest(async mockServer => {
        const client = new OrderClient(mockServer.url);
        const order = await client.getOrder('123');
        expect(order.id).toBe('123');
        expect(order.items.length).toBeGreaterThan(0);
      });
  });

  it('returns 404 for missing order', async () => {
    await provider
      .addInteraction()
      .given('order 999 does not exist')
      .uponReceiving('a request for non-existent order')
      .withRequest('GET', '/api/orders/999')
      .willRespondWith(404, b => b.jsonBody({ error: string('Order not found') }))
      .executeTest(async mockServer => {
        const client = new OrderClient(mockServer.url);
        await expect(client.getOrder('999')).rejects.toThrow('Order not found');
      });
  });
});
```

## Pact Provider Verification (TypeScript)

```typescript
import { Verifier } from '@pact-foundation/pact';

describe('Order Service provider verification', () => {
  it('validates contracts from all consumers', async () => {
    await new Verifier({
      providerBaseUrl: 'http://localhost:3001',
      pactUrls: ['./pacts/OrderUI-OrderService.json'],
      // or: pactBrokerUrl: 'https://pact-broker.example.com',
      stateHandlers: {
        'order 123 exists': async () => {
          await seedTestOrder({ id: '123', status: 'shipped', items: [{ productId: 'P1', quantity: 1, price: 29.99 }] });
        },
        'order 999 does not exist': async () => {
          await clearOrders();
        },
      },
      publishVerificationResult: process.env.CI === 'true',
      providerVersion: process.env.GIT_SHA,
      providerVersionBranch: process.env.GIT_BRANCH,
    }).verifyProvider();
  });
});
```

## Pact (.NET)

```csharp
// Consumer
[Fact]
public async Task GetOrder_WhenExists_ReturnsOrder()
{
    var pact = Pact.V4("OrderUI", "OrderService", new PactConfig { PactDir = "./pacts" });
    await pact
        .UponReceiving("a request for order 123")
        .Given("order 123 exists")
        .WithRequest(HttpMethod.Get, "/api/orders/123")
        .WillRespond()
        .WithStatus(HttpStatusCode.OK)
        .WithJsonBody(new { id = Match.Type("123"), status = Match.Type("shipped") })
        .VerifyAsync(async ctx =>
        {
            var client = new OrderClient(ctx.MockServerUri);
            var order = await client.GetOrderAsync("123");
            Assert.Equal("123", order.Id);
        });
}

// Provider
[Fact]
public async Task VerifyPacts()
{
    var config = new PactVerifierConfig { ProviderVersion = Environment.GetEnvironmentVariable("GIT_SHA") };
    new PactVerifier("OrderService", config)
        .WithHttpEndpoint(new Uri("http://localhost:5001"))
        .WithPactBrokerSource(new Uri("https://pact-broker.example.com"))
        .WithProviderStateUrl(new Uri("http://localhost:5001/_pact-states"))
        .Verify();
}
```

## Event Schema Registry

```typescript
// Avro schema for order events
const orderCreatedSchema = {
  type: 'record',
  name: 'OrderCreated',
  namespace: 'com.example.orders',
  fields: [
    { name: 'orderId', type: 'string' },
    { name: 'userId', type: 'string' },
    { name: 'totalAmount', type: 'double' },
    { name: 'currency', type: { type: 'enum', name: 'Currency', symbols: ['USD', 'EUR', 'GBP'] } },
    { name: 'createdAt', type: { type: 'long', logicalType: 'timestamp-millis' } },
  ],
};

// JSON Schema alternative
const orderCreatedJsonSchema = {
  $id: 'https://example.com/schemas/order-created/v2',
  type: 'object',
  required: ['orderId', 'userId', 'totalAmount', 'currency', 'createdAt'],
  properties: {
    orderId: { type: 'string', format: 'uuid' },
    userId: { type: 'string', format: 'uuid' },
    totalAmount: { type: 'number', minimum: 0 },
    currency: { type: 'string', enum: ['USD', 'EUR', 'GBP'] },
    createdAt: { type: 'string', format: 'date-time' },
  },
  additionalProperties: false,
};
```

## Pact Message Contracts (Events)

```typescript
import { PactV4 } from '@pact-foundation/pact';

// Consumer side — expects OrderCreated event
const messagePact = new PactV4({ consumer: 'NotificationService', provider: 'OrderService' });

describe('OrderCreated event contract', () => {
  it('processes order created event', async () => {
    await messagePact
      .addInteraction()
      .given('a new order is placed')
      .expectsToReceive('an OrderCreated event')
      .withContent(MatchersV3.like({ orderId: '123', userId: 'u1', totalAmount: 99.99, currency: 'USD' }), 'application/json')
      .executeTest(async message => {
        const handler = new OrderCreatedHandler();
        await handler.handle(JSON.parse(message.contents.toString()));
      });
  });
});
```

## Breaking Change Detection

```bash
# OpenAPI diff — detect breaking changes
npx openapi-diff previous-spec.yaml current-spec.yaml --breaking-only

# Or: oasdiff
oasdiff breaking --base prev.yaml --revision curr.yaml --fail-on ERR
```

Breaking changes: removed endpoint, removed required field from response, added required field to request, changed field type, narrowed enum values, changed status codes.

Non-breaking: added optional field to response, added optional query parameter, added new endpoint, widened enum values.

## CI Integration

```yaml
# Consumer CI
- run: npm test -- --testPathPattern=contract
- run: npx pact-broker publish ./pacts --consumer-app-version=$GITHUB_SHA --branch=$GITHUB_REF_NAME

# Provider CI
- run: npm run test:contract:provider
- run: npx pact-broker can-i-deploy --pacticipant=OrderService --version=$GITHUB_SHA --to-environment=production
```

`can-i-deploy` gates deployment: only deploy if all consumer contracts pass.

## Anti-Patterns

- No provider states -- tests depend on environment data that may not exist
- Overly strict matchers -- use `like()` for type matching to avoid false positives on unrelated changes
- Publishing contracts from feature branches without labels -- contaminates the main verification matrix
- No `can-i-deploy` gate -- contracts verified in isolation but not enforced at deployment

## Workflow

1. Identify service boundaries and integration points
2. Write consumer contract tests (what shape do I expect?)
3. Publish contracts to broker (or commit pact files)
4. Implement provider verification with state handlers
5. Add `can-i-deploy` to provider deployment pipeline
6. For events: add message pact or schema registry validation
7. Add OpenAPI breaking-change detection to API provider CI

Done: ✓ consumer contracts for all API dependencies ✓ provider verification with state handlers ✓ event contracts for async boundaries ✓ pact broker or file-based sharing ✓ can-i-deploy gate on provider deployment ✓ breaking change detection in CI ✓ schema versioning strategy defined
