---
name: api-gateway-design
description: Design API gateway and BFF architecture with request routing, rate limiting, circuit breakers, auth at edge, header propagation, and caching
metadata:
  version: 1.3
  argument-hint: "gateway type (Kong/AWS API Gateway/custom), auth at edge (required/optional), rate limiting policy, backend services to route, caching strategy"
---

Design the API gateway architecture for $ARGUMENTS.

## Tool Integration

- **Language diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone


## Gateway Patterns

### Routing

Path-based routing (most common):

```
/api/users/**     -> user-service:8080
/api/orders/**    -> order-service:8080
/api/payments/**  -> payment-service:8080
/api/search/**    -> search-service:8080
```

- Use path prefix matching with longest-prefix-wins semantics
- Strip the gateway prefix before forwarding when upstream services use root paths
- Support versioned routing: `/v1/users` and `/v2/users` to different upstreams or service versions
- Route by header for canary deployments: `X-Canary: true` routes to canary upstream

Host-based routing:

```
api.example.com       -> api-gateway
admin.example.com     -> admin-bff
webhooks.example.com  -> webhook-ingress
```

- Use host-based routing to separate public API, admin, and webhook traffic
- Each subdomain can have different auth, rate limiting, and security policies

### Request Aggregation

- Gateway combines multiple upstream calls into a single client response
- Use when the client would otherwise make 3+ sequential calls
- Set a timeout on aggregated requests: if one upstream is slow, return partial data or error
- Mark aggregated fields as optional in the response contract to handle partial failures

```
GET /api/dashboard
  -> GET user-service/me
  -> GET order-service/orders?userId={id}&limit=5
  -> GET notification-service/unread-count?userId={id}
  <- { user: {...}, recentOrders: [...], unreadNotifications: 3 }
```

### Request/Response Transformation

- Add, remove, or rename headers before forwarding to upstream
- Transform request body shape when client contract differs from upstream
- Redact sensitive headers from upstream responses (internal trace IDs, server versions)
- Add correlation ID header if not present: `X-Correlation-Id: <uuid>`

## Authentication at the Gateway

### Token Validation at Edge

- Validate JWT signature, expiration, issuer, and audience at the gateway
- Extract claims (user ID, roles, scopes) and forward as headers to upstream services
- Upstream services trust gateway-injected headers; do not re-validate the JWT
- Use asymmetric key validation (RS256/ES256) at the gateway to avoid sharing secrets

Header propagation after auth:

```
Gateway validates JWT -> extracts claims -> forwards:
  X-User-Id: user-123
  X-User-Roles: admin,editor
  X-User-Org: org-456
  X-Correlation-Id: req-789
```

### API Key Authentication

- Validate API keys at the gateway against a key store (Redis, database)
- Map API key to client identity, tier, and rate limit group
- Forward client identity headers to upstream; never forward the raw API key
- Support key rotation: accept both old and new keys during rotation window

### Auth Bypass for Public Endpoints

- Define explicit allowlist of unauthenticated paths: `/health`, `/docs`, `/public/**`
- All other routes require authentication by default (deny-by-default)
- Never rely on upstream services to reject unauthenticated requests

## Rate Limiting

### Strategy

| Scope | Granularity | Use case |
|-------|-------------|----------|
| Per API key | Key ID | Server-to-server, third-party integrations |
| Per user | User ID from JWT | Authenticated user requests |
| Per IP | Client IP (with X-Forwarded-For) | Anonymous/public endpoints |
| Per endpoint | Path + method | Protect expensive operations |
| Per tier | Subscription plan | Differentiated service levels |

### Algorithm Selection

| Algorithm | Behavior | Best for |
|-----------|----------|----------|
| Fixed window | Reset counter every N seconds | Simple, low overhead |
| Sliding window | Rolling window of N seconds | Smoother distribution |
| Token bucket | Tokens refill at steady rate, allow bursts | Bursty traffic patterns |
| Leaky bucket | Process at fixed rate, queue excess | Strict rate enforcement |

