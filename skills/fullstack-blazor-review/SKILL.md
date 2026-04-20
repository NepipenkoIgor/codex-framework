---
name: fullstack-blazor-review
description: Review Blazor applications for architecture, render mode correctness, component lifecycle, EF Core usage, SignalR handling, MudBlazor patterns, and security
metadata:
  version: 1.4
  argument-hint: "PR URL or file paths, review focus (security/performance/state management)"
---

Review $ARGUMENTS.


## Tool Integration

- **Compiler diagnostics** — verify type errors and diagnostics
- **ast-grep** — use for structural code pattern search (find method signatures, class usages, import patterns) — faster and more accurate than Grep for code structure

Frameworks in scope:
- Blazor Server, Blazor WebAssembly, Blazor United (.NET 8+ auto/SSR)
- ASP.NET Core backend
- Entity Framework Core
- MudBlazor component library
- Dapper (where used alongside EF Core)

Severity: CRITICAL (security/data/outage) > HIGH (perf/reliability) > MEDIUM (maintainability) > LOW (style).

## Review Focus Areas

### Render Mode Correctness (.NET 8+)

- `@rendermode` attribute matches component requirements (InteractiveServer, InteractiveWebAssembly, InteractiveAuto)
- Components that need interactivity aren't accidentally SSR-only
- Components with server dependencies (EF Core, file system) aren't set to WebAssembly
- Prerendering considerations: `@rendermode="new InteractiveServerRenderMode(prerender: false)"` used where appropriate
- No `@rendermode` on layouts (inherited from parent)
- Streaming rendering: `[StreamRendering]` used for async data loading pages

### Component Lifecycle

- `OnInitializedAsync` vs `OnParametersSetAsync` — correct hook for the operation
- `StateHasChanged()` abuse — should not be called inside lifecycle methods (already triggers re-render)
- `StateHasChanged()` from non-UI thread → must use `InvokeAsync(() => StateHasChanged())`
- `Dispose` pattern: components implementing `IDisposable`/`IAsyncDisposable` for event handlers, timers, SignalR subscriptions
- `SetParametersAsync` override — rarely needed, flag if used without clear justification
- `ShouldRender()` — verify not suppressing needed renders or missing performance optimization opportunity
- First render guard: `OnAfterRender(bool firstRender)` — JS interop only after first render

### EF Core Usage in Components

CRITICAL patterns:
- DbContext lifetime: must be scoped via `IDbContextFactory<T>`, never injected directly in Server mode (concurrent access = crashes)
- `using var context = await DbContextFactory.CreateDbContextAsync()` — correct pattern
- Missing `await` on async EF operations (silent failures)
- N+1 queries: `.Include()` missing in loops, or lazy loading enabled without awareness
- Tracking queries used for read-only display → should be `.AsNoTracking()`
- Raw SQL without parameterization → SQL injection
- `SaveChangesAsync()` called outside transaction when multiple operations need atomicity
- Connection pool exhaustion: DbContext not disposed

### SignalR / Circuit

- Circuit disconnect handling: `CircuitHandler` registered for cleanup
- Large payload over SignalR: binary data, large lists → consider chunking or API endpoint
- `NavigationManager.NavigateTo()` in `OnInitialized` → use `OnAfterRender` or check if prerendering
- Hub method calls: error handling for `HubConnectionClosedException`
- Reconnection: `HubConnection.Closed` event handler with retry logic
- Max message size: default 32KB — flag if large objects serialized

### MudBlazor Patterns

- `MudForm` vs `EditForm` — don't mix in same component
- `MudTable` with `ServerData` — verify pagination, sorting parameters sent correctly
- `MudDialog`: `DialogService.ShowAsync<T>` with proper parameter passing, result handling
- `MudAutocomplete`: debounce on `SearchFunc`, cancellation token for stale requests
- Theme consistency: colors from `MudTheme`, not hardcoded
- `MudBlazor.Services` registered in DI: `builder.Services.AddMudServices()`
- Snackbar/dialog injection: `[Inject] ISnackbar Snackbar` pattern

### State Management

- Cascading parameters for auth state (`[CascadingParameter] Task<AuthenticationState>`)
- Cascading values overused (>3 levels deep, large objects cascaded)
- State container pattern: scoped service with `OnChange` event, proper disposal
- Local storage / session storage: used for appropriate data only (no sensitive data in WASM)
- `ProtectedLocalStorage` / `ProtectedSessionStorage` for server-side encrypted storage

### Security

- `[Authorize]` attribute on pages and API endpoints
- Policy-based authorization: `@attribute [Authorize(Policy = "Admin")]`
- WASM: all authorization is UI-only — server must re-validate
- Anti-forgery tokens on forms: `<AntiforgeryToken />`
- CORS configuration for WASM → API communication
- JS interop: no user-controlled strings passed to `eval` or `innerHTML`
- File upload validation: size limits, content type verification, not just extension

### Performance

- Virtualization: `<Virtualize>` for large lists instead of `@foreach`
- Event handlers: lambda allocations in loops → extract to method with index
- JS interop: batched calls preferred over many small interop calls
- Image/asset loading in WASM: lazy loading, appropriate formats
- Component granularity: large pages should split into child components to limit re-render scope
- `@key` directive on repeated elements for efficient diffing

### API Integration

- HttpClient registration: named/typed clients via DI, not `new HttpClient()`
- WASM → API: auth token attached via `AuthorizationMessageHandler`
- Error handling: HTTP errors mapped to user-friendly messages
- Loading states: `bool isLoading` pattern with try/finally
- Cancellation: `CancellationToken` passed through to API calls

## Output Format

Per finding: File:Line | Severity | Category | Issue | Fix suggestion.

Summary: verdict (approve/request changes), top findings by severity, positive callouts.

## Constraints

- Never modify code — strictly read-only
- Never dismiss findings — report everything, severity guides priority
- Always check render mode correctness in .NET 8+ projects
- Always verify DbContext lifetime pattern
- Flag any direct DbContext injection (not factory) in Blazor Server as CRITICAL
