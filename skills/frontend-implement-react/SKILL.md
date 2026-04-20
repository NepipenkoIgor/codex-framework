---
name: frontend-implement-react
description: React 19 patterns — hooks, Server Components, concurrent features, forms, state decisions
metadata:
  version: 1.0
  domain: frontend
  keywords: [react, jsx, hooks, context, useState, useEffect, useOptimistic, useActionState, server components, suspense, use client]
---

## Hooks Rules

- Never call hooks conditionally, inside loops, or in nested functions — top-level only.
- Every useEffect with a subscription or timer MUST return a cleanup function.
- Deps array is exhaustive — include every value read inside the effect. Omitting is a bug.
- Never use useEffect to compute derived state — compute inline during render instead.
- Never use useEffect to sync two pieces of state — lift shared logic to an event handler.

## React 19 — New APIs

- `use(promise)` — suspend a component until the promise resolves. Replaces useEffect+useState data fetch patterns. Works inside conditionals unlike other hooks.
- `use(Context)` — read context value. Equivalent to useContext but callable conditionally.
- `useOptimistic(state, updateFn)` — immediately reflect a mutation in UI before server confirms. Always pair with a Server Action. Reverts automatically on error.
- `useActionState(action, initialState)` — wraps a server action; returns [state, dispatch, isPending]. Use for forms with server-side validation and error feedback.
- `useFormStatus()` — reads pending/data/method/action of the nearest parent `<form>`. Only call inside a component rendered inside the form, never in the form component itself.
- `useTransition()` — mark state updates as non-urgent; keeps UI responsive during heavy renders. Use for route changes, tab switches, long list filters.

## Server vs Client Components

- Default: every component is a Server Component — zero client JS shipped unless opted in.
- Add `"use client"` only when the component uses: browser APIs, event handlers, useState, useEffect, or React 19 client hooks.
- Push `"use client"` to the lowest leaf possible — never at layout or page level without strong reason.
- Passing Server Component children as props into a Client Component is valid and keeps the subtree server-rendered.
- Never import a Client Component into a Server Component that runs on the server-only boundary without dynamic import.

## Suspense Boundaries

- Wrap any component that suspends (uses `use(promise)`, lazy(), or async RSC) in `<Suspense fallback={...}>`.
- Place Suspense as close to the suspending component as possible — not at the root.
- Use multiple nested Suspense boundaries to isolate independent loading states.
- `loading.tsx` in Next.js App Router is a Suspense boundary — do not double-wrap.

## State Decisions

- Local state (`useState`/`useReducer`) — UI-only, not shared across routes or siblings.
- Lifted state — share between siblings via nearest common ancestor. Stop here before reaching for context.
- Context — app-wide stable values (theme, auth user, locale). Never put frequently-changing values in context.
- External store (Zustand, Jotai, etc.) — cross-route, high-frequency updates, or complex derived state.
- `useReducer` over `useState` when next state depends on previous state + action type, or when multiple sub-values update together.

## Refs

- `useRef` is for mutable values that do NOT trigger re-renders: DOM node refs, timer IDs, previous value tracking.
- Never store derived state in a ref — compute it inline.
- Never use a ref to drive rendering logic — that is state.

## Performance

- Do NOT add memo/useMemo/useCallback preemptively. React Compiler (React 19) handles most memoization automatically.
- Add memoization only after measuring with React DevTools Profiler — never as a default.
- Expensive pure computations inside a component that re-runs frequently → `useMemo`.
- Stable callback identity needed for a child with `React.memo` → `useCallback`.

## Hard Rules

- Never mutate state directly — always return new value from setState or reducer.
- Never derive state from props in useState initializer unless explicitly lazy-init with function form.
- Never nest a component definition inside another component — extract to module scope.
- Always handle loading and error branches when using `use(promise)`.

## Done Criteria

- LSP reports zero errors.
- No useEffect used where state is derivable from existing values.
- No prop drilling beyond 2 levels without context or composition.
- Every async data read wrapped in a Suspense boundary.
- No memoization added without profiler evidence.
