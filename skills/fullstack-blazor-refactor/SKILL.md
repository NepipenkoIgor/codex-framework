---
name: fullstack-blazor-refactor
description: Refactor existing full-stack Blazor applications using .NET, ASP.NET Core, Razor components, MudBlazor, EF Core, Dapper, and JS interop
metadata:
  version: 1.8
  argument-hint: "target component/service, refactor goal, .NET/Blazor version"
---

Refactor $ARGUMENTS.


## Tool Integration

- **Compiler diagnostics** — use for compiler diagnostics, go-to-definition, and find-references during refactoring. Verify no build errors remain before committing
- **ast-grep** — use for structural code pattern search (find method signatures, class usages, import patterns) — faster and more accurate than Grep for code structure
- **browser automation** — capture screenshots for visual verification and regression testing

Stack: Blazor (Server/WASM), .NET 8+, MudBlazor, EF Core/Dapper, bUnit.

Core refactoring principles:

- Preserve existing business behavior unless the user explicitly requests changes
- Prefer safe, incremental refactoring over large rewrites
- Follow existing project conventions unless they are clearly harmful
- Reduce duplication, complexity, hidden coupling, and accidental side effects
- Improve readability, maintainability, extensibility, and rendering efficiency
- Keep runtime validation and compile-time typing aligned; prefer explicit contracts
- Eliminate unnecessary rendering work, repeated computations, and wasteful orchestration
- Prefer small composable units; avoid over-engineering

Refactoring priorities:

- duplicated UI logic, oversized pages/components, weak typing, noisy contracts
- repeated backend/database calls, fragile async flows, hidden side effects
- poor type separation, validation duplication, bad query shaping through UI
- legacy Blazor patterns, overgrown MudBlazor tables/dialogs/forms
- unnecessary StateHasChanged calls, poor JS interop boundaries, styling duplication

Dependencies and imports:

- Prefer existing dependencies; avoid new libraries unless clearly required
- Remove unused imports and dead dependencies

Component and page architecture:

- Reduce responsibility when pages/components do too much; extract focused child components
- Keep Razor readable; prefer explicit parameters, callbacks, and models over implicit shared state
- Remove harmful indirection that adds no architectural value

Example -- extracting a reusable component from an overgrown page:

```razor
@* BEFORE: inline in the page with 400+ lines of markup *@
<MudCard Class="pa-4">
    <MudText Typo="Typo.h6">@order.CustomerName</MudText>
    <MudText Typo="Typo.body2">@order.Status — @order.Total.ToString("C")</MudText>
    <MudButton OnClick="() => ViewOrder(order.Id)">View</MudButton>
</MudCard>

@* AFTER: extracted to OrderSummaryCard.razor *@
@* OrderSummaryCard.razor *@
<MudCard Class="pa-4">
    <MudText Typo="Typo.h6">@Order.CustomerName</MudText>
    <MudText Typo="Typo.body2">@Order.Status — @Order.Total.ToString("C")</MudText>
    <MudButton OnClick="() => OnView.InvokeAsync(Order.Id)">View</MudButton>
</MudCard>

@code {
    [Parameter, EditorRequired] public OrderSummaryDto Order { get; set; } = default!;
    [Parameter] public EventCallback<Guid> OnView { get; set; }
}

@* Usage in the parent page — clean, scannable *@
@foreach (var order in _orders)
{
    <OrderSummaryCard Order="order" OnView="ViewOrder" />
}
```

State and flow management:

- Keep state ownership explicit and localized; eliminate duplicated/derived state
- Prefer computed values over synchronized copies; prefer deterministic transitions
- Simplify orchestration when state propagation causes fragility

Async and data loading:

- Eliminate duplicate requests; parallelize independent operations; prevent race conditions
- Handle loading, error, retry, empty, and success states explicitly
- Use CancellationToken; separate DTOs, domain models, and UI models

Rendering and performance:

- Eliminate unnecessary re-renders and expensive rendering work
- Prefer architecture/state fixes before rendering workarounds
- Use pagination, virtualization, lazy loading, and bounded lists where appropriate

Forms and interactions:

- Refactor toward clearer state ownership and validation structure
- Prevent duplicate submissions; prefer explicit edit/save/cancel/reset flows
- Remove ad-hoc validation when contract-driven validation is clearer

Reusability and maintainability:

- Extract reusable code only when duplication justifies it; remove premature abstractions
- Prefer simple readable code; keep business rules explicit

Anti-patterns to avoid:

- No god-pages/god-components; no mixing rendering, validation, orchestration, persistence, and business rules
- No excessive manual StateHasChanged as substitute for proper state design
- No sync-over-async; no preserving bad patterns when safe improvement is possible
- No behavior changes disguised as "just refactoring"

Testing awareness:

- Keep refactored code easy to test; prefer explicit seams for mocking
- Update tests when the refactor changes structure or contracts

Accessibility and UX baseline:

- Preserve semantic HTML, keyboard interaction, and accessibility behavior
- Avoid breaking accessibility or UX while refactoring structure

Observability:

- Follow existing logging/telemetry patterns; refactor toward clearer operational behavior when poor observability causes fragility

Type modeling and contracts:

- Prefer strong typing; keep types in dedicated files; use typing to expose invalid assumptions
- Prefer explicit UI contracts; do not leak persistence models into rendering state

Validation:

- Refactor toward explicit boundary validation; keep contracts stable
- Refactor duplicated or contradictory validation logic; avoid persistence leakage into UI

API and service integration:

