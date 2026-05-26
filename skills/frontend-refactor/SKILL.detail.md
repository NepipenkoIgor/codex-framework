# frontend-refactor — Extended Patterns (detail file)
# Load on demand — not injected by default

- Angular Signals as default state model
- Signal-based reactive forms (signals + FormGroup or signal-driven form state) for refactored/new forms with schema-based validation
- Zod as default validation for new TS/JS projects. For established Angular projects, use the existing validation approach (Angular validators, class-validator) unless the team has adopted Zod
- No template-driven forms in new code
- Prefer signal-driven form state over RxJS-based form state; migrate toward signal-based reactive forms over legacy patterns

React / Next.js:

- Function components + hooks only, no class components
- React Compiler-compatible patterns when supported
- No defensive memoization without measured need; derived state over synchronized copies
- No business logic in useEffect; keep effects minimal
- Next.js: respect server/client boundaries; avoid duplicate fetching and waterfalls
- Refactor effect-heavy code toward simpler render-driven or state-driven designs

Vue / Nuxt:

- Composition API with `<script setup lang="ts">`; compiler macros (`defineProps`, `defineEmits`, `defineModel`)
- `computed` for derived state, not watchers; narrow reactive scope
- Small focused components; composables (`useXxx()`) for reusable logic without over-abstracting
- Pinia over Vuex for state management; `storeToRefs()` for reactive store access
- Nuxt 3: `useAsyncData()`, `useFetch()`, `$fetch()` over legacy `asyncData`/`$axios`
- `defineComponent()` to `<script setup>` for simpler, less boilerplate components
- Mixins to composables: extract shared logic to `useXxx()` functions

Svelte:

- Svelte 5 Runes as default: `$state()`, `$derived()`, `$effect()`, `$props()`
- Small explicit components; clear reactive state without implicit complexity
- Avoid unnecessary reactive statements and repeated store logic
- Narrow reactive scope; Zod for validation where needed
- `{#snippet}` blocks over slots (Svelte 5)
- Callback props via `$props()` over `createEventDispatcher()`
- `+page.server.ts` for server-only data loading

Styling and CSS:

- Tailwind CSS as primary when available; utility classes for standard layout/spacing/typography
- Extract semantic CSS classes only when utilities repeat, markup gets noisy, or for reusable UI concepts
- CSS for complex selectors, layered states, pseudo-elements, animations, and stateful styling
- No inline styles unless dynamic runtime need; use CSS variables and project theme tokens
- Preserve strict CSP compatibility when refactoring UI: remove avoidable `style` attributes, inline `<style>`, and inline event handlers; route dynamic visual values through CSS variables, classes, or data attributes.
- Refactor repeated utility chains and noisy class strings into clearer reusable patterns

Styling non-negotiable rules:

- Tailwind as primary styling system when available
- No custom CSS for what Tailwind handles well; no inline styles for standard cases
- No `'unsafe-inline'` dependency for normal UI styling; if a framework requires inline styles, isolate and document the exception.
- Move repeated utilities into reusable classes; move complex visual states into CSS
- Keep templates readable; balance Tailwind utilities with CSS where each excels

Refactoring workflow:

1. Detect the framework and conventions used in the codebase
2. Understand the feature boundary, surrounding architecture, and current behavior
3. Identify the highest-value safe refactors before making changes
4. Prefer targeted improvements over broad rewrites
5. Reuse existing utilities, services, schemas, types, and patterns
6. Ensure async flows and rendering behavior become simpler and more efficient
7. Ensure types, schemas, and view models are placed in appropriate dedicated files when non-trivial
8. Summarize what was changed, what risks remain, and what further improvements are optional

Output requirements:

- Start with a short diagnosis of the main issues found
- Propose a concise refactoring plan before large structural changes
- Produce concrete production-ready code, not only advice
- Follow the idioms of the detected framework
- Align with the project's testing approach when tests exist
- Keep type design, schema design, and file organization consistent with the skill rules
- Preserve intended behavior unless the user explicitly asks for product or UX changes

Framework migration patterns:

React class to function components:
- Convert class state to useState hooks; getDerivedStateFromProps to useMemo
- Convert lifecycle methods: componentDidMount/componentWillUnmount to useEffect with cleanup
- Convert class methods to const functions; remove this binding
- Extract custom hooks for reusable logic that was in class methods
- Migrate one component at a time — class and function components can coexist

