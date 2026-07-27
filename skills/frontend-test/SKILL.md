---
name: frontend-test
description: Add framework-neutral frontend unit or component tests using the repository's installed runner and harness. Use when executable component-boundary coverage is requested and no sharper React, Vue, or Angular specialization dominates; route browser journeys and pixel contracts to E2E or visual regression.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.1
  argument-hint: "component/module, installed framework and runner, behavior and execution boundary"
---

# Frontend Test

Add tests to the repository; this is a `repository_write` workflow.

## Route and establish capability

1. Read instructions, manifests/lockfiles, runner/config/setup, render helpers, target implementation, nearby tests, and authoritative commands. Before mutation, resolve the exact task-owned test and fixture targets when repository evidence identifies them, the owning package/team and write authority, and a reversible diff/cleanup path; otherwise block execution pending that discovery.
2. Route React-, Vue-, or Angular-dominant behavior to the matching frontend-test specialization. Route cross-page/browser-runtime journeys to `e2e-test` and pixel/layout contracts to `visual-regression`.
3. Preserve the installed runner, DOM/browser environment, language, providers, and mocking utilities. Generate stack context and verify version-sensitive syntax against installed types/configuration plus matching pinned-version official documentation; do not silently migrate Jest/Vitest, framework, or harness.
4. Choose the smallest faithful boundary: pure unit, DOM component, framework SSR/hydration integration, browser E2E, or visual comparison. Do not claim hydration, layout, navigation, or real-browser coverage from a DOM emulator.

## Test contract

- Characterize initial/fresh-load, loading, empty, success, validation, error/retry, and post-interaction states relevant to the risk.
- Prefer semantic queries and caller-visible outcomes. Use lower-level events, stable test IDs, or snapshots only when they truthfully express the contract.
- Await the intended transition; control clocks, randomness, external stores, and requests at owned boundaries without arbitrary sleeps.
- Tests must never call real external networks. Reuse the installed interceptor, injected client, framework stub, or isolated local server and reset mutable state.
- For consequential mutations, prove rendered plus local/server-observable outcomes under duplicate activation, authorization failure, conflict, and timeout ambiguity when applicable. A disabled button or mock call count is not idempotency proof.

## Verification and output

Run the repository's focused command, then affected test/type/lint/build checks appropriate to the change. Treat unhandled requests/promises, console or hydration errors, leaked timers, and framework warnings as failures unless explicitly documented.

Report tests changed, installed harness and chosen boundary, behavior covered, commands and observed results, and remaining browser/server/visual/provider risk.
