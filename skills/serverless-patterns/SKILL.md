---
name: serverless-patterns
description: Implement serverless architecture patterns — Lambda/Edge Functions, event triggers, cold start optimization, and stateless design
metadata:
  version: 2.2
  argument-hint: "cloud provider (AWS/GCP/Azure), runtime, trigger types, expected concurrency"
---

Implement serverless architecture for $ARGUMENTS.


## Platform Selection

| Platform | Runtime | Max Duration | Cold Start | Best For |
|----------|---------|-------------|------------|----------|
| AWS Lambda | Node.js, Python, .NET, Java, Go, Rust | 15 min | 100ms-10s | Full-featured serverless, AWS ecosystem |
| Cloudflare Workers | V8 isolates (JS/TS/Wasm) | 30s / 15 min (paid) | <5ms | Edge computing, low latency, global |
| Vercel Edge Functions | V8 isolates (JS/TS) | 30s | <5ms | Next.js edge routes, middleware |
| Vercel Serverless Functions | Node.js | 60s (hobby) / 300s (pro) | 250ms-2s | Next.js API routes, SSR |
| Supabase Edge Functions | Deno | 150s max | 200-500ms | Supabase ecosystem |
| Lambda@Edge | Node.js, Python | 5s / 30s (origin) | 50-200ms | CloudFront transforms |
| Google Cloud Functions | Node.js, Python, Go, Java, .NET | 60 min (2nd gen) | 200ms-5s | GCP ecosystem |
| Azure Functions | Node.js, .NET, Python, Java | Unlimited (premium) | 1-10s | .NET ecosystem, Azure integration |

Decision: global low-latency API → Cloudflare Workers | Next.js edge middleware → Vercel Edge | Next.js API routes needing Node.js APIs → Vercel Serverless | Supabase backend → Supabase Edge | full AWS ecosystem → Lambda | .NET on Azure → Azure Functions | need >30s at edge → Lambda (not edge runtimes) | CDN transforms → Lambda@Edge or Cloudflare.

Edge vs traditional: edge (V8 isolate, <5ms cold start, <5MB bundle, 30s limit, 128MB memory, no file system, HTTP-only DB) vs traditional (full runtime, 100ms-10s cold start, TCP/VPC access, 10GB memory, /tmp, native modules). Use edge for latency-sensitive stateless lightweight ops; traditional for heavy compute, long-running, native dependencies.

## Cold Start Optimization

Causes: runtime init (200ms-5s) | code init (loading dependencies, 50ms-5s) | handler init (module-level code, variable).

**Bundle size:** tree-shake aggressively with esbuild/swc; use modular SDKs (`@aws-sdk/client-s3` not `aws-sdk`); target <5MB Lambda, <1MB edge.

**Lazy initialization:**
```typescript
// Module-level singletons persist across warm invocations
let prisma: PrismaClient | null = null;
function getDb() {
  if (!prisma) { const { PrismaClient } = require('@prisma/client'); prisma = new PrismaClient(); }
  return prisma;
}
```

**Provisioned concurrency (Lambda):** pre-warm N instances; use for user-facing latency-sensitive functions; schedule for predictable traffic (business hours); set `ProvisionedConcurrentExecutions: 5` in SAM Globals.

**Keep-warm:** CloudWatch Events ping every 5min — use only when provisioned concurrency too expensive; pings must be distinguishable from real invocations.

Cold start by runtime: Node.js 200-800ms (bundle with esbuild, lazy imports) | Python 200-800ms (minimize dependencies, use layers) | .NET 1-3s (ReadyToRun, trimming) | Java 3-10s (GraalVM native image, SnapStart) | Rust/Go 50-150ms (minimal concern).

.NET Lambda: `<PublishReadyToRun>true</PublishReadyToRun>`, `<PublishTrimmed>true</PublishTrimmed>`, `<TrimMode>link</TrimMode>`. Use `Amazon.Lambda.Annotations` for source-generated handlers; `Amazon.Lambda.RuntimeSupport` for Native AOT.

## Function Composition

**AWS Step Functions:** use for multi-step workflows with error handling and retry. Patterns: Sequential (A→B→C) | Parallel (simultaneous branches) | Fan-out/Fan-in (Map state) | Choice (conditional) | Wait (duration/timestamp) | Callback (pause + external token resume).

```json
{
  "ValidateOrder": { "Type": "Task", "Resource": "arn:...:validate-order", "Next": "ProcessPayment",
    "Catch": [{ "ErrorEquals": ["ValidationError"], "Next": "OrderFailed" }] },
  "ProcessPayment": { "Type": "Task", "Resource": "arn:...:process-payment", "Next": "FulfillOrder",
    "Retry": [{ "ErrorEquals": ["States.TaskFailed"], "MaxAttempts": 3, "BackoffRate": 2 }] }
}
```

**Queue chaining:** `Lambda A → SQS → Lambda B → SQS → Lambda C`. Each function independently retryable and scalable; DLQ per queue; idempotent handlers.