Angular migration patterns:
- NgModule to standalone: convert `@NgModule` components to `@Component({ standalone: true, imports: [...] })`; move declarations into component-level imports array; remove module files when all components are standalone
- `*ngIf`/`*ngFor` to new control flow: `*ngIf="x"` to `@if (x) { }`, `*ngFor="let i of items"` to `@for (i of items; track i.id) { }`, `*ngSwitch` to `@switch (value) { @case (v) { } }`
- Constructor injection to `inject()`: `constructor(private svc: Service)` to `private svc = inject(Service)`; removes constructor boilerplate, works in functions and standalone context
- RxJS BehaviorSubject to Signals: replace `.getValue()`/`.next()` with `signal()`/`.set()`/`.update()`; replace `combineLatest` + `map` with `computed()`; replace `.subscribe()` in components with `effect()` for side effects
- Class-based guards/resolvers to functional: `canActivate: [AuthGuard]` to `canActivate: [() => inject(AuthService).isAuthenticated()]`; functional interceptors via `HttpInterceptorFn`
- Decorator inputs to signal inputs: `@Input() name: string` to `name = input<string>()`; `@Output() clicked = new EventEmitter()` to `clicked = output<void>()`; `@Input()/@Output()` pair to `value = model<string>()`
- Template-driven/Reactive Forms to signal-based reactive forms: replace imperative form state with signal-driven form state
- Migrate route-by-route; keep old and new patterns coexisting during migration

Vue Options API to Composition API:
- `data()` to `ref()`/`reactive()`; `computed:` properties to `computed()`; `methods:` to plain functions
- Lifecycle hooks: `created` to script setup body; `mounted` to `onMounted()`; `beforeDestroy` to `onBeforeUnmount()`
- `defineComponent()` to `<script setup>`: remove `defineComponent()` wrapper, export props via `defineProps()`, events via `defineEmits()`, two-way binding via `defineModel()`
- Mixins to composables: extract shared logic to `useXxx()` functions; replace `this.mixinMethod()` with composable return values
- Vuex to Pinia: `mapState`/`mapActions` to `storeToRefs()` + direct method calls; `modules` to separate Pinia stores; `mutations` removed (direct state mutation in Pinia actions)
- Nuxt 2 to Nuxt 3: `asyncData` to `useAsyncData()`; `fetch` to `useFetch()`; `$axios` to `$fetch()`; `middleware` files to `defineNuxtRouteMiddleware()`; Options API plugins to Composition API composables
- Use `<script setup lang="ts">` for new/migrated components; keep options for complex legacy if needed

JavaScript to TypeScript migration:
- Start with tsconfig.json: strict: false initially, add strictNullChecks and noImplicitAny incrementally
- Rename .js to .ts file by file; fix type errors as you go
- Add types to function signatures first (highest value), then variables
- Use unknown over any for untyped external data; narrow with type guards
- Generate types from API schemas (OpenAPI → TypeScript) rather than writing by hand
- Target: strict: true with zero any across the codebase

SvelteKit refactoring patterns:
- Stores to Runes: `writable(0)` to `let count = $state(0)`; `derived(store, $s => ...)` to `let value = $derived(...)`
- `$:` reactive blocks to `$effect()` for side effects and `$derived()` for computed values
- Slots to `{#snippet}` blocks (Svelte 5): named slots become named snippets with explicit parameter passing
- `export let prop` to `let { prop } = $props()`: destructure all props from `$props()` call
- `createEventDispatcher()` to callback props: `dispatch('click', data)` becomes `let { onclick } = $props()` with `onclick(data)`
- `+page.ts` to `+page.server.ts` when data is server-only: move `load` functions to server files to avoid shipping server logic to the client
- `onMount` with fetch to `+page.server.ts` load: move data fetching from component lifecycle to SvelteKit load functions for SSR and streaming

Next.js refactoring patterns:
- Pages Router to App Router: `getServerSideProps` to `async` Server Component; `getStaticProps` to static Server Component with optional `revalidate`; `getStaticPaths` to `generateStaticParams()`
- `useRouter()` from `next/router` to `useRouter()` from `next/navigation` + `useSearchParams()` + `usePathname()`; `router.query` to `useParams()` or `useSearchParams()`
- API routes (`pages/api/`) to Route Handlers (`app/api/route.ts`) or Server Actions for mutations
- `_app.tsx` to `app/layout.tsx`; `_document.tsx` to root layout `<html>` tag; `_error.tsx` to `error.tsx` (per-route) and `global-error.tsx`
- Client-side data fetching to Server Components: move `useEffect` + `useState` fetch patterns to `async` Server Components that fetch directly
- `getServerSideProps` redirect/notFound to `redirect()` and `notFound()` from `next/navigation`

Blazor refactoring patterns:
- Legacy Blazor Server to .NET 8+ Interactive Server render mode: add `@rendermode InteractiveServer` to components that need interactivity; default to static SSR for content pages
- `@code` block cleanup: extract large `@code` blocks to code-behind `.razor.cs` files; keep Razor markup readable
- `OnInitializedAsync` to `OnParametersSetAsync` when data loading depends on route params or cascading parameters that may change
- `IJSRuntime` scattered calls to centralized JS interop service: wrap related JS calls in a dedicated service with `IJSObjectReference` and proper `IAsyncDisposable` cleanup
- `StateHasChanged()` overuse: refactor excessive manual `StateHasChanged()` calls by fixing state ownership; use child components with explicit parameters instead
- Monolithic page components: split overgrown `.razor` pages that combine tables, dialogs, forms, and service calls into focused child components

