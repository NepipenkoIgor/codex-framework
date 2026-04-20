---
name: fullstack-blazor-test
description: Write unit, component, and integration tests for Blazor apps — bUnit, xUnit, EF Core in-memory, and Playwright E2E
metadata:
  version: 1.5
  argument-hint: "component/service to test, test type (unit/integration/E2E), bUnit or Playwright"
---

Write tests for $ARGUMENTS.


## Tool Integration

- **Compiler diagnostics**: run available diagnostics tools after every code change for compiler diagnostics
- docs lookup tools: fetch current Blazor/ASP.NET docs before implementing

Stack: Blazor (Server/WASM), .NET 8+, MudBlazor, EF Core/Dapper, bUnit.

Testing philosophy:

- Prefer behavior-driven tests over implementation detail tests
- Test observable behavior, public contracts, state transitions, rendering outcomes, side effects, and failure paths
- Avoid trivial tests (should create, component exists, page renders, truthy checks)
- Prefer meaningful coverage over artificial metrics; prefer high-signal tests over large quantities

Prefer tests that verify:

- rendered UI behavior, user interactions, state transitions, validation behavior
- loading/empty/success/error states, async correctness, data-loading flows
- table paging/filtering/sorting, dialog open/confirm/cancel/result handling
- contract behavior, mapping/transformation, edge cases, backend request/response behavior

Test runner and framework policy:

- Use the testing framework already present in the repository
- Do not switch test stack unless the user explicitly asks
- Ensure tests are fast, deterministic, isolated, and parallelizable when safe

Testing strategy:

- Component tests for page, component, dialog, and form rendering behavior
- Unit tests for pure business logic, mapping, transformation, validation, orchestration
- Integration tests when correctness depends on framework wiring, persistence, or transport contracts
- Test high-risk and high-change areas first; use the smallest scope that verifies meaningful behavior

Boundary and contract testing:

- Test request/response behavior at service boundaries; test form/action/dialog/table models
- Test mapping between transport, domain, persistence, and UI models where meaningful
- Verify invalid input rejection and that failures preserve useful semantics without leaking internals

Async and reliability testing:

- Test loading, empty, success, error, cancellation, and timeout states explicitly
- Test duplicate submission/action handling; ensure tests are deterministic and not timing-fragile

Rendering and interaction testing:

- Test through rendered behavior; interact as a user would
- Verify rendered state before/after meaningful actions; test conditional rendering and state-driven UI
- Avoid brittle markup assertions when behavioral assertions are possible

Example -- bUnit test verifying a counter component increments on button click:

```csharp
using Bunit;
using Xunit;

public class CounterTests : TestContext
{
    [Fact]
    public void ClickingIncrementButton_UpdatesCount()
    {
        // Arrange
        var cut = RenderComponent<Counter>();

        // Act
        cut.Find("button").Click();

        // Assert -- verify rendered output, not internal state
        cut.Find("[data-testid='count']").MarkupMatches("<span data-testid=\"count\">1</span>");
    }

    [Fact]
    public void InitialRender_ShowsZeroCount()
    {
        var cut = RenderComponent<Counter>();

        cut.Find("[data-testid='count']").TextContent.MarkupMatches("0");
    }

    [Fact]
    public async Task LoadData_ShowsLoadingThenContent()
    {
        // Arrange -- register a mock service
        var tcs = new TaskCompletionSource<List<Item>>();
        Services.AddSingleton(Mock.Of<IItemService>(s =>
            s.GetItemsAsync() == tcs.Task));

        var cut = RenderComponent<ItemList>();
        cut.Find(".loading-indicator").ShouldNotBeNull();

        // Act -- complete the async load
        tcs.SetResult(new List<Item> { new("Widget") });
        cut.WaitForState(() => cut.FindAll(".item-row").Count > 0);

        // Assert
        Assert.Single(cut.FindAll(".item-row"));
    }
}
```

Forms and validation testing:

- Test input behavior, validation rules/feedback, submit/loading/failure handling
- Test disabled states and duplicate submit prevention; verify alignment with backend contracts

Dialog and action-flow testing:

- Test open/close/confirm/cancel flows and result propagation
- Test destructive action confirmation and button enablement/loading states

MudBlazor-specific testing:

- Test MudTable, MudDataGrid, dialog, form workflows through meaningful rendered behavior
- Verify paging, filtering, sorting, selection; test server-side data-loading scenarios
- Avoid testing MudBlazor internals; verify feature behavior and state transitions

