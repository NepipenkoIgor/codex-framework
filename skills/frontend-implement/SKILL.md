---
name: frontend-implement
description: Implement new frontend features — components, pages, forms, routing, data fetching, and interactions
metadata:
  version: 3.0
  argument-hint: "feature/component name, framework (React/Vue/Angular), page or module context"
---

Implement $ARGUMENTS.

## Tool Integration

- Use the available TypeScript or framework diagnostics tools after meaningful code changes.
- Use the available docs lookup tool when framework or library syntax is uncertain.
- Use browser automation when runtime behavior or visual state matters.

## Core Principles

- Follow existing conventions, file structure, naming, and architecture.
- Prefer consistency with the current codebase over introducing new patterns.
- Keep components focused; separate UI, state, schemas, types, and data-access concerns.
- Reuse the existing design system, UI kit, primitives, tokens, and component variants before adding new UI surface.
- Prefer project utility classes, variant helpers, and shared class composition helpers over inline styles or arbitrary values.
- Do not add inline styles for standard styling. Use inline styles only for values that must be computed at runtime, and prefer CSS variables or data attributes when they keep CSP compatibility intact.
- Avoid hardcoded visual values when tokens, theme variables, or shared variants exist.
- TypeScript-first; derive types from schemas to avoid duplication.
- Build async flows with loading, error, empty, and success states.
- Prefer explicit, predictable data flow.
- Keep implementation simple: solve the current product problem without speculative abstraction.

## Dependencies and Imports

- Prefer existing project dependencies.
- Prefer framework-native solutions before third-party packages.
- Keep imports explicit and remove unused ones.

## State, Async, and Performance

- Keep state close to usage; prefer derived values over synchronized copies.
- Avoid duplicate requests and race conditions.
- Separate request DTOs, API types, UI view models, and form models when responsibilities differ.
- Prefer architecture and state fixes before memoization.
- Avoid render waterfalls, unstable keys, and unnecessary re-renders; measure before adding complex performance optimizations.

## UI Consistency

- Inspect nearby components and shared UI primitives before creating new elements.
- Match existing spacing, typography, radius, shadow, icon, and focus patterns.
- Use design tokens or semantic utility classes for colors and spacing.
- Keep UI compatible with strict CSP: avoid `style` attributes, inline `<style>`, and inline event handlers unless the deployment explicitly supports nonces/hashes.
- Do not introduce a parallel UI kit or one-off styling system.
- Keep interactive states complete: default, hover, focus-visible, active, disabled, loading, and error.
- Design for responsive behavior with existing breakpoints and layout primitives.

## Forms

- Keep validation close to form behavior.
- Prevent duplicate submissions.
- Handle loading and error states explicitly.

## TypeScript

- Strong static typing; avoid `any`.
- Keep non-trivial shared types in dedicated colocated files.
- Use advanced type features for safety, not cleverness.

## Validation and Schemas

- Zod is the default for new TS/JS projects.
- In established Angular projects, follow the team's existing validation approach unless a change is justified.

## Framework Guidance

### React / Next.js

- Function components + hooks only.
- Prefer derived state over synchronized copies.
- Avoid business logic in `useEffect`.
- Respect server/client boundaries in Next.js.

### Angular

- Prefer signal-based state and standalone components where the repo supports them.
- Prefer `@if`, `@for`, and `@switch` in modern Angular code.
- Prefer `inject()` and modern reactive patterns over constructor-heavy code.

### Vue / Nuxt

- Prefer Composition API with explicit reactive state.
- Use `computed` for derived state and keep watchers narrow.

### Svelte

- Keep reactive state simple and explicit.
- Avoid effect chains that hide ownership or ordering.

## Verification

1. Run the relevant diagnostics or type checks.
2. Run targeted tests when the repo has them.
3. Verify the changed user flow in the browser when practical.

## Output Requirements

- Produce production-ready code in the repository's existing style.
- Keep the implementation narrow.
- State assumptions when context is missing.
- Mention any design-system, token, or UI consistency assumption that could not be verified.
