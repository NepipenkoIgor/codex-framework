---
name: frontend-architecture
description: Design frontend application architecture including component hierarchies, state management, routing, data fetching, form systems, and build strategies
metadata:
  version: 1.8
  argument-hint: "application domain, framework (React/Vue/Angular/Svelte), team size, key features (forms/tables/real-time), scale expectations"
---

Design the frontend architecture for $ARGUMENTS.

## Tool Integration

- **Type diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone

Core architecture principles:

- Follow existing project conventions when extending an existing system
- Design systems that are easy to implement, test, evolve, and navigate
- Keep component responsibilities, state ownership, and data flow explicit
- Separate UI rendering, state management, data fetching, validation, and side effects
- Avoid over-engineering; prefer the smallest clean architecture that fits the problem
- Prefer explicit, predictable data flow over implicit reactivity chains
- Design for developer ergonomics and onboarding clarity

Architecture completeness checklist:

- Identify application structure: feature-based vs layer-based organization
- Identify component hierarchy: shared vs feature-scoped, presentational vs container
- Identify state ownership: local component, feature-scoped, or global store
- Identify server state vs client state boundaries
- Identify routing structure: lazy loading, guards, nested routes, layouts
- Identify data fetching strategy: server components, query libraries, HTTP layer
- Identify form architecture: schema-driven validation, multi-step flows, submission handling
- Identify API integration layer: client generation, error handling, retry, caching
- Identify authentication and authorization UI patterns
- Identify design system or component library strategy
- Identify build strategy: code splitting, dynamic imports, bundle optimization
- Identify testing strategy: unit, integration, E2E distribution
- Identify error boundary and fallback UI strategy
- Identify internationalization needs
- Identify accessibility requirements: ARIA patterns, keyboard navigation, screen reader support

Architecture workflow:

1. Identify the product goal and core user workflows
2. Define application structure and module boundaries
3. Define component tree and shared component strategy
4. Define state management strategy and data flow
5. Define routing architecture and navigation patterns
6. Define data fetching and API integration layer
7. Define form architecture and validation strategy
8. Define error handling, loading states, and fallback UI
9. Map architecture into implementation-ready structure for the target framework
10. Highlight tradeoffs, risks, and recommended next steps

Application structure:

- Feature-based organization preferred: group by domain feature, not by technical layer
- Each feature module owns its components, state, types, schemas, and API calls
- Shared module for cross-cutting components, utilities, hooks/composables, and types
- Avoid deep nesting; prefer flat feature folders with clear naming
- Keep index files for clean public API from each feature module

Component architecture:

- Distinguish presentational components (UI-only, props-driven) from container components (state, data fetching, orchestration)
- Prefer small, focused components; split when a component handles multiple responsibilities
- Shared components: design system primitives, layout components, generic UI patterns
- Feature components: domain-specific, composed from shared primitives
- Avoid prop drilling beyond two levels; use composition, context, or dependency injection
- Design component APIs for reuse: explicit props, sensible defaults, slots/children for flexibility

Example — component hierarchy with state ownership for an orders feature:

```
OrdersPage (container — owns query params, fetches data)
├── OrderFilters (presentational — emits filter changes up)
├── OrderTable (presentational — receives rows, emits sort/select)
│   └── OrderRow (presentational — receives single order)
├── OrderDetailDrawer (container — fetches detail by ID)
│   ├── OrderSummary (presentational)
│   └── OrderActions (presentational — emits action events)
└── Pagination (shared — receives page/total, emits page change)

State ownership:
  OrdersPage:
    - server state: useQuery(['orders', filters]) → TanStack Query
    - client state: selectedOrderId (local), drawerOpen (local)
    - URL state: page, sort, filter (searchParams)
  OrderDetailDrawer:
    - server state: useQuery(['orders', id]) → TanStack Query
  OrderFilters, OrderTable, Pagination:
    - no owned state — controlled via props + callbacks
```

State management strategy:

- Keep state as close to usage as possible; lift only when multiple components need it
- Server state (fetched data) managed separately from client state (UI state, form state)
- Server state: query libraries (TanStack Query, SWR, Angular query patterns) for caching, revalidation, and deduplication
- Client state: component-local state for UI concerns; global store only for genuinely cross-cutting state
- Derived/computed state preferred over manually synchronized copies
- Avoid redundant state that can be computed from existing data
- Framework-specific: Angular signals, React hooks/reducers, Vue refs/reactive, Svelte stores

Routing architecture:

- Lazy-load feature routes by default; eager-load shell and critical paths
- Define route guards for authentication, authorization, and feature flags
- Use nested routes and layout routes for consistent page structure
- Keep route definitions colocated with feature modules when framework supports it
- Handle 404, unauthorized, and error routes explicitly
- Prefer URL-driven state for filters, pagination, and navigation

Data fetching strategy:

- Separate data fetching from UI rendering; avoid fetch calls inside render logic
- Prefer query/cache libraries for server state: automatic caching, deduplication, background revalidation
- Server components (Next.js, Nuxt, SvelteKit): fetch at the server boundary, pass to client components
- Define loading, error, empty, and success states for every async operation
- Avoid request waterfalls; parallelize independent data needs
- Prefetch data on navigation intent when latency matters

Form architecture:

- Schema-driven forms: define shape and validation with Zod, derive types from schemas
- Keep validation close to form logic; colocate schemas with form components or feature module
- Handle all form states explicitly: pristine, dirty, validating, submitting, success, error
- Prevent duplicate submissions; disable submit during in-flight requests
- Multi-step forms: define step schemas separately, compose for full validation
- Prefer controlled form state with clear reset and error recovery

API integration layer:

- Centralized HTTP client with interceptors for auth tokens, error handling, and retry
- Generated API clients from OpenAPI specs when available
- Typed request/response contracts; separate API types from UI view models when shape differs
- Handle network errors, timeouts, and server errors at the integration boundary
- Retry with backoff for transient failures

Authentication and authorization UI:

- Auth state available globally via context, store, or service
- Route guards redirect unauthenticated users; protect sensitive UI sections
- Token refresh handled transparently in HTTP interceptor layer
- Role/permission-based UI: hide or disable features based on user capabilities
- Distinguish authentication (who) from authorization (what they can do)

Design system and component library:

- Prefer established component library (shadcn/ui, Radix, Angular CDK, Headless UI) over custom primitives
- Build domain-specific composed components on top of primitives
- Consistent theming via CSS variables or Tailwind config
- Accessibility built into primitives: keyboard navigation, ARIA attributes, focus management

Build and bundling strategy:

- Code split by route; dynamic import for heavy features and modals
- Tree-shake unused code; monitor bundle size with build analysis
- Environment-specific configuration; no secrets in client bundles
- Cache strategy for static assets; content hashing for cache busting

Testing strategy:

- Unit tests: utilities, hooks/composables, state logic, schema validation
- Integration tests: component rendering with state and user interaction
- E2E tests: critical user flows, authentication, form submissions
- Prefer testing behavior over implementation details; mock API layer at the boundary

Error boundary and fallback UI:

- Error boundaries at route and feature level; prevent full-app crashes
- Meaningful error messages with recovery actions (retry, navigate back)
- Loading skeletons or placeholders; avoid layout shift
- Empty states with guidance: explain why empty, suggest next action

Internationalization:

- Extract user-facing strings; no hardcoded text in components
- Framework-native i18n; lazy-load locale data per language
- Support RTL layouts when required; design components for text direction flexibility

Accessibility architecture:

- Semantic HTML as foundation; headings, landmarks, lists, buttons, links
- ARIA attributes for custom widgets: roles, states, labels, live regions
- Keyboard navigation: focus management, tab order, keyboard shortcuts
- Color contrast compliance (WCAG AA minimum); no color-only signaling

Framework-specific guidance:

Angular:
- Standalone components; signal-based state; lazy-loaded feature routes
- Services for shared state and data access; inject where needed
- Prefer signals and computed over RxJS for component state
- Signal Forms for new form development