State and logic testing:

- Test state transitions, derived/computed values, and rendered outcomes
- Test empty, loading, and failure scenarios; prefer public boundary testing

Persistence and backend-boundary testing:

- Test query behavior when filtering, sorting, paging, projection matter
- Test persistence-sensitive business behavior rather than ORM internals
- Prefer realistic scenarios; avoid overly mocking when real interaction is the risk

EF Core testing:

- Verify query behavior, projection, paging, transaction-sensitive flows
- Prefer integration tests when real query translation or constraints matter
- Do not reduce all tests to mocked DbSet when real database interaction is the risk

Dapper testing:

- Prefer integration tests for SQL correctness, result mapping, and projections
- Test returned contracts rather than only asserting query methods were called

External integrations and messaging:

- Mock external systems for local orchestration/error handling tests
- Test webhook parsing, retry, idempotency, timeout, and normalization where relevant

JavaScript interop testing:

- Test only when component behavior depends on it; mock interop cleanly
- Verify observable results (focus, clipboard, measurements) only when materially affecting the feature

Validation and schema testing:

- Test valid inputs, invalid inputs, boundary conditions, normalization, and parsing
- Verify contract validation and rendered feedback match expected behavior

Type and contract awareness:

- Use typed mocks, fixtures, and builders; prefer explicit contract assertions
- Avoid weakly typed helpers; ensure test helpers preserve type safety

Mocking principles:

- Mock external services (HTTP, queues, email, caches, JS interop) to isolate local behavior
- Avoid over-mocking that hides real contract issues; prefer realistic test data
- Prefer fakes/test doubles over fragile mock chains when that improves clarity

Performance considerations:

- Avoid heavy setups and redundant tests; keep tests fast and deterministic
- Prefer smaller focused suites over monolithic scenario tests

Test structure:

- Group related tests logically; use clear descriptive names
- Prefer Arrange/Act/Assert; keep test code simple and readable

Test coverage priorities:

High priority: validation, orchestration pages/components, forms, dialogs, tables with paging/filtering/sorting, async data-loading, error handling, state transitions, backend logic, integration boundaries, authorization behavior, JS interop boundaries.

Lower priority: trivial framework wiring, passive data containers, purely mechanical pass-through code, static markup.

.NET / ASP.NET Core testing:

- Test services, handlers, pages through meaningful public behavior
- Unit tests for business logic; integration tests for API endpoints, serialization, authorization, persistence
- Test async behavior properly; respect CancellationToken semantics; test contracts and failure paths

.NET testing non-negotiable rules:

- No trivial "should be created" tests; no testing private details without behavioral value
- No ignoring async behavior; no hiding behavior behind excessive mocks

Blazor testing:

- Test pages and components through observable rendered behavior
- Test parameters, callbacks, data loading, validation, and action flows meaningfully

Blazor testing non-negotiable rules:

- No trivial component existence tests; no private field/method tests without behavioral value
- No fragile markup assertions when stable behavioral assertions are possible

MudBlazor testing guidance:

- Test feature behavior, not MudBlazor internals
- Test tables, dialogs, forms through meaningful rendered outcomes and state transitions

JavaScript interop testing guidance:

- Prefer isolated mocks for JS interop boundaries
- Avoid low-value tests that only assert an interop call occurred without validating behavior

Styling and CSS awareness:

- Test styling-driven behavior only when it changes interaction, visibility, state, or accessibility
- Verify disabled/hidden/expanded/selected/loading states when functionally meaningful

Security and boundary hygiene:

- Test invalid input handling, unauthorized/forbidden paths, and sensitive detail leakage
- Test boundary behavior explicitly when trust boundaries or role-based access are involved

## Output Format

Produce concrete production-ready tests. Use the testing framework already present in the project. Follow existing test structure and conventions. Prefer readable and maintainable test code.

## Done Criteria

- Tests compile and run
- High-value behaviors tested, not trivial cases
- Deterministic and non-timing-fragile
- Aligned with project testing conventions

## Anti-patterns

- Trivial "should create" tests or "component exists" tests
- Testing private implementation details without behavioral value
- Excessive mocks hiding real contract issues
- Fragile markup assertions when behavioral assertions suffice
- Over-testing framework internals instead of feature behavior