**Fan-out/fan-in:** `Trigger → Lambda (split N items) → SQS (N messages) → Lambda (process each, write DynamoDB) → DynamoDB Stream → Lambda (aggregate when complete)`.

Rules: use Step Functions for multi-step workflows; use SQS between functions for decoupled async; never chain Lambda invocations synchronously in code.

## State Management in Stateless Functions

External state stores: DynamoDB (key-value, session, counters, <10ms) | Redis/ElastiCache/Upstash (cache, rate limiting, <5ms) | S3 (large objects, checkpoints, 50-200ms) | SSM Parameter Store (config, feature flags) | Secrets Manager (credentials, API keys).

Connection reuse:
```typescript
// Module-level: persists across warm invocations
let cachedConfig: AppConfig | null = null;
let pool: Pool | null = null;

export async function handler(event: APIGatewayEvent) {
  if (!cachedConfig) cachedConfig = await loadConfig();
  const db = pool ??= new Pool({ connectionString: process.env.DATABASE_URL, max: 1, idleTimeoutMillis: 30000 });
}
```

Rules: always handle the cold path (never assume warm state); set TTL on cached values; `max: 1` connection per Lambda instance; use RDS Proxy for PostgreSQL/MySQL to avoid connection exhaustion; prefer HTTP-based DB clients for edge; never open/close connections per invocation.

Connection strategies: **RDS Proxy** (managed pooling for Aurora/RDS — preferred) | **Prisma Data Proxy** (managed, adds latency) | **HTTP-based databases** (PlanetScale, Neon, Supabase, Turso — no TCP).

## Edge Computing Patterns

**Cloudflare Workers:**
```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const country = request.headers.get('cf-ipcountry') ?? 'US';
    if (country === 'DE') return Response.redirect('https://de.example.com' + new URL(request.url).pathname);
    // A/B testing: const variant = hashMod(userId, 100) < 10 ? 'experiment' : 'control'
    // Cache: await caches.default.match(cacheKey) → ctx.waitUntil(caches.default.put(key, response.clone()))
    // KV: await env.MY_KV.get('key', 'json'); await env.MY_KV.put('key', data, { expirationTtl: 3600 })
    // D1: await env.DB.prepare('SELECT * FROM products WHERE category = ?').bind(category).all()
  }
};
```

**Vercel Edge Functions:**
```typescript
export const runtime = 'edge';
export async function GET(request: Request) {
  const country = request.headers.get('x-vercel-ip-country') ?? 'US';
  return Response.json({ message: 'Hello', country });
}
// proxy.ts in Next.js 16: check session cookie, redirect by geo, etc.
// export const config = { matcher: ['/((?!_next|api|static).*)'] }
```

**Supabase Edge Functions (Deno):**
```typescript
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data, error } = await supabase.from('webhooks').insert({ payload: await req.json() }).select().single();
  if (error) throw error;
  return new Response(JSON.stringify(data), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
});
```

Edge use cases: geolocation routing (cf-ipcountry / x-vercel-ip-country) | A/B testing (deterministic bucketing, cache per variant) | personalization (inject user content at edge, cache shell) | rate limiting (KV/Durable Objects) | auth validation (verify JWT at edge, reject before origin) | bot detection | image optimization.

## Cost Optimization

Pricing: AWS Lambda 1M free + $0.20/1M | Cloudflare Workers 100K req/day free | Vercel Edge 500K/mo hobby | Supabase Edge 500K/mo free.

Memory and CPU tuning (Lambda): more memory = proportionally more CPU; run AWS Lambda Power Tuning to find optimal; CPU-bound → increase memory until duration stops decreasing; I/O-bound → minimize memory (waiting for network doesn't use CPU).

Batching: `MaximumBatchingWindowInSeconds` on SQS to collect events before invoking; batch size 10-100 depending on processing time; also for DynamoDB Streams and Kinesis.

Reserved concurrency: `ReservedConcurrentExecutions: 100` to cap max instances and prevent cost runaway. Calculate: `peak_rps * avg_duration_seconds = needed_concurrency` + 20-50% headroom.

## API Patterns

**API Gateway + Lambda (SAM):**
```yaml
Resources:
  ApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: dist/handler.handler; Runtime: nodejs22.x; MemorySize: 256; Timeout: 29
      Events:
        GetItems: { Type: Api, Properties: { Path: /items, Method: get } }
```

**Lambda Function URL (no API Gateway):** use for simple HTTP endpoints; use API Gateway for custom domains, request validation, usage plans, WAF.

## Event Triggers

| Event Source | Trigger Type | Use Case |
|-------------|-------------|----------|
| API Gateway / Function URL | Synchronous | HTTP endpoints |
| SQS | Async (polling) | Task queues, decoupled processing |
| SNS | Async (push) | Fan-out notifications |
| S3 | Async (event) | File upload processing |
| EventBridge | Async (event) | Scheduled tasks, cross-service events |
| DynamoDB Streams | Async (polling) | Change data capture, sync |
| Kinesis | Async (polling) | Real-time streaming |
| CloudWatch Events | Async (scheduled) | Cron jobs |

SQS partial batch failure reporting:
```typescript
export const handler: SQSHandler = async (event) => {
  const failed: { itemIdentifier: string }[] = [];
  for (const record of event.Records) {
    try { await processMessage(JSON.parse(record.body)); }
    catch { failed.push({ itemIdentifier: record.messageId }); }
  }
  return { batchItemFailures: failed };
};
```

Cron: `Schedule: cron(0 9 * * ? *)` with `Input: '{"type": "daily-report"}'`.

## Deployment Patterns

**SAM:** `Globals.Function` for shared config; `AWS::Serverless::Function` with `Events`; `Policies` with named policies (DynamoDBCrudPolicy, SQSSendMessagePolicy).

**SST:** `new sst.aws.Dynamo`, `new sst.aws.ApiGatewayV2`, `api.route('GET /items', { handler, link: [table] })`.

**Serverless Framework:** `serverless.yml` with `provider`, `functions`, `events.httpApi`.

**Wrangler (Cloudflare):** `wrangler.toml` with `name`, `main`, `compatibility_date`, `[[kv_namespaces]]`.

## Monitoring and Observability

Structured logging:
```typescript
// JSON.stringify({ level, message, timestamp, requestId, functionName: process.env.AWS_LAMBDA_FUNCTION_NAME, ...context })
```

| Metric | Alert Threshold |
|--------|----------------|
| Duration | P95 > 80% of timeout |
| Errors | >1% of invocations |
| Throttles | >0 sustained |
| Cold starts | >20% of invocations |
| Concurrent executions | >80% of limit |
| Iterator age (streams) | >1 minute |
| DLQ messages | >0 |

Tracing: AWS X-Ray (built-in) | Datadog APM (`datadog-lambda-js`) | OpenTelemetry (`@opentelemetry/instrumentation-aws-lambda`).

## Testing

Local invocation: `sam local invoke ApiFunction -e events/get-items.json` | `sam local start-api` | `sls invoke local -f listItems` | `wrangler dev`.

Unit: mock APIGatewayEvent and context; test happy path + 401 for unauthenticated. Integration: SAM local or LocalStack; test full event path; verify DLQ behavior; test cold start path explicitly.

## Security

IAM roles: one role per function, minimum required permissions; never `*` resource in production; audit with IAM Access Analyzer.

Secrets: use SSM Parameter Store (free) or Secrets Manager (rotation support); cache in module-level variables (`if (!cachedSecret) cachedSecret = await ssm.GetParameter({WithDecryption: true})`); never hardcode.

VPC: use only when Lambda needs VPC resources (RDS, ElastiCache); adds 1-10s cold start — avoid unless necessary; use VPC endpoints for S3/DynamoDB/SQS; use RDS Proxy instead of direct RDS.

Input validation: validate all inputs at handler boundary with Zod; API Gateway request validation catches malformed requests pre-invocation; never trust event data from external sources.

## Anti-Patterns

Synchronous Lambda-to-Lambda calls (tight coupling, cascading failures, double billing — use Step Functions or SQS) | VPC Lambda for functions calling only public APIs (adds 1-10s cold start with no benefit) | direct DB connections without RDS Proxy (connection pool exhaustion; each warm instance holds a connection) | ignoring partial batch failure on SQS (entire batch retries, reprocessing succeeded messages).

## Implementation Workflow

1. Choose platform (latency, runtime, ecosystem)
2. Design function boundaries (one responsibility per function)
3. Select event sources and triggers
4. Set up deployment tooling (SAM, SST, Serverless, Wrangler)
5. Implement handler with input validation and error handling
6. Configure database connections with pooling/proxy
7. Set up monitoring, structured logging, and alerting
8. Optimize cold starts based on measured data
9. Configure security (IAM roles, secrets, VPC if needed)
10. Write unit and integration tests
11. Set cost alerts and reserved concurrency limits

## Output Format

```
Platform:          [AWS Lambda / Cloudflare Workers / Vercel Edge / Supabase Edge]
Runtime:           [Node.js / .NET / Python / V8 isolate]
Triggers:          [HTTP / SQS / S3 / Schedule / Stream]
Composition:       [Step Functions / SQS chaining / direct]
State:             [DynamoDB / Redis / KV / D1]
Database:          [connection strategy]
Deployment:        [SAM / SST / Serverless / Wrangler]
Cold Start:        [optimization approach]
Monitoring:        [logging, tracing, alerting]
Cost Controls:     [reserved concurrency, memory tuning]
```

## Done Criteria

- Functions deploy and execute within timeout limits
- Cold start measured and optimized (<500ms for user-facing functions)
- Database connections pooled or proxied appropriately
- IAM roles follow least privilege
- Secrets loaded from secure store, cached across warm invocations
- Async event sources have DLQ configured
- Structured logging with request correlation
- Monitoring alerts on error rate, duration, and throttles
- Cost within budget with reserved concurrency limits set
- Unit and integration tests cover happy path and error cases
- Deployment automated via CI/CD pipeline
