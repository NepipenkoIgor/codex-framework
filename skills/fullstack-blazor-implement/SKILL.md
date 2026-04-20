---
name: fullstack-blazor-implement
description: Implement full-stack features in Blazor — components, APIs, forms, auth, EF Core persistence, and MudBlazor UI
metadata:
  version: 1.9
  argument-hint: "feature name, Blazor hosting model (Server/WASM/Auto), component scope"
---

Implement $ARGUMENTS.


## Tool Integration

- **Compiler diagnostics**: run available diagnostics tools after every code change for compiler diagnostics
- docs lookup tools: fetch current Blazor/ASP.NET docs before implementing

Stack: Blazor (Server/WASM), .NET 8+, MudBlazor, EF Core/Dapper, bUnit.

Core implementation principles:

- Follow existing project conventions, structure, naming, and architecture
- Write code that is easy to read, test, and extend; prefer small composable units
- Separate UI, state, validation, orchestration, persistence, and infrastructure concerns
- Build async flows carefully: loading, error, empty, success, cancellation, retry, and failure handling
- Keep runtime validation and compile-time typing aligned; prefer explicit contracts
- Avoid duplicated logic, unnecessary DB/HTTP calls, repeated rendering work, and over-engineering
- Prefer production-safe defaults over convenience shortcuts

Dependencies and imports:

- Prefer existing project dependencies; avoid new libraries unless clearly required
- Keep using statements clean and minimal; prefer explicit named dependencies

Component and page architecture:

- Create pages and components with clear responsibilities; split when justified
- Keep Razor markup readable; prefer explicit parameters, callbacks, and models over implicit shared state
- Prefer child components, focused partials, and view models when complexity grows

State and flow management:

- Keep state ownership explicit and localized; avoid duplicated or hidden mutable shared state
- Prefer computed/derived values over manually synchronized copies
- Keep loading, selection, form, and action state explicit; prefer deterministic transitions

Async and data loading:

- Handle loading, error, retry, empty, and success states explicitly
- Parallelize independent operations; prevent race conditions and duplicate side effects
- Use CancellationToken where appropriate; separate DTOs, domain models, and UI models

Rendering and performance:

- Avoid unnecessary re-renders and expensive work in rendering paths
- Prefer architecture/state fixes before rendering workarounds
- Use pagination, virtualization, lazy loading, and bounded lists where appropriate

Forms and interactions:

- Keep validation close to form logic; handle submit, loading, validation, error states explicitly
- Prevent duplicate submissions; ensure flows are recoverable after failures
- Prefer explicit edit, save, cancel, reset, confirm, and delete flows

Example -- Razor component with EditForm, DataAnnotations validation, and submit handling:

```razor
@page "/contacts/new"
@inject IContactService ContactService
@inject NavigationManager Nav

<EditForm Model="_form" OnValidSubmit="HandleSubmit">
    <DataAnnotationsValidator />
    <MudTextField @bind-Value="_form.Name" Label="Name" For="@(() => _form.Name)" />
    <MudTextField @bind-Value="_form.Email" Label="Email" For="@(() => _form.Email)" />
    <MudButton ButtonType="ButtonType.Submit" Disabled="_submitting" Color="Color.Primary">
        @(_submitting ? "Saving..." : "Save")
    </MudButton>
</EditForm>

@code {
    private ContactFormModel _form = new();
    private bool _submitting;

    private async Task HandleSubmit()
    {
        _submitting = true;
        try
        {
            await ContactService.CreateAsync(_form);
            Nav.NavigateTo("/contacts");
        }
        finally { _submitting = false; }
    }

    public class ContactFormModel
    {
        [Required, MaxLength(100)] public string Name { get; set; } = "";
        [Required, EmailAddress]   public string Email { get; set; } = "";
    }
}
```

Reusability and maintainability:

- Extract reusable code only when duplication justifies it; remove premature abstractions
- Prefer simple readable code over clever solutions; keep business rules explicit

Anti-patterns to avoid:

- No god-pages/god-components; no mixing rendering, validation, orchestration, persistence, and business rules
- No excessive manual StateHasChanged as substitute for proper state design
- No sync-over-async; no leaking persistence/transport concerns into UI without contract boundary

Testing awareness:

- Keep code easy to test; prefer explicit seams for mocking services and integrations
- Align with the project's testing approach when tests exist

Accessibility and UX baseline:

- Use semantic HTML; support keyboard interaction; provide clear loading/error/empty feedback
- Preserve focus behavior, dialog accessibility, and action clarity

Observability:

- Follow existing logging/telemetry patterns; avoid noisy logs and leaking secrets

Type modeling and contracts:

- Prefer strong typing; keep shared contracts, DTOs, form/table/page models in dedicated files
- Colocate feature-local types; use shared modules for cross-feature types
- Prefer explicit UI contracts; do not leak persistence models into rendering state

Validation:

- Validate at boundaries; prefer explicit parsing and normalization over implicit assumptions
- Keep contracts explicit and stable; avoid leaking persistence models into UI contracts

API and service integration:

- Prefer explicit request/response contracts; keep service calls bounded and predictable
- Prefer backend endpoints shaped for UI use cases; avoid excessive client-side transformation
- Ensure backward compatibility where possible

Pagination:

- All list/table endpoints must support pagination when datasets can grow
- Keep pagination contracts aligned between UI state and backend APIs

API versioning:

- Prefer explicit versioning for public APIs; use route-based (/api/v1/) or project convention
- Prefer additive changes over breaking changes

API documentation and OpenAPI:

- Document all HTTP APIs with OpenAPI/Swagger; keep docs aligned with runtime validation
- Use Swashbuckle or project's generator; include proper annotations and response status codes

Database and persistence:

- Use the project's established persistence approach; keep persistence separate from UI
- Prefer projection over full entity graphs; keep filtering/sorting/paging close to the database
- Avoid chatty flows; prefer explicit contracts between Blazor and backend services

EF Core:

- Prefer EF Core for CRUD and transactional workflows; use DbContext directly when simpler
- No unnecessary repository wrappers; prefer AsNoTracking for reads; do not leak entities into UI

Dapper:

- Use for query-heavy reads, reporting, and performance-sensitive paths
- Always parameterize; keep non-trivial SQL in dedicated query modules

Inline SQL rules:

- No large inline SQL in pages/controllers/services; never concatenate user input into SQL

Error handling:

- Handle failures explicitly; no swallowed exceptions or ambiguous states
- Consider retries, idempotency, and partial-failure handling where side effects exist

Background jobs and messaging:

- Keep jobs focused; validate payloads at boundary; prefer idempotent handlers
- Handle retries, deduplication, timeout, and cancellation explicitly

External integrations:

- Keep integration services focused; validate external payloads at boundary
- Normalize provider data at integration boundary; insulate UI from provider-specific shapes

Security:

- Validate all external input at boundary; prefer explicit authorization checks
- Never leak secrets into logs or UI; keep sensitive operations narrow and auditable

JavaScript interop:

- Use JS interop only when Blazor/MudBlazor/CSS cannot achieve the behavior
- Isolate behind dedicated services; keep calls explicit, minimal, and lifecycle-safe
- Handle failures with try-catch; dispose IJSObjectReference in component Dispose
- No hidden DOM manipulation fighting Blazor rendering; no JS interop for poor state design workarounds

.NET / ASP.NET Core:

- Prefer async end-to-end with CancellationToken; keep services focused
- Separate UI, application logic, and infrastructure; follow existing MediatR/CQRS/minimal API patterns

.NET non-negotiable rules:

- Async all the way; no sync-over-async; do not ignore CancellationToken
- Do not leak EF entities through UI contracts; do not put business logic in Razor components
- Prefer explicit boundary validation; use modern .NET APIs

Blazor:

- Separate markup, state, orchestration, and domain logic; keep Razor readable
- Prefer explicit parameters, EventCallback, and focused child components
- Prefer async lifecycle methods; avoid uncontrolled StateHasChanged

Blazor non-negotiable rules:

- No heavy business logic in Razor markup; no repeated StateHasChanged as state fix
- No overgrown pages combining tables, dialogs, forms, domain logic, and service calls
- Keep non-trivial types in dedicated files; use modern Blazor APIs

MudBlazor:

- Use MudBlazor idiomatically; keep table/dialog/form/action workflows clear and bounded
- Keep selection, paging, filtering, sorting state explicit and aligned with backend contracts
- Prefer server-side data loading for large datasets; avoid excessive in-memory data
- Prefer explicit dialog models and action callbacks over hidden shared state
- Avoid overgrown pages where MudBlazor markup, orchestration, and domain logic coexist

Styling:

- Follow the project's established styling approach; use Tailwind as primary when available
- Use utilities for layout/spacing/typography; extract semantic classes when markup gets noisy
- Prefer CSS for complex selectors, layered states, pseudo-elements, and animations
- No inline styles for standard cases; prefer CSS variables over hardcoded values

Styling non-negotiable rules:

- Tailwind is primary when available; no custom CSS for what Tailwind handles well
- No inline styles for standard styling; move complex visual states into CSS
- Keep Razor markup readable; balance Tailwind utilities and semantic CSS

Design token enforcement (mandatory):

- Before creating any UI component: check for existing tokens (CSS variables in `app.css`/`:root`, MudTheme palette, Tailwind config). If none exist, create them first.
- Never hardcode colors, spacing, font sizes, shadows, or border radius — always reference tokens
- MudBlazor: use `MudTheme` palette (`Primary`, `Secondary`, `Error`, `Surface`) — never raw hex in component parameters
- CSS isolation (`.razor.css`): use `var(--color-primary)` not hex values
- All interactive elements at same size must have identical height — match MudBlazor size system (`Size.Small`, `Size.Medium`, `Size.Large`)
- Every input, button, select must have consistent focus ring, hover, disabled states

Implementation workflow:

1. Detect the Blazor, .NET, and project conventions used in the codebase
2. Understand the feature boundary and surrounding architecture
3. Propose a short implementation plan before making structural changes
4. Implement using the smallest clean structure that fits the problem
5. Reuse existing utilities, services, contracts, schemas, types, and patterns
6. Ensure async flows, validation, rendering behavior, backend interactions, and persistence boundaries are correct and efficient
7. Ensure contracts, schemas, and models are placed in appropriate dedicated files when non-trivial
8. Provide a summary of the implementation and possible improvements

Output requirements:

- Provide a short explanation of the implementation approach
- Produce concrete production-ready code
- Follow the idioms of the detected framework and runtime
- Align with the project's testing approach when tests exist
- Keep type design, contract design, validation strategy, rendering behavior, styling approach, and file organization consistent with the skill rules

## Structured Output Contract
- **Status**: `done` | `partial` | `blocked`
- **Changed**: `[file.ext: +lines/-lines, ...]` — list every modified file
- **Notes**: blockers or non-obvious decisions only — omit if none

Do NOT return prose summaries or recaps.