React / Next.js:
- Function components and hooks; server components where supported
- Colocation: keep component, styles, types, and tests together
- App Router patterns: layouts, loading, error, and not-found conventions
- Avoid excessive context nesting; prefer composition
- In Next.js 16, `params`, `searchParams`, `cookies()`, `headers()`, and `draftMode()` are async only — always await before destructuring. Type `params` as `Promise<{ slug: string }>`.
- In Next.js 16, request-time rendering is dynamic by default unless caching is explicit.
- In Next.js 16, prefer `proxy.ts` for request interception; use `middleware.ts` only for explicit Edge runtime cases or projects not yet migrated.
- Check the project's installed framework version and current official guidance before broad framework work; report material version drift.

Next.js App Router architecture:

Server vs Client component decision:

```
                    ┌─ Needs interactivity (onClick, onChange, hooks)?  → 'use client'
                    ├─ Needs browser APIs (window, localStorage)?      → 'use client'
Component ──────────├─ Needs React state or effects?                   → 'use client'
                    ├─ Only renders data / static markup?              → Server Component (default)
                    ├─ Fetches data directly (db, API)?                → Server Component
                    └─ Uses server-only secrets/env?                   → Server Component
```

Rule: start every component as Server Component. Add 'use client' only when interactivity is required. Push 'use client' to the leaf — wrap only the interactive part, not the whole page.

Route groups for layout separation:

```
app/
  (marketing)/         # public marketing layout (no sidebar, no auth)
    layout.tsx
    page.tsx            # landing page
    pricing/page.tsx
    about/page.tsx
  (app)/               # authenticated app layout (sidebar, nav, auth guard)
    layout.tsx
    dashboard/page.tsx
    settings/page.tsx
  (auth)/              # minimal auth layout (centered card)
    layout.tsx
    login/page.tsx
    register/page.tsx
```

- Route groups `(name)` do not affect URL — `/dashboard`, not `/(app)/dashboard`
- Each group gets its own layout.tsx with distinct shell, nav, and providers
- Use for separating auth vs public vs admin layouts cleanly

Parallel routes:

- Define named slots with `@slotName` directories in the same layout
- Each slot renders independently and can have its own loading/error states
- Layout receives slots as props alongside `children`
- Use `default.tsx` in each slot to provide fallback for unmatched sub-routes

```
app/
  @analytics/
    page.tsx          # analytics panel
    default.tsx       # fallback when sub-route doesn't match
  @activity/
    page.tsx          # activity feed
    default.tsx
  layout.tsx          # receives { children, analytics, activity }
  page.tsx            # main content
```

Intercepting routes:

- `(.)` intercepts same-level route, `(..)` parent-level, `(...)` root-level
- Primary use case: modal overlays that preserve URL for sharing/refresh
- Direct navigation (refresh, link paste) renders the full page; soft navigation renders the modal
- Combine with parallel route `@modal` slot for clean modal management

```
app/
  layout.tsx                    # { children, modal }
  @modal/
    default.tsx                 # null — no modal active
    (.)items/[id]/page.tsx      # intercepted: show item in modal
  items/
    page.tsx                    # item list
    [id]/page.tsx               # full item detail page (direct nav)
```

Vue / Nuxt:
- Composition API with script setup; composables for reusable logic
- Pinia for global state; computed for derived values
- Nuxt auto-imports, file-based routing, server routes

Svelte / SvelteKit:
- Small focused components; explicit reactive declarations
- SvelteKit load functions for data fetching; form actions for mutations
- Stores for shared state; derived stores for computed values

Architecture output format:

Provide:

1. Architecture summary (problem, approach, key decisions)
2. Application structure (folder layout, module boundaries)
3. Component hierarchy (shared components, feature components, page components)
4. State management map (what state lives where, server vs client)
5. Routing architecture (route tree, lazy loading, guards, layouts)
6. Data fetching strategy (where data is fetched, caching, revalidation)
7. Form architecture (validation strategy, schema locations, multi-step handling)
8. API integration design (client setup, interceptors, error handling)
9. Build and performance strategy (code splitting, bundle optimization)
10. Testing approach (what to test, testing boundaries, tooling)
11. Implementation-ready folder structure for the target framework
12. Tradeoffs, assumptions, risks, and follow-up recommendations

Output requirements:

- Start with a short architecture summary
- Identify the main features, component boundaries, and state ownership
- Define recommended data fetching, form, and API patterns
- Map the design into implementation-ready structure for the target framework
