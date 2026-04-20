---
name: backend-test-dotnet
description: ASP.NET Core testing with xUnit, WebApplicationFactory, EF Core in-memory vs real DB, FluentAssertions
metadata:
  version: 1.0
  domain: backend
  keywords: [dotnet, .net, csharp, c#, xunit, nunit, webapplicationfactory, integration test, ef core test, fluent assertions]
---

# Backend Test — .NET

Pair with `backend-test` for universal testing principles.

## Setup

- Use `xUnit` for all new projects — never MSTest for new code
- Use `WebApplicationFactory<TProgram>` for integration tests — boots real ASP.NET Core pipeline
- Use `FluentAssertions` for readable assertions — never bare `Assert.Equal` for complex objects
- Use a real test database (PostgreSQL/SQL Server via Docker or Testcontainers) — never `UseInMemoryDatabase` for integration tests (doesn't enforce constraints or transactions)
- Use `Testcontainers.MsSqlServer` or `Testcontainers.PostgreSql` for hermetic DB in CI

## WebApplicationFactory Pattern

- Create a custom `CustomWebApplicationFactory<TProgram>` that overrides `ConfigureWebHost`
- Override DB connection string in `ConfigureWebHost` to point to test DB
- Use `IClassFixture<CustomWebApplicationFactory<TProgram>>` — one factory instance per test class
- Use `CreateClient()` for HTTP calls — always test at HTTP boundary, not handler level

## Database

- Run migrations in test fixture setup: `dbContext.Database.Migrate()`
- Seed required data in constructor or `InitializeAsync` — never depend on pre-existing data
- Wrap each test in a transaction rolled back in `Dispose`/`DisposeAsync` — or truncate tables in `afterEach`
- Never `EnsureCreated()` in tests — migrations validate the real schema

## HTTP Testing

- Always assert both status code and response body: `response.StatusCode.Should().Be(HttpStatusCode.Created)`
- Deserialize response with `System.Text.Json` — never assert on raw string
- Test auth: always verify endpoint returns `401` without bearer token
- Test validation: always verify endpoint returns `400`/`422` with invalid request body

## Unit Testing Services

- Instantiate service under test directly with mocked dependencies — never `WebApplicationFactory` for pure unit tests
- Use `NSubstitute` or `Moq` for mocking interfaces — never mock concrete classes
- Never mock `DbContext` — use real EF Core with in-memory provider only for pure domain logic tests with no SQL constraints needed; for anything involving migrations or constraints use real DB

## Hard Rules

- Never `UseInMemoryDatabase` for integration tests — real DB or Testcontainers always
- Never mock `DbContext` for integration tests
- Always test auth enforcement (401/403) on every protected endpoint
- Always `FluentAssertions` — no bare `Assert.Equal` for response body comparisons
- Never share `HttpClient` instances across parallel tests — create per test class

## Done Criteria

- All API endpoints have integration tests via `WebApplicationFactory` + `HttpClient`
- Auth enforcement tested (401 without token)
- Validation rejection tested (400/422 with invalid body)
- Real DB (or Testcontainers) used — no `UseInMemoryDatabase` for integration tests
- Test DB seeded and cleaned between tests
- `FluentAssertions` used throughout
