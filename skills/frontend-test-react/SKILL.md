---
name: frontend-test-react
description: Test React components, hooks, routes, server boundaries, and hydration behavior with the repository's installed runner and harness. Use when executable React-specific test coverage is requested; do not use for Vue, Angular, generic browser E2E, or feature implementation without a testing deliverable.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.2
  domain: frontend
  keywords: [react, testing, rtl, react testing library, vitest, jest, userEvent, fireEvent, hydration, server components]
---

# Frontend Test - React

Write the smallest executable tests that prove caller-visible React behavior while preserving the repository's installed runner, environment, utilities, and conventions.

## Establish the boundary

1. Read applicable instructions, manifests and lockfiles, runner config, setup files, nearby tests, and the target implementation. Before mutation, resolve exact task-owned test/fixture targets when repository evidence identifies them, package ownership and write authority, plus a reversible diff and isolated cleanup path; otherwise block execution pending discovery.
2. Generate project stack context and resolve the installed React/framework, runtime engine, peer-dependency ranges, compiler/build tooling, runner, DOM environment, Testing Library, router, request-mocking capabilities, browser targets, and deployment runtime as one mutual-compatibility chain. Verify version-sensitive choices from installed metadata/types and matching official support evidence. Do not silently add or migrate a harness.
3. Classify each behavior before choosing a test:
   - pure state or hook logic: unit test when isolation is faithful;
   - client component behavior: component test with the production providers needed by the path;
   - Server Component, Server Action, route, SSR, or hydration contract: use the repository's framework-aware integration harness;
   - browser-only layout, focus, navigation, streaming, or hydration behavior that the DOM emulator cannot reproduce: use browser/E2E coverage.
4. Characterize success, loading, empty, error, retry, authorization, and duplicate-action outcomes that are relevant to the change.

## Interaction and queries

- Prefer accessible-name and semantic queries because they reflect the user contract. Use test IDs only when no stable user-facing selector exists.
- Prefer `userEvent` for realistic multi-event user interactions. `fireEvent` is valid for a low-level event or browser condition that `userEvent` does not model; do not ban it mechanically.
- Await asynchronous interaction and UI settlement. Use `findBy*` for appearance and `waitFor` only around an assertion that genuinely retries.
- Bound every automated wait, controlled retry, and timeout-after-commit reconciliation exercise by attempts or elapsed time derived from the inspected operation contract and repository test-runner limits; idempotency does not make an unbounded test or production retry safe.
- Use manual `act` only for updates outside the harness's automatic wrapping, such as direct timer or external-store advancement.
- Do not assert private state, hook implementation, framework internals, or incidental class names unless those are the public contract.

## Boundary control

- Tests must not call real external networks. Reuse the installed request interception, dependency adapter, framework stub, or local test server at the narrowest truthful boundary.
- MSW is one valid interception mechanism, not a universal requirement. A direct dependency stub can be more accurate for an injected client; a route integration test may exercise a local handler.
- Preserve production provider composition where it affects behavior. Reset mutable handlers, timers, globals, modules, and stores according to the installed harness.
- Do not force a Server Component into a client DOM harness or claim hydration coverage from static markup. Prove serialization, server/client ownership, and fresh hydration at the boundary where they execute.

## Verification

- Run the repository-authoritative focused test command, then the affected suite or required type/lint checks.
- A passing mock assertion is insufficient for a mutation: verify the rendered result or persisted/local-handler outcome, including error and duplicate activation where material.
- Treat console errors, hydration warnings, unhandled requests, leaked timers, and `act` warnings as failures unless the repository explicitly documents an exception.

## Output

- Tests changed and behavior covered
- Installed runner/harness and selected boundary
- Commands run and observed results
- Browser/server/hydration paths not exercised and residual risk
