---
name: frontend-test-vue
description: Vue 3 + Nuxt 3 testing with Vue Test Utils, vitest, Pinia stubs
metadata:
  version: 1.0
  domain: frontend
  keywords: [vue, vuejs, nuxt, testing, vue test utils, vitest, pinia, mount, shallowMount, composable]
---

# Frontend Test — Vue

Pair with `frontend-test` for universal testing principles.

## Workflow

1. Read the component, composable, route, and nearby tests before writing new cases.
2. Choose the narrowest test that covers the behavior risk.
3. Mount with the same plugins, stores, router, and provide/inject setup that production uses.
4. Drive behavior through rendered output and user events.
5. Run the targeted Vitest command and report any remaining untested risk.

## Setup

- Use `@vue/test-utils` + `vitest` — never Jest for new Vue 3 projects (vitest is native to Vite)
- Use `jsdom` or `happy-dom` environment in `vitest.config.ts`
- Use `@pinia/testing` for Pinia store testing — never mock Pinia manually

## Mounting

- Use `mount()` for integration tests (full child rendering) — prefer over `shallowMount`
- Use `shallowMount()` only when child components are irrelevant to the test and would cause test noise
- Pass props via `mount(Component, { props: { ... } })` — never mutate `wrapper.vm` props directly
- Use `global.plugins` to install Pinia, Router, and other plugins: `mount(C, { global: { plugins: [createPinia()] } })`

## Querying and Assertions

- Query by role or text via `wrapper.find('[role="button"]')` or `wrapper.findComponent(MyComponent)`
- Use `wrapper.get()` when element must exist (throws if missing) — `wrapper.find()` when checking absence
- Assert rendered text with `wrapper.text()`, attributes with `wrapper.attributes()`, classes with `wrapper.classes()`
- Never assert on internal component data directly — test through rendered output

## User Interactions

- Use `await wrapper.trigger('click')` / `await wrapper.trigger('input')` for DOM events
- Use `await wrapper.setValue(value)` for input/select changes — never set `.value` directly
- Always `await` triggers — Vue Test Utils updates DOM asynchronously after events

## Pinia Testing

- Use `createTestingPinia({ initialState: { store: { ... } } })` from `@pinia/testing`
- Access store after mounting: `const store = useMyStore()` — `createTestingPinia` auto-stubs actions
- To test real action logic: `createTestingPinia({ stubActions: false })`
- Never instantiate stores outside of a Pinia context — always inside test with testing pinia active

## Composable Testing

- Test composables by mounting a minimal wrapper component, not by calling the composable directly
- Exception: pure logic composables with no DOM/lifecycle dependencies can be called with `withSetup()` helper
- For Nuxt composables (`useFetch`, `useAsyncData`): mock via `vi.mock('#app', ...)` or use `@nuxt/test-utils`

## Hard Rules

- Never mutate `wrapper.vm` properties directly to simulate prop changes — use `wrapper.setProps()`
- Never call composables outside of component setup context without `withSetup` wrapper
- Never use real Pinia in tests — always `createTestingPinia`
- Always `await` event triggers before asserting

## Done Criteria

- All tests use `createTestingPinia` — no real Pinia instances
- All event triggers are awaited
- No direct `wrapper.vm` property mutation for inputs — `setValue()` used
- All composables tested through component mount or `withSetup`
- Tests pass with no Vue warnings

## Output Contract

- Changed tests:
- Behavior covered:
- Command run:
- Remaining risk:
