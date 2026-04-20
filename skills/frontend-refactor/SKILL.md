---
name: frontend-refactor
description: Refactor existing frontend code for maintainability, strong typing, performance, and idiomatic framework patterns
metadata:
  version: 2.4
  argument-hint: "target file/component, refactor goal (performance/readability/patterns), framework"
---

Refactor $ARGUMENTS.


## Tool Integration

- **Type diagnostics** — verify type-safety after refactoring
- **ast-grep** — use for structural code pattern search (find component signatures, hook usages, import patterns) — faster and more accurate than Grep for code structure
- **browser automation** — capture screenshots for visual verification and regression testing

Core refactoring principles:

- Preserve existing business behavior unless the user explicitly requests functional changes
- Prefer safe, incremental refactoring over large rewrites
- Follow existing project conventions unless they are clearly harmful
- Reduce duplication, complexity, and accidental coupling
- Improve readability, maintainability, and long-term extensibility
- Keep components focused; separate UI, state, schemas, types, and data-access concerns
- Avoid over-engineering; prefer small composable units over monolithic components
- TypeScript-first with strong typing; derive types from Zod schemas to avoid duplication
- Eliminate unnecessary rendering work, repeated computations, and wasteful UI patterns

Refactoring priorities:

- duplicated logic, oversized components, weak typing
- noisy or brittle templates, unnecessary re-renders, unstable state placement
- repeated API calls, fragile async flows, poor schema/type separation
- styling duplication, misuse of framework APIs, legacy patterns

Dependencies and imports:

- Prefer existing project dependencies; avoid new libraries unless clearly needed
- Prefer framework-native solutions before third-party packages
- Keep imports clean, minimal, explicit (named over wildcard), and tree-shakable
- Remove unused imports and dead dependencies

Component, state, and async refactoring:

- Reduce component responsibility; extract smaller units when it improves clarity
- Prefer semantic HTML; improve accessibility safely without behavior changes
- Keep state close to usage; eliminate duplicated/redundant derived state
- Prefer computed/derived values over manually synchronized copies; no unnecessary global state
- Eliminate duplicate requests, waterfalls, stale responses, and race conditions
- Handle loading, error, retry, and empty states explicitly
- Separate API types, DTOs, view models, and form models when responsibilities differ

Rendering and performance:

- Eliminate unnecessary re-renders and expensive work in render paths
- Prefer architecture/state improvements before memoization
- Memoize only for measured or strongly indicated performance problems
- Use pagination, lazy loading, virtualization, debounce, or throttle where appropriate

Forms and interactions:

- Refactor toward clearer state ownership and validation structure
- Handle submit, loading, validation, and error states explicitly; prevent duplicate submissions
- Replace ad-hoc validation with cleaner schema-driven validation

Anti-patterns to avoid:

- Large rewrites when targeted refactoring suffices
- New abstractions that do not clearly reduce complexity
- Changing behavior while claiming "just refactoring"
- God components, duplicated state across layers, mixing UI with data fetching
- Clever abstractions that reduce readability

TypeScript:

- Strong static typing; avoid any and loosely typed literals
- Keep shared types, DTOs, schema-derived types, view models in dedicated colocated type files
- Use generics, mapped/conditional types, discriminated unions, satisfies, infer when justified
- Derive types from schemas and contracts; prefer readonly and narrow literal inference
- Reusable generic table, form, API, and state types for repeated project patterns

Validation and schemas:

- Zod as default validation for new TS/JS projects. For established Angular projects, use the existing validation approach (Angular validators, class-validator) unless the team has adopted Zod
- Derive TypeScript types from Zod schemas when using Zod; keep schemas separate from UI when shared/non-trivial
- Refactor toward schema-driven validation when existing validation is fragmented or duplicated

Angular:

- Signal-based state and component design; standalone components; clean templates
- Prefer signals, computed, effects over RxJS for component state
- Modern APIs: `input()`, `output()`, `model()` over decorators
- Modern control flow: `@if`, `@for`, `@switch` over `*ngIf`, `*ngFor`, `*ngSwitch`
- Functional guards and interceptors over class-based
- `inject()` function over constructor injection
- Refactor away from legacy Angular patterns when safe and localized

Angular non-negotiable rules:

## Extended Patterns
For complex scenarios, self-load additional patterns:
Read `skills/frontend-refactor/SKILL.detail.md`
Load only when task involves: large-scale component migrations, design system token replacements, or cross-framework rewrites