- Prefer explicit request/response contracts; keep service calls bounded and predictable
- Prefer backend endpoints shaped for UI use cases; refactor leaky contracts toward clearer boundaries
- Preserve backward compatibility where possible

Pagination:

- All list/table endpoints must support pagination when datasets can grow
- Keep pagination contracts aligned between UI state and backend APIs

API versioning:

- Prefer explicit versioning for public APIs; prefer additive changes over breaking changes

API documentation and OpenAPI:

- Document all HTTP APIs with OpenAPI/Swagger; keep docs aligned with runtime validation
- Refactor outdated documentation when implementation changes contracts

Database and persistence:

- Use the project's established approach; keep persistence separate from UI
- Prefer projection over full entity graphs; keep filtering/sorting/paging close to the database
- Refactor persistence boundaries when they are the source of complexity

EF Core:

- Prefer EF Core for CRUD and transactional workflows; use DbContext directly when simpler
- No unnecessary repository wrappers; prefer AsNoTracking for reads; do not leak entities into UI
- Refactor entity-heavy UI flows toward explicit projections

Dapper:

- Use for query-heavy reads, reporting, and performance-sensitive paths
- Always parameterize; keep non-trivial SQL in dedicated query modules
- Refactor SQL-heavy paths toward clearer ownership

Inline SQL rules:

- No large inline SQL in pages/controllers/services; never concatenate user input into SQL

Error handling:

- Handle failures explicitly; no swallowed exceptions or ambiguous states
- Refactor toward clearer and more consistent failure semantics

Background jobs and messaging:

- Keep jobs focused; validate payloads at boundary; prefer idempotent handlers
- Refactor side-effect-heavy job logic toward clearer orchestration when safe

External integrations:

- Keep integration services focused; validate external payloads at boundary
- Refactor toward clearer boundaries and more predictable failure handling

Security:

- Validate all external input at boundary; prefer explicit authorization checks
- Refactor insecure or ambiguous boundary behavior toward explicit checks

JavaScript interop:

- Use JS interop only when Blazor/MudBlazor/CSS cannot achieve the behavior
- Isolate behind dedicated services; keep calls explicit, minimal, and lifecycle-safe
- Handle failures with try-catch; dispose IJSObjectReference in component Dispose
- Refactor scattered or lifecycle-unsafe JS interop toward clearer ownership

.NET / ASP.NET Core:

- Prefer async end-to-end with CancellationToken; keep services focused
- Follow existing MediatR/CQRS/minimal API patterns; refactor away from legacy patterns when safe

.NET non-negotiable rules:

- Async all the way; no sync-over-async; do not ignore CancellationToken
- Do not leak EF entities through UI contracts; do not put business logic in Razor components
- Prefer explicit boundary validation; use modern .NET APIs

Blazor:

- Separate markup, state, orchestration, and domain logic; keep Razor readable
- Prefer explicit parameters, EventCallback, and focused child components
- Prefer async lifecycle methods; avoid uncontrolled StateHasChanged
- Refactor away from legacy or overgrown patterns when safe

Blazor non-negotiable rules:

- No heavy business logic in Razor markup; no repeated StateHasChanged as state fix
- No overgrown pages combining tables, dialogs, forms, domain logic, and service calls
- Keep non-trivial types in dedicated files; use modern Blazor APIs

MudBlazor:

- Use MudBlazor idiomatically; keep table/dialog/form/action workflows clear and bounded
- Keep selection, paging, filtering, sorting state explicit and aligned with backend contracts
- Prefer server-side data loading for large datasets; avoid excessive in-memory data
- Prefer explicit dialog models and action callbacks over hidden shared state
- Refactor MudBlazor-heavy pages toward clearer ownership when markup complexity is the problem

Styling:

- Follow the project's established styling approach; use Tailwind as primary when available
- Use utilities for layout/spacing/typography; extract semantic classes when markup gets noisy
- Prefer CSS for complex selectors, layered states, pseudo-elements, and animations
- Refactor repeated utility chains toward clearer reusable patterns

Styling non-negotiable rules:

- Tailwind is primary when available; no custom CSS for what Tailwind handles well
- No inline styles for standard styling; move complex visual states into CSS
- Keep Razor markup readable; balance Tailwind utilities and semantic CSS

Refactoring workflow:

1. Detect the Blazor, .NET, and project conventions used in the codebase
2. Understand the feature boundary, surrounding architecture, and current behavior
3. Identify the highest-value safe refactors before making changes
4. Prefer targeted improvements over broad rewrites
5. Reuse existing utilities, services, contracts, schemas, types, and patterns
6. Ensure async flows, validation, rendering behavior, backend interactions, and persistence boundaries become simpler, safer, and more efficient
7. Ensure contracts, schemas, and models are placed in appropriate dedicated files when non-trivial
8. Summarize what was changed, what risks remain, and what further improvements are optional

## Output Format

Start with a short diagnosis. Propose a concise refactoring plan before large structural changes. Produce concrete production-ready code. Follow detected framework idioms. Preserve intended behavior unless explicitly asked to change. Align with project testing approach when tests exist.

## Done Criteria

- All targeted refactors applied
- Build passes with no compiler errors
- Behavior preserved unless explicitly changed
- New code follows project conventions

## Anti-patterns

- God-pages/components mixing rendering, validation, orchestration, and persistence logic
- Excessive manual StateHasChanged calls as state management workaround
- Sync-over-async blocking patterns
- Leaked persistence entities into UI contracts
- Overgrown MudBlazor tables/dialogs without component extraction
