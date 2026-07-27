---
name: frontend-test-vue
description: Test Vue or Nuxt components, composables, stores, routes, SSR, and hydration with the repository's installed runner and harness. Use when Vue-specific rendering or reactivity dominates; do not use for React, Angular, generic browser E2E, or implementation without a testing deliverable.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.1
  domain: frontend
  keywords: [vue, nuxt, testing, vue test utils, vitest, jest, pinia, mount, composable, hydration]
---

# Frontend Test - Vue

Write behavior-focused Vue tests without replacing the repository's runner, DOM environment, Vue Test Utils/Nuxt harness, store setup, or component style.

## Workflow

1. Inspect instructions, manifests and lockfiles, test config/setup, nearby tests, target component/composable/route, and installed Vue/Nuxt capabilities. Verify every selected version-sensitive API or command against installed/generated types, CLI/configuration schema, or matching official documentation. Before mutation, resolve exact task-owned test/fixture targets when repository evidence identifies them, package ownership and write authority, plus a reversible diff and isolated cleanup path; otherwise block execution pending discovery.
2. Choose the execution boundary:
   - pure transform: unit test;
   - component/reactivity contract: Vue Test Utils component test with required plugins and provides;
   - Nuxt route, plugin, server endpoint, SSR, or hydration: the installed Nuxt integration harness;
   - browser-only focus, layout, navigation, streaming, or hydration: browser/E2E test.
3. Cover the relevant rendered states and failure transitions, not internal refs or implementation-specific watcher calls.
4. Run the repository's focused command and affected checks.

## Components and interaction

- Preserve Options API, Composition API, `<script setup>`, and repository mounting conventions; testing is not an incidental migration.
- Use `mount` or the repository render helper when child integration matters. Shallow mounting is acceptable only when the child contract is explicitly outside scope and the stub does not erase the behavior under test.
- Change props with `setProps`, inputs with `setValue`, and events with awaited `trigger` or the installed user-event helper. Direct instance mutation is not a user interaction.
- Prefer semantic/accessibility queries where the installed harness supports them. Component lookup or stable test IDs are acceptable for contracts without a user-facing selector.
- Await Vue updates and unresolved promises deliberately; do not add arbitrary sleeps.

## Stores, composables, and I/O

- Use a real Pinia instance when store integration or action behavior is part of the contract. Use `createTestingPinia` when isolating the component from actions is the intended boundary. Neither is universal.
- Make action stubbing explicit; `stubActions: false` is not proof of persistence or network behavior.
- Test lifecycle-dependent composables inside a component/app setup. Pure context-free logic may be invoked directly when that is its real contract.
- Tests must not call real external networks. Reuse the installed interceptor, injected client stub, Nuxt mock, or local test server at the truthful boundary; reset mutable state between cases.
- Do not claim SSR or hydration coverage from a DOM-only mount. Verify server rendering, payload/state transfer, and fresh hydration with the matching harness or browser.

## Verification and output

- Verify rendered or persisted outcomes for mutations, including error, retry, stale response, and duplicate activation when material.
- Treat Vue warnings, hydration mismatches, unhandled requests, leaked timers, and unhandled promises as failures unless documented.
- Report tests changed, installed harness and boundary, behavior covered, commands/results, and untested SSR/browser/provider risk.
