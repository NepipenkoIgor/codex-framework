---
name: blazor-development
description: Implement, debug, refactor, review, or test full-stack Blazor applications across Razor components, render modes, ASP.NET Core, persistence, JavaScript interop, and bUnit/Playwright coverage. Use when the task is Blazor-specific; do not use for general .NET APIs without Razor or Blazor runtime behavior.
metadata:
  version: 2.0
  argument-hint: "mode (implement/debug/refactor/review/test), component or service, target framework, render mode"
  owner: fullstack-dotnet
  reviewed: "2026-07-26"
---

# Blazor Development

Select the task mode from the request. Share discovery and invariants, then execute only the relevant mode instead of loading five overlapping skills.

## Discovery

1. Read the project target framework, hosting model, render modes, router, layouts, component library, persistence, auth, tests, and deployment configuration.
2. Before material mutation, resolve the exact repository, deployment and data targets, their owners/permissions, and the recovery or rollback path.
3. Trace the affected component through parameters, cascading state, services, HTTP/database boundaries, JS modules, and rendered output.
4. Verify framework-version and component-library APIs in official documentation.
5. Preserve the repository's existing architecture unless the request or evidence requires migration.
6. For greenfield work with no manifest or lockfile, resolve the current supported .NET LTS and compatible Blazor/tooling releases from configured official sources at execution time, verify the stack together, then treat the generated project manifest, `global.json` when used, and dependency lockfile as authority.

## Shared Invariants

- Choose render mode intentionally and keep client/server-only dependencies on the correct side.
- Treat parameters as external input; avoid mutating them as component-owned state.
- Make async lifecycle work cancellation-aware and avoid duplicate initialization across prerender/interactive transitions.
- Treat circuit reconnect and replay as expected distributed-system behavior: persist consequential commands behind server-side authorization and idempotency rather than relying on component memory. Derive reconnect/retry attempt and elapsed-time bounds from the installed circuit/provider behavior and product deadlines; after exhaustion expose a recoverable pending/error state instead of retrying indefinitely.
- Dispose event subscriptions, timers, streams, `DotNetObjectReference`, and JS modules owned by the component.
- Use `InvokeAsync` when external callbacks update component state.
- Keep EF Core contexts scoped appropriately, bound queries, and use transactions for multi-step integrity changes. A context is not safe for parallel operations; use the repository's factory/unit-of-work boundary rather than sharing one context across concurrent component work.
- Enforce authorization at server/data boundaries; UI visibility is not authorization.
- Preserve semantic HTML, labels, focus behavior, keyboard support, error states, and reduced motion.

## Implement Mode

1. Define the route/component/service contract and loading, empty, error, and authorization states.
2. Implement the smallest vertical slice using existing components and DI boundaries.
3. Add persistence and JS interop only behind typed, disposable boundaries.
4. Add focused component/service/integration tests and verify the affected render mode.

## Debug Mode

1. Reproduce and capture browser console/network, server logs, circuit state, render mode, and exact lifecycle sequence.
2. Reduce the failure to routing/rendering, binding/state, DI, persistence, SignalR circuit, auth, or JS interop.
3. Prove the root cause before editing; fix the smallest responsible boundary.
4. Add a regression check that fails before and passes after the change.

## Refactor Mode

1. Establish characterization tests or equivalent behavior evidence.
2. Separate rendering, state transitions, application logic, persistence, and interop without changing the public contract.
3. Refactor in reviewable increments and rerun affected tests after each boundary move.
4. Report deliberate compatibility or behavior changes separately.

## Review Mode

Prioritize correctness and regressions over style. Check render-mode boundaries, lifecycle races, disposal, authorization, query/materialization cost, JS interop ownership, accessibility, error behavior, and missing executable tests. Every finding needs severity, concrete evidence, and a tight file/line or reproduction reference.

## Test Mode

- Use unit tests for pure rules and state transitions.
- Use bUnit for component rendering, parameters, events, DI, authorization views, and accessible output.
- Use integration tests for ASP.NET Core, persistence, auth, and serialization boundaries.
- Use Playwright only for behavior requiring a real browser, render-mode transition, navigation, focus, or JS interop.
- Avoid EF Core InMemory when relational behavior matters; use the repository's supported relational test path.

## Verification

Run the repository's formatter, build, analyzers, affected unit/bUnit/integration tests, and browser checks required by the mode. Exercise the actual hosting/render mode and report any browser, database, auth, or deployment path not verified.

## Output Contract

- Mode and affected render/hosting boundary
- Root cause or design decision
- Files and contracts changed or reviewed
- Exact checks and observed results
- Unverified paths and residual risk
