---
name: frontend-test-react
description: React testing with RTL, vitest/jest, msw — behavior-driven, no implementation details
metadata:
  version: 1.0
  domain: frontend
  keywords: [react, testing, rtl, react testing library, vitest, jest, msw, userEvent, act, renderHook]
---

# Frontend Test — React

Pair with `frontend-test` for universal testing principles.

## Setup

- Use `@testing-library/react` + `@testing-library/user-event` — never Enzyme, never shallow rendering
- Use `vitest` (preferred) or `jest` as test runner — configure `jsdom` environment
- Use `msw` (Mock Service Worker) for API mocking — never mock fetch/axios directly
- Use `@testing-library/jest-dom` matchers — always import in setup file, never per-test

## Querying

- Query priority (highest to lowest): `getByRole` → `getByLabelText` → `getByPlaceholderText` → `getByText` → `getByTestId`
- Never use `getByTestId` when a semantic query works — it tests implementation not behavior
- Never query by class name or element tag — fragile and implementation-coupled
- Use `findBy*` for async elements (returns promise), `queryBy*` only for asserting absence

## User Interactions

- Always use `userEvent` from `@testing-library/user-event` — never `fireEvent` for user actions
- Always `await userEvent.setup()` at test start, then call methods on the instance
- Never simulate events directly on DOM nodes — go through userEvent

## Async Testing

- Use `findBy*` queries for elements that appear asynchronously — never `waitFor` + `getBy`
- Use `waitFor` only for non-element async assertions (e.g. mock call count)
- Never use `act()` manually when using `userEvent` or RTL async utilities — they wrap automatically

## Hooks Testing

- Use `renderHook()` from `@testing-library/react` for isolated hook tests
- Always wrap state updates in `act()` when testing hooks directly with `renderHook`
- Test hook behavior through component rendering when possible — renderHook for complex isolated logic only

## MSW

- Define handlers in `src/mocks/handlers.ts`, server in `src/mocks/server.ts`
- Use `server.use()` in individual tests to override handlers for error/edge cases
- Always call `server.resetHandlers()` in `afterEach` — never leave overrides leaking

## Hard Rules

- Never test implementation details (internal state, private methods, component internals)
- Never use `shallow` rendering — always full render
- Never mock React hooks directly — test behavior through rendered output
- Never `fireEvent` when `userEvent` applies
- Never `getByTestId` when semantic query exists
- Always `await` async queries — never ignore returned promises

## Done Criteria

- All user interactions use `userEvent`
- All API calls mocked via MSW, not fetch stubs
- No `getByTestId` where semantic query works
- No `fireEvent` calls
- All async assertions use `findBy*` or `waitFor`
- Tests pass without console errors or act() warnings
