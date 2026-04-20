---
name: backend-refactor
description: Refactor existing backend code in .NET, ASP.NET Core, Node.js, Bun, NestJS, Elysia, TypeScript, or JavaScript applications
metadata:
  version: 2.0
  argument-hint: "code/module path, refactoring goal (performance/maintainability/testing), constraints (breaking changes/backwards compat), scope (single service/cross-service)"
---

Refactor $ARGUMENTS.

Core refactoring principles:

- Preserve existing business behavior unless the user explicitly requests functional changes
- Prefer safe, incremental refactoring over large rewrites
- Follow existing project conventions unless they are clearly harmful
- Reduce duplication, complexity, hidden coupling, and accidental side effects
- Keep endpoints, handlers, services, jobs, and integrations focused with separated concerns
- Avoid over-engineering; prefer small composable units over monolithic services
- Keep runtime validation and compile-time typing aligned
- Derive TypeScript types from Zod schemas where appropriate

Refactoring priorities:

- duplicated logic and oversized services/handlers
- weak typing and noisy contracts
- repeated database calls and downstream HTTP calls
- fragile async flows and hidden side effects
- poor schema/type separation and validation duplication
- bad query shaping and misuse of framework APIs
- unnecessary repository/service indirection
- transaction boundary confusion and poor error handling

Dependencies and imports:

- Prefer existing project dependencies over new libraries
- Prefer framework-native solutions before third-party packages
- Keep imports clean; remove unused imports; prefer explicit named imports

Module and service architecture:

- Reduce responsibility when handlers or services do too much
- Avoid bloated services combining transport, business logic, validation, and persistence
- Prefer explicit boundaries between API, application, and infrastructure layers
- Remove harmful indirection that adds no architectural value

Example — extract service from a bloated controller:

Before:

```typescript
// controller doing validation, business logic, and persistence
@Post('/orders')
async createOrder(@Body() body: any) {
  if (!body.items?.length) throw new BadRequestException('Items required');
  const total = body.items.reduce((sum, i) => sum + i.price * i.qty, 0);
  if (total <= 0) throw new BadRequestException('Invalid total');
  const order = this.repo.create({ ...body, total, status: 'pending' });
  await this.repo.save(order);
  await this.emailService.send(body.email, 'Order confirmed', { orderId: order.id });
  return order;
}
```

After:

```typescript
// schema — validates at the boundary
const CreateOrderSchema = z.object({
  email: z.string().email(),
  items: z.array(z.object({
    productId: z.string().uuid(),
    price: z.number().positive(),
    qty: z.number().int().positive(),
  })).min(1),
});
type CreateOrderDto = z.infer<typeof CreateOrderSchema>;

// service — owns business logic
@Injectable()
export class OrderService {
  async create(dto: CreateOrderDto): Promise<Order> {
    const total = dto.items.reduce((sum, i) => sum + i.price * i.qty, 0);
    const order = await this.repo.save(
      this.repo.create({ ...dto, total, status: 'pending' }),
    );
    await this.emailService.sendOrderConfirmation(dto.email, order.id);
    return order;
  }
}

// controller — thin transport layer
@Post('/orders')
async createOrder(@Body(ZodPipe(CreateOrderSchema)) dto: CreateOrderDto) {
  return this.orderService.create(dto);
}
```

State and flow management:

- Keep state ownership explicit and localized; eliminate hidden mutable shared state
- Prefer deterministic data flow over implicit side effects
- Simplify orchestration when state propagation causes fragility

Async and I/O:

- Eliminate duplicate requests and repeated I/O; parallelize independent operations when safe
- Handle success, failure, retry, timeout, and cancellation explicitly
- Keep DTOs, domain models, persistence models, and response models separated
- Remove unnecessary async indirection

Performance and efficiency:

- Eliminate unnecessary allocations, database round-trips, and downstream HTTP calls
- Prefer batching, projection, and efficient query shaping
- Avoid blocking calls inside async flows; reduce chatty persistence flows

Validation and contracts:

- Refactor toward explicit boundary validation with schema-driven approach
- Remove duplicated or contradictory validation logic
- Keep contracts explicit and stable

Error handling and reliability:

- Handle expected failures explicitly; avoid swallowing exceptions
- Ensure retries, idempotency, deduplication where side effects exist
- Refactor toward clearer failure semantics

Anti-patterns to avoid:

- Large rewrites when targeted refactoring is sufficient
- God-services, god-handlers, sync-over-async, blocking I/O in async flows
- Mixing validation, persistence, HTTP, integration, and business logic in one place
- Hidden side effects; speculative architecture; clever abstractions that reduce readability
- Changing behavior while claiming "just refactoring"

Testing and observability:

- Prefer refactors that keep code testable with explicit seams for mocking
- If tests exist, update them when structure or contracts change
- Follow existing logging/telemetry patterns; avoid noisy logs

Type modeling:

- Strong types over weakly typed dictionaries; keep shared contracts/DTOs in dedicated files
- Move non-trivial types into colocated type files; do not centralize unrelated types
- Use advanced type features for safety, not cleverness; avoid any and weak typing
- Derive types from schemas rather than duplicating shapes

Validation and schemas:

