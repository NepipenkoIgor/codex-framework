---
name: state-management
description: State management architecture and patterns — choosing tools, layering strategy, persistence, and testing
metadata:
  version: 1.6
  argument-hint: "framework (React/Angular/Vue/Svelte), state scope (local/feature/global), server state handling"
---

Design state management for $ARGUMENTS using appropriate patterns and tools for the framework and scope.


## State Location Decision Tree

Choose the right tool for the scope:

1. **Component-local** → useState/signal/ref (simplest, preferred)
2. **Shared between siblings** → lift to parent, pass down
3. **Shared across distant components** → context/provide-inject/service
4. **App-wide with complex updates** → store (Redux/Zustand/Pinia/NgRx)
5. **Server state (API data)** → TanStack Query/SWR/Apollo (NOT a store)
6. **Complex async workflows** → state machine (XState) or reducer
7. **URL-driven state** → URL params (single source of truth)

**Golden rule:** Never put server state in a client store. Separate concerns.

## State Categories

| Category | Examples | Storage | Tool |
|----------|----------|---------|------|
| Client (UI) | theme, modal open, form draft | memory/localStorage | useState/Zustand |
| Server (API) | users list, posts, profile | cache | TanStack Query |
| URL | filters, pagination, search | URL params | useSearchParams |
| Complex async | multi-step wizard, form submission | state machine | XState |
| Persisted | user preferences, saved searches | localStorage | Zustand persist |

## Persistence Strategy

| Storage | Best for | Considerations |
|---------|----------|----------------|
| URL params | Filters, pagination, sort (shareable, bookmarkable) | No sensitive data |
| sessionStorage | Wizard progress, form drafts (temporary) | Clears on tab close |
| localStorage | User preferences, theme, dark mode | Version migrations, clear on logout |
| IndexedDB | Offline data, large datasets (100+ MB) | Complex queries |
| Database | Source of truth for sensitive data | Always sync after local changes |

## Optimistic Updates

Pattern for instant UI feedback:

1. Store previous state before mutation
2. Apply update optimistically (show new state immediately)
3. Send mutation to server
4. On failure: rollback to previous, show error
5. Disable conflicting actions during pending mutation

## Derived & Computed State

Never store what can be computed:

- React: `useMemo()` for expensive computations
- Angular: `computed()` signal for reactive derived values
- Vue: `computed()` property
- Svelte: `$derived` rune
- Blazor: `@computed` pattern

## State Normalization

For collections with 50+ items needing frequent ID lookups:

```typescript
interface NormalizedState<T> {
  byId: Record<string, T>;
  allIds: string[];
}
```

Use Redux Toolkit `createEntityAdapter` or Zustand with Immer.



## Framework Choice Summary

| Framework | Default | Client Store | Server State | Complex Async |
|-----------|---------|--------------|--------------|---------------|
| React | useState | Zustand/Jotai | TanStack Query | XState |
| Angular | Signals | NgRx SignalStore | TanStack Query | Signals + RxJS |
| Vue 3 | Pinia | Pinia | TanStack Query | Composables |
| Svelte 5 | Runes | Runes + stores | SvelteKit load | XState |
| Next.js | Server Actions | Zustand | TanStack Query | Server Actions |
| Blazor | Cascading | Services | HttpClient | SignalR |

## Server State Patterns

Separate client state from server state:

- **Client store:** User preferences, theme, UI state
- **Server cache:** TanStack Query for API data with invalidation
- **Mutations:** Always go through mutations with optimistic updates
- **Revalidation:** Invalidate related queries on mutation

## Testing Strategy

- **Unit tests:** State transitions, reducers, selectors
- **Integration tests:** State + components interact correctly
- **Optimistic updates:** Verify rollback on error
- **Persistence:** Verify migrations on localStorage changes

## Anti-Patterns

1. **Server in store:** Storing API data in Redux/Zustand (use TanStack Query)
2. **Infinite loops:** Using effect to sync derived state (use computed)
3. **Boolean bloat:** Multiple boolean flags for state (use discriminated unions)
4. **Global everything:** All state in single global store (colocate when possible)

> For extended implementation patterns, ask to invoke `/state-management-implement` on demand.
