---
name: fullstack-blazor-debug
description: Diagnose and fix bugs in Blazor applications using .NET, ASP.NET Core, Razor components, MudBlazor, EF Core, Dapper, and JS interop
metadata:
  version: 1.9
  argument-hint: "bug description, component/page affected, error message, .NET version"
---

Debug $ARGUMENTS.


## Tool Integration

- **Compiler diagnostics** — use for compiler diagnostics, go-to-definition to trace call chains, and find-references to identify all callers of buggy code
- **ast-grep** — use for structural code pattern search (find method signatures, class usages, import patterns) — faster and more accurate than Grep for code structure
- **browser automation** — capture screenshots for visual verification and regression testing

Stack: Blazor (Server/WASM), .NET 8+, MudBlazor, EF Core/Dapper, bUnit.

Core debugging principles:

- Diagnose root cause before proposing broad refactors; distinguish symptoms from actual causes
- Prefer minimal safe fixes over large rewrites; prefer targeted debugging over speculative architecture changes
- Verify rendering, state ownership, validation, orchestration, backend interaction, and persistence before changing code
- Avoid hiding bugs behind repeated StateHasChanged, arbitrary delays, broad catch blocks, or defensive workarounds
- Use the smallest fix that addresses the actual cause instead of masking the symptom

Debugging priorities:

- non-interactive UI, broken click/submit behavior
- stale state, duplicated state, rendering loops, repeated rerenders
- failed data loading, race conditions, duplicate side effects
- MudBlazor table/dialog bugs, validation mismatches, contract mismatches
- serialization bugs, JS interop lifecycle bugs, incorrect conditional rendering
- pagination/filtering/sorting bugs, background update issues
- Blazor Server connection problems, authorization/boundary bugs
- query/persistence issues visible through UI, memory pressure and resource leaks

Bug diagnosis approach:

- Identify the reported symptom; reconstruct expected behavior
- Trace the full flow: rendering, parameters, state, callbacks, validation, services, contracts, persistence, JS interop
- Inspect state ownership, lifecycle timing, async flows, and rerender triggers first
- Check for contract/schema/serialization/type mismatches and persistence leakage
- Explain root cause clearly before proposing structural changes

Dependencies and imports:

- Prefer existing dependencies; avoid new libraries unless the fix requires them
- Remove debug-only imports and temporary code when the fix is complete

Component and page architecture:

- Check responsibility boundaries, component coupling, and whether brittle composition causes invalid data flow
- Check if overly heavy Razor markup is hiding the actual issue

State and flow management:

- Check state ownership, duplicated state, hidden mutable shared state first
- Verify selection, form, dialog, loading, and table query state independently when relevant

Async and data loading:

- Check for duplicate requests, stale results, race conditions, and fragile retry flows
- Check loading/error/cancellation transitions and whether CancellationToken is missing

Rendering and performance:

- Check for unnecessary rerenders, expensive rendering work, unstable render inputs
- Prefer fixing root rendering triggers before adding workarounds

Example -- fixing a rendering loop caused by calling StateHasChanged inside OnParametersSetAsync:

```csharp
// BAD: causes infinite rerender loop
protected override async Task OnParametersSetAsync()
{
    _items = await ItemService.GetItemsAsync(CategoryId);
    StateHasChanged(); // Triggers OnParametersSetAsync again
}

// GOOD: let the framework handle rendering after lifecycle completes
protected override async Task OnParametersSetAsync()
{
    // Only reload when the parameter actually changed
    if (CategoryId != _previousCategoryId)
    {
        _previousCategoryId = CategoryId;
        _items = await ItemService.GetItemsAsync(CategoryId);
        // No StateHasChanged needed -- Blazor rerenders after OnParametersSetAsync
    }
}
```

Forms and interactions:

- Check form state ownership, validation timing, and submit/error state handling
- Check whether form reset/cancel/save flows leave stale state behind

Reusability and maintainability:

- Apply the smallest maintainable fix; remove harmful abstractions hiding the root cause
- Extract reusable code only when duplication directly contributes to the bug

Anti-patterns to avoid:

- No speculative fixes without root cause; no masking bugs with StateHasChanged/Task.Delay/forced reloads
- No large rewrites when targeted debugging suffices; no clever abstractions reducing readability
- No behavior changes disguised as "just a bugfix"

Testing awareness:

- Keep fixes easy to test; add tests for the bug scenario when appropriate
- Prefer reproducing subtle bugs in focused tests when regression-prone

Accessibility and UX baseline:

- Preserve semantic HTML, keyboard interaction, and accessibility behavior
- Avoid fixing one issue by silently breaking accessibility or UX

Observability:

- Follow existing logging/telemetry patterns; check whether poor observability hinders diagnosis
- Avoid leaking secrets into logs or UI error messages

Type modeling and contracts:

- Prefer strong typing; keep types in dedicated files; use typing to expose invalid assumptions
- Prefer explicit UI contracts; do not leak persistence models into rendering state

Validation:

- Check validation at boundaries; check for duplicate or contradictory validation logic
- Prefer fixing contract clarity before adding defensive patches

API and service integration:

- Check request/response contracts; check if UI compensates for badly shaped backend responses
- Prefer fixing contract shape before layering more client-side transformation

Database and persistence:

- Use the project's established approach; prefer fixing query correctness and boundaries
- Check projection, filtering, paging close to backend; avoid excessive in-memory data

EF Core:

- Check DbContext scoping, tracking behavior, projection, Includes, and entity leakage
- Check whether repository layers hide the actual persistence issue

Dapper:

- Verify parameterized query behavior, result mapping, joins, projections, and paging
- Move large inline SQL to dedicated query modules when readability is part of the issue

Inline SQL rules:

- Check large inline SQL when debugging correctness; never allow unsafe string concatenation

Error handling:

- Check failure paths, swallowed exceptions, and ambiguous results explicitly
- Prefer clearer failure semantics over defensive catch-all behavior

Background jobs and messaging:

- Check for duplicate side effects, retry storms, timeout issues, and partial failures
- Validate payloads at boundary; prefer idempotent handlers

External integrations:

- Check timeout, retry, serialization, mapping, and partial-failure bugs at integration boundaries
- Normalize provider data close to boundary; insulate UI from provider-specific shapes

Security:

- Validate external input at boundary; check authorization and access checks
- Never leak secrets or internal exception detail into UI

JavaScript interop:

- Use JS interop only when Blazor/MudBlazor/CSS cannot achieve the behavior
- Isolate behind dedicated services; keep calls explicit, minimal, and lifecycle-safe
- Handle failures with try-catch; dispose IJSObjectReference in component Dispose
- Check lifecycle timing, disposal, DOM availability, and interop call frequency before proposing JS-based fixes

.NET / ASP.NET Core:

- Prefer async end-to-end with CancellationToken; keep services focused
- Follow existing MediatR/CQRS/minimal API patterns; debug away from legacy patterns when safe

.NET non-negotiable rules:

- Async all the way; no sync-over-async; do not ignore CancellationToken
- Do not leak EF entities through UI contracts; do not put business logic in Razor components
- Check async deadlocks, cancellation misuse, transaction leakage, DbContext scope misuse before proposing broad fixes

Blazor:

- Separate markup, state, orchestration, and domain logic; keep Razor readable
- Prefer explicit parameters, EventCallback, and focused child components
- Check lifecycle order, OnInitializedAsync vs OnParametersSetAsync, disposal, and rerender triggers before restructuring

Blazor non-negotiable rules:

- No heavy business logic in Razor markup; no repeated StateHasChanged as state fix
- No overgrown pages combining tables, dialogs, forms, domain logic, and service calls
- Keep non-trivial types in dedicated files; use modern Blazor APIs

MudBlazor:

- Use MudBlazor idiomatically; keep table/dialog/form/action workflows clear and bounded
- Keep selection, paging, filtering, sorting state explicit and aligned with backend contracts
- Check MudBlazor workflow bugs through state, contracts, and orchestration before blaming the component library

Styling:

- Follow the project's established styling approach; use Tailwind as primary when available
- Debug visibility, interaction, focus, overflow, layout, and state-driven styling issues by checking class conditions and selector precedence before rewriting structure

Styling non-negotiable rules:

- Tailwind is primary when available; no custom CSS for what Tailwind handles well
- No inline styles for standard styling; move complex visual states into CSS
- Keep Razor markup readable; balance Tailwind utilities and semantic CSS

Remediation workflow:

1. Immediate mitigation -- revert, disable feature, or add guard
2. Root cause fix -- address the actual bug
3. Prevention -- add test or validation to prevent recurrence

Debugging workflow:

1. Detect the Blazor, .NET, and project conventions used in the codebase
2. Understand the reported symptom, expected behavior, and affected feature boundary
3. Identify likely root-cause categories before changing code
4. Trace rendering behavior, state ownership, parameters, EventCallback flows, validation, backend contracts, persistence, async flows, JS interop, and MudBlazor workflows
5. Confirm the most likely root cause and avoid speculative rewrites
6. Apply the smallest safe fix that addresses the actual cause
7. Ensure contracts, schemas, and models remain aligned and placed in appropriate dedicated files when non-trivial
8. Summarize the root cause, the fix, remaining risks, and any optional follow-up improvements

Output requirements:

- Start with a short diagnosis of the symptom and likely root cause
- Explain the root cause clearly before proposing large structural changes
- Propose a concise debug plan when the issue is non-trivial
- Produce concrete production-ready code, not only advice
- Follow the idioms of the detected framework and runtime
- Align with the project's testing approach when tests exist
- Preserve intended behavior unless the user explicitly asks for functional, product, or UX changes
- Prefer minimal safe fixes over broad refactors

UI fix rules: when fixing UI bugs in Blazor/Razor/MudBlazor — use existing MudTheme palette and CSS variables. Never introduce new hardcoded hex colors or arbitrary px values. If the bug is caused by inconsistent tokens, fix the token source, not the individual component.

## Structured Output Contract
- **Status**: `done` | `partial` | `blocked`
- **Changed**: `[file.ext: +lines/-lines, ...]` — list every modified file
- **Notes**: blockers or non-obvious decisions only — omit if none

Do NOT return prose summaries or recaps.