Component refactoring patterns:

Extract component:
- When a component exceeds ~200 lines or has multiple distinct responsibilities
- Extract by visual section (header, sidebar, content) or by behavior (form, table, dialog)
- Pass data down via props; emit events up — do not reach into parent state

Extract custom hook / composable:
- When multiple components share the same state + effect pattern
- Extract the state, effects, and derived values into a reusable function
- Keep the hook focused: one concern per hook (useAuth, usePagination, useDebounce)
- Return only what consumers need — hide implementation details

Flatten component hierarchy:
- When prop drilling exceeds 3 levels, consider: context/provide (scoped), state management, or composition
- Prefer composition (slots/children) over deep nesting with prop forwarding
- Flatten wrapper components that only pass props through without adding behavior

Simplify conditional rendering:
- Extract complex condition logic into named boolean variables or computed properties
- Replace nested ternaries with early returns or guard clauses
- Extract each conditional branch into its own component when logic is complex

State refactoring patterns:

Lift state up:
- When siblings need to share state, move it to the nearest common parent
- Pass state down as props and updater functions as callbacks
- Appropriate when: 2-3 components share state, nesting is shallow

Push state down:
- When parent holds state only one child uses, move it into the child
- Reduces parent re-renders and simplifies parent component
- Appropriate when: state is used in only one subtree

Replace synchronized state with derived state:
- Symptom: two state values that must always be in sync (state + derived copy)
- Fix: keep one source of truth, derive the other with computed/useMemo
- Common case: filtered list derived from full list + filter criteria

Example — simplify a bloated component by extracting a hook and removing duplicated state:

Before:

```tsx
function UserList() {
  const [users, setUsers] = useState<User[]>([]);
  const [filteredUsers, setFilteredUsers] = useState<User[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => { fetchUsers().then(setUsers).finally(() => setLoading(false)); }, []);
  useEffect(() => {
    setFilteredUsers(users.filter((u) => u.name.toLowerCase().includes(search.toLowerCase())));
  }, [users, search]); // synchronized copy — bug-prone

  return loading ? <Spinner /> : (
    <div>
      <input value={search} onChange={(e) => setSearch(e.target.value)} />
      {filteredUsers.map((u) => <UserCard key={u.id} user={u} />)}
    </div>
  );
}
```

After:

```tsx
function UserList() {
  const { data: users = [], isLoading } = useQuery({ queryKey: ['users'], queryFn: fetchUsers });
  const [search, setSearch] = useState('');
  const filtered = useMemo(
    () => users.filter((u) => u.name.toLowerCase().includes(search.toLowerCase())),
    [users, search],
  );

  if (isLoading) return <Spinner />;
  return (
    <div>
      <input value={search} onChange={(e) => setSearch(e.target.value)} />
      {filtered.map((u) => <UserCard key={u.id} user={u} />)}
    </div>
  );
}
```

Changes: removed duplicated `filteredUsers` state, replaced manual fetch with TanStack Query, derived `filtered` with `useMemo` instead of synchronizing via a second `useEffect`.

Replace global state with server state:
- Symptom: global store caching API data with manual invalidation
- Fix: use server state management (React Query, SWR, Angular query) — handles caching, revalidation, optimistic updates
- Keep global state only for truly client-side concerns (theme, sidebar open, draft form data)

Common refactoring anti-patterns to avoid:
- Extracting components too early — wait until duplication or complexity justifies it
- Creating abstractions for one-time use — three copies is the extraction threshold
- Renaming everything during a refactor — changes obscure the meaningful diff
- Mixing behavior changes with structural refactoring in the same PR
- Refactoring test code at the same time as production code — two moving targets
- Over-abstracting form logic — forms are inherently procedural; some repetition is clearer than a framework
- Premature optimization disguised as refactoring — measure first

## LSP Workflow (TypeScript/JavaScript)
After every file edit:
1. Use available diagnostics tools or the repo's local type-check command to check for type errors
2. Fix all errors before proceeding to the next file
3. Never use `tsc --noEmit`, `npm run build`, or any compiler CLI — LSP is the single source of truth
4. If LSP results appear stale (error on a line that no longer exists), wait 2s and retry once

## Structured Output Contract
- **Status**: `done` | `partial` | `blocked`
- **Changed**: `[file.ext: +lines/-lines, ...]` — list every modified file
- **Notes**: blockers or non-obvious decisions only — omit if none

Do NOT return prose summaries or recaps.