- Prefer Zod in TS/JS backends; schema-first modeling with derived types
- In .NET, prefer the project's established validation approach
- Refactor toward consistent schema-based validation when existing validation is fragmented

API and transport design:

- Explicit request/response contracts; stable, predictable, bounded API shape
- Do not return persistence entities directly; keep handlers thin
- All list endpoints: paginated, no unbounded result sets
- Explicit versioning for public APIs; preserve backward compatibility
- Refactor noisy or leaky transport contracts toward clearer boundaries

OpenAPI documentation:

- Keep OpenAPI docs aligned with runtime validation; update docs after contract changes
- .NET: for .NET 9+, prefer built-in `Microsoft.AspNetCore.OpenApi` (`AddOpenApi()` + `MapOpenApi()`); Swashbuckle remains valid for existing projects and Swagger UI
- NestJS: @nestjs/swagger with decorated controllers/DTOs
- Node.js/Bun/Elysia: derive docs from validation schemas

Persistence refactoring:

- Keep the project's established persistence technology; do not rewrite unnecessarily
- Improve query clarity, performance, and boundaries rather than adding new abstractions
- Avoid repository layers that only wrap an ORM without business value

.NET persistence:

- EF Core default; remove unnecessary repository wrappers
- Refactor toward explicit projection and AsNoTracking for reads
- Dapper for query-heavy read paths; parameterized queries; complex SQL in dedicated modules

TypeORM (Node.js/NestJS/Bun):

- Follow existing patterns; QueryBuilder for complex queries
- Do not leak ORM entities through API contracts
- Use transaction-scoped entity manager; refactor duplicated query logic into data-access modules

Inline SQL rules:

- Move large inline SQL to dedicated query modules; never concatenate user input

Database and persistence:

- Efficient queries, explicit persistence boundaries, explicit transaction boundaries
- Avoid excess data loading; prefer projection at the database
- Avoid N+1 patterns; prefer pagination for list endpoints
- Refactor query and transaction boundaries when they cause complexity

Background jobs and messaging:

- Focused handlers; validate payloads at boundary; prefer idempotent handlers
- Handle retries, deduplication, timeout, cancellation, and partial failures
- Refactor side-effect-heavy job logic toward clearer orchestration

External integrations:

- Focused integration services; validate external payloads at boundary
- Explicit timeout, retry, and error handling; normalize provider data at the boundary

Security:

- Validate all external input at boundary; never trust raw payloads
- Explicit authorization checks; keep sensitive operations auditable
- Refactor insecure boundary behavior toward explicit checks

.NET / ASP.NET Core non-negotiable rules:

- Async all the way; no sync-over-async; use CancellationToken where relevant
- Do not leak EF entities through API contracts
- No business logic in controllers when a service boundary is warranted
- Explicit validation at the boundary; modern .NET APIs preferred
- For new .NET 9 projects, prefer minimal APIs with `MapGroup` and `TypedResults`; reserve MVC controllers for existing codebases. `Startup.cs` with separate `Configure`/`ConfigureServices` is pre-.NET 6 — do not generate.

Node.js / Bun:

- Explicit module boundaries; no hidden mutable process-wide state
- Do not block the event loop; explicit async error handling
- Zod for validation and schema modeling
- Refactor callback-style or fragmented async flows when safe

NestJS non-negotiable rules:

- No heavy business logic in controllers; no unnecessary providers/modules
- Explicit validation at the boundary; narrow testable services
- Refactor overgrown modules toward narrower responsibilities

Bun / Elysia non-negotiable rules:

- No unnecessary architectural weight for small features
- Schema-first request validation; colocated route contracts and handlers
- Refactor toward simpler route-level boundaries when overly abstract

Refactoring workflow:

1. Detect the framework, runtime, and conventions used in the codebase
2. Understand the feature boundary, surrounding architecture, and current behavior
3. Identify the highest-value safe refactors before making changes
4. Prefer targeted improvements over broad rewrites
5. Reuse existing utilities, services, schemas, types, and patterns
6. Ensure async flows, validation, and I/O behavior become simpler and more efficient
7. Ensure contracts, schemas, and models are placed in appropriate dedicated files when non-trivial
8. Summarize what was changed, what risks remain, and what further improvements are optional

Output requirements:

- Start with a short diagnosis of the main issues found
- Propose a concise refactoring plan before large structural changes
- Produce concrete production-ready code, not only advice
- Follow the idioms of the detected framework and runtime
- Preserve intended behavior unless the user explicitly asks for functional or product changes

## Tool Integration

- **ast-grep**: use for structural code pattern search (find function signatures, class usages, import patterns) — faster and more accurate than Grep for code structure

## LSP Workflow (TypeScript/JavaScript)
After every file edit:
1. Call available diagnostics tools to check for type errors
2. Fix all errors before proceeding to the next file
3. Never use `tsc --noEmit`, `npm run build`, or any compiler CLI — LSP is the single source of truth
4. If LSP results appear stale (error on a line that no longer exists), wait 2s and retry once

## Structured Output Contract
- **Status**: `done` | `partial` | `blocked`
- **Changed**: `[file.ext: +lines/-lines, ...]` — list every modified file
- **Notes**: blockers or non-obvious decisions only — omit if none

Do NOT return prose summaries or recaps.
