---
name: backend-implement-dotnet
description: ASP.NET Core 8+ patterns — minimal APIs, EF Core 8, FluentValidation, ProblemDetails, structured logging
metadata:
  version: 1.0
  domain: backend
  keywords: [dotnet, .net, csharp, c#, aspnet, asp.net core, minimal api, ef core, entity framework, web api, fluent validation, problem details]
---

# Backend Implement — .NET

Pair with `backend-implement` for universal rules.

## API Style

- Prefer Minimal APIs for new endpoints in .NET 8+ — Controllers only for complex filter pipelines
- Always use typed `Results<T1, T2>` return types — never bare `IResult` (loses type information)
- Group related endpoints with `MapGroup()` — never scatter `app.Map*` calls without organization
- Always `.WithTags()` and `.WithName()` on endpoints — required for OpenAPI/Swagger generation
- Use endpoint filters (`IEndpointFilter`) for cross-cutting concerns — never duplicated logic per handler

## Validation

- Use `FluentValidation` for all request models — never manual `if` chains for validation
- Register validators via `builder.Services.AddValidatorsFromAssemblyContaining<T>()`
- Return `ValidationProblem()` (RFC 7807 compliant) on validation failure — never custom error shapes
- Validate at the API boundary — never pass unvalidated models into services or repositories

## Dependency Injection

- Register with correct lifetime: `AddScoped` for per-request (DbContext), `AddSingleton` for stateless, `AddTransient` for lightweight
- Never `new` a service that has DI dependencies — always resolve through the container
- Never inject `IServiceProvider` to manually resolve — signals a design problem, fix the dependency graph
- Use `IOptions<T>` for typed configuration — never `IConfiguration["key"]` string indexing in services

## Entity Framework Core 8

- Always use migrations — never `EnsureCreated()` outside of tests
- Never lazy loading (`UseLazyLoadingProxies`) — always explicit `.Include()` / `.ThenInclude()`
- Always `AsNoTracking()` for read-only queries — never track entities you will not modify
- Call `SaveChangesAsync()` once per unit of work — never once per entity in a loop
- Always scope `DbContext` — never singleton, never static
- Use compiled queries (`EF.CompileAsyncQuery`) for hot paths queried frequently

## Error Handling

- Use `IExceptionHandler` (registered via `builder.Services.AddExceptionHandler<T>()`) — never try/catch in every handler
- Always return `ProblemDetails` (RFC 7807) for errors — never custom error response shapes
- Use `ILogger<T>` everywhere — never `Console.Write`, `Debug.WriteLine`, or `Trace`
- Always structured log parameters: `_logger.LogError(ex, "Order {OrderId} failed", orderId)` — never string interpolation in log calls

## Auth

- Use `.RequireAuthorization()` on `MapGroup()` — never per-endpoint auth checks as inline code
- Policy-based auth for business rules — never role string comparisons in handlers or services
- Always validate JWT `iss`, `aud`, `exp`, `nbf` — never accept tokens without full claim validation

## Hard Rules

- Never `EnsureCreated()` in production — migrations always
- Never lazy loading — explicit `Include()` always
- Never `Console.Write` or `Debug.WriteLine` — `ILogger<T>` always
- Never string interpolation in log messages — structured logging always
- Never singleton `DbContext`
- Never `IConfiguration["key"]` string access in services — `IOptions<T>` always
- Never untyped `IResult` return from endpoints — `Results<T1, T2>` always

## Done Criteria

- All endpoints return `ProblemDetails` on error
- All request models validated with FluentValidation at API boundary
- No `EnsureCreated()` anywhere in production code paths
- No lazy loading — all related data via explicit Include
- Structured logging with `ILogger<T>` throughout — no Console calls
- LSP reports zero errors