- Use token bucket for most APIs: allows short bursts while maintaining average rate
- Use sliding window for strict per-second limits
- Store counters in Redis for distributed rate limiting across gateway instances

### Rate Limit Headers

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 742
X-RateLimit-Reset: 1620000000
Retry-After: 30
```

- Return rate limit headers on every response, not just 429
- Return `Retry-After` header with 429 responses
- Use seconds (not timestamp) for `Retry-After` for simplicity

## Circuit Breakers

### States

```
Closed (normal) -> Open (failing) -> Half-Open (testing recovery)
     ^                                      |
     |______________________________________|
              (success in half-open)
```

### Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| Failure threshold | 5 failures in 10s | Trips to open |
| Open duration | 30s | Time before half-open |
| Half-open max requests | 3 | Requests allowed to test recovery |
| Success threshold | 2 consecutive | Resets to closed |
| Timeout | 5s | Request timeout before counting as failure |

### Fallback Strategies

- Return cached response (stale data is better than no data)
- Return degraded response with missing optional fields
- Return 503 with `Retry-After` header
- Route to a backup/fallback service

### Per-Upstream Circuit Breakers

- Each upstream service has its own circuit breaker instance
- A failing payment service should not break user profile lookups
- Monitor circuit breaker state transitions as operational metrics
- Alert on circuit breaker trips: open state indicates upstream degradation

## Caching at the Edge

### Cache Strategy

| Content | Cache | TTL | Invalidation |
|---------|-------|-----|-------------|
| Static config/reference data | Yes | 5-60 min | Event-driven or TTL |
| User-specific data | Conditional | 1-5 min | On write or TTL |
| Search results | Yes | 1-5 min | TTL |
| Mutation responses | Never | N/A | N/A |
| Auth tokens/sessions | Never | N/A | N/A |

- Use `Cache-Control` headers from upstream to drive gateway caching
- Cache GET requests only; never cache POST/PUT/PATCH/DELETE
- Include `Authorization` header in cache key for user-specific responses (or use `Vary: Authorization`)
- Use `Surrogate-Key` headers for targeted cache invalidation

### Conditional Caching

- Support `ETag` and `If-None-Match` at the gateway level
- Return 304 Not Modified when content has not changed
- Reduces bandwidth without serving stale data

## BFF (Backend-for-Frontend)

### When to Use BFF

- Multiple client types with different data needs (web, mobile, admin)
- Client requires aggregated data from multiple microservices
- Client needs transformed data shapes (mobile needs compact payloads)
- Authentication strategy differs per client (cookies for web, tokens for mobile)

### BFF Architecture

```
Web App    -> Web BFF    -> Microservices
Mobile App -> Mobile BFF -> Microservices
Admin App  -> Admin BFF  -> Microservices
```

### BFF Design Rules

- One BFF per client type; do not share a BFF across web and mobile
- BFF owns the client contract; upstream services own their domain contract
- BFF handles: aggregation, transformation, caching, auth token management
- BFF does NOT handle: business logic, data validation, persistence
- Keep BFFs thin: orchestration and mapping only
- BFF is part of the frontend team, not the backend team

### BFF for SPAs (Token Management)

- BFF stores OAuth tokens server-side; frontend uses httpOnly session cookies
- BFF handles token refresh transparently
- BFF proxies API calls with the access token from server-side store
- Eliminates token exposure in browser JavaScript

## Health Checks and Observability

### Gateway Health Endpoints

```
GET /health          -> Gateway process health
GET /health/ready    -> Gateway + all upstreams healthy
GET /health/live     -> Gateway process alive
```

- `/health/ready` checks upstream connectivity: DNS resolution + TCP connect + HTTP health endpoint
- Mark upstream as unhealthy after 3 consecutive health check failures
- Remove unhealthy upstreams from load balancer rotation
- Re-add after 2 consecutive successful health checks

### Observability

Metrics to emit per upstream:

| Metric | Type | Purpose |
|--------|------|---------|
| Request count | Counter | Traffic volume |
| Error count (4xx, 5xx) | Counter | Error rate |
| Latency (P50, P95, P99) | Histogram | Performance |
| Circuit breaker state | Gauge | Upstream health |
| Rate limit hits | Counter | Client behavior |
| Cache hit/miss ratio | Counter | Cache effectiveness |

- Add correlation ID to every request for distributed tracing
- Log: method, path, upstream, status code, latency, correlation ID
- Use structured logging (JSON) for machine-parseable log aggregation

## Load Balancing

### Strategies

| Strategy | Use case |
|----------|----------|
| Round robin | Default, equal-capacity instances |
| Weighted round robin | Mixed-capacity instances |
| Least connections | Varying request durations |
| IP hash | Session affinity (sticky sessions) |
| Random with two choices | Low-overhead, good distribution |

- Use health-check-aware load balancing: skip unhealthy instances
- Support graceful drain: stop routing to instances shutting down
- Sticky sessions for WebSocket connections (required for stateful protocols)

## Technology-Specific Patterns

### YARP (.NET)

- Configure in `appsettings.json` or programmatically via `IReverseProxyConfig`
- Use transforms for header manipulation, path rewriting, and request modification
- Integrate with ASP.NET Core middleware pipeline for auth, rate limiting, logging
- Support dynamic configuration reload without restart

### Kong

- Use declarative configuration (`kong.yml`) for version-controlled setup
- Leverage built-in plugins: rate-limiting, jwt, cors, request-transformer
- Custom plugins in Lua or Go for domain-specific logic
- Use DB-less mode for immutable infrastructure deployments

### AWS API Gateway

- Use HTTP API (v2) for lower latency and cost; REST API (v1) for advanced features
- Integrate with Lambda authorizers for custom auth logic
- Use usage plans and API keys for tiered rate limiting
- Enable CloudWatch metrics and X-Ray tracing for observability

### Nginx

- Use `upstream` blocks with health checks for load balancing
- Use `proxy_pass` with `proxy_set_header` for routing and header propagation
- Use `limit_req_zone` for rate limiting
- Use OpenResty for programmable Lua-based request handling

### Traefik

- Auto-discovery from Docker labels or Kubernetes Ingress annotations
- Middleware chain: rate limiting -> auth -> circuit breaker -> retry
- Built-in Let's Encrypt for automatic TLS certificate management
- Dashboard for real-time routing and middleware visibility

## Security at the Gateway

- Terminate TLS at the gateway; use mTLS for gateway-to-upstream communication in zero-trust networks
- Validate and sanitize all incoming headers; strip unexpected headers
- Set security headers on all responses: `Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options`
- Block requests with oversized bodies before forwarding to upstream
- IP allowlisting/blocklisting for admin and internal endpoints
- CORS handling at the gateway: validate `Origin`, set `Access-Control-*` headers

## Anti-Patterns

- Single gateway for all traffic types -- public API, admin, and webhook gateways have different auth and rate limit requirements
- Caching authenticated responses without proper key variation -- causes cross-user data leaks
- Rate limiting only at the application level -- the gateway is the only choke point before services are overwhelmed
- Sharing a BFF across different client types -- defeats per-client payload and auth optimization
- No correlation ID propagation -- impossible to trace a request across service boundaries

## Output Format

For each gateway design:

```
Gateway:           [technology and deployment model]
Routing:           [path-based, host-based, header-based rules]
Authentication:    [JWT validation, API key, OAuth — what happens at the edge]
Rate Limiting:     [algorithm, scope, limits per tier]
Circuit Breakers:  [thresholds, fallback strategy per upstream]
Caching:           [what is cached, TTL, invalidation approach]
BFF:               [per-client BFF structure, if applicable]
Load Balancing:    [strategy, health check configuration]
Observability:     [metrics, logging, tracing approach]
Security:          [TLS, headers, CORS, IP restrictions]
```

Output rules:

- Provide concrete configuration or code for the chosen gateway technology
- Define routing rules with exact path patterns and upstream targets
- Specify rate limit numbers per tier and endpoint category
- Include circuit breaker thresholds and fallback behavior
- Document header propagation: which headers are added, removed, or forwarded
