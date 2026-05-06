---
name: fullstack-nextjs-review
description: Review Next.js full-stack changes for App Router correctness, server/client boundaries, caching, and route behavior.
metadata:
  version: 3.0
  argument-hint: "PR/diff/module, App Router area, API/server action/data flow, auth/cache concerns"
---

# Fullstack Next.js Review

Use this skill for review work in Next.js applications that span UI and server behavior.

Target Next.js guidance is governed by `CODEX.versions.md`. Compare the project version to the target before reviewing framework-specific behavior. If the project is below target, report version drift separately from correctness findings.

## When To Use

- App Router pages, layouts, route handlers, middleware, or server actions
- Changes crossing UI, data fetching, auth, and persistence
- Cache, revalidation, streaming, or server/client boundary reviews
- Next.js PRs where frontend behavior and backend contracts interact

## Review Workflow

1. Read the diff and identify changed route segments, server actions, route handlers, and shared components.
2. Check server/client boundaries: `use client` placement, server-only imports, browser-only APIs, and data leakage.
3. Check data flow: validation, auth/session access, request/response contracts, persistence model leakage, and duplicate fetching.
4. Check request APIs: async `params`, `searchParams`, `cookies()`, `headers()`, and `draftMode()` usage under the project’s Next.js version.
5. Check caching: static/dynamic rendering, `fetch` cache mode, Cache Components, `revalidateTag(tag, profile)`, `updateTag`, `refresh`, and mutation invalidation.
6. Check UI states: loading, error, empty, optimistic updates, accessibility, and responsive behavior.
7. Check performance: waterfalls, bundle bloat, client component overuse, unbounded queries, and image/font usage.
8. Check tests and verification: route handler tests, server action tests, component tests, E2E or browser checks for user flows.
9. Report findings first with file references and concrete fix direction.

## Review Focus

- App Router segment behavior and nested layout effects
- Server vs client component boundaries
- Next.js version drift against `CODEX.versions.md`
- `proxy.ts` vs deprecated `middleware.ts` usage and runtime assumptions
- Route handlers and server actions
- Auth, authorization, and session trust boundaries
- Cache invalidation, revalidation, and stale UI risk
- Data validation and API/DB contract integrity
- UI consistency, design-system reuse, accessibility, and loading/error states
- Performance, bundle size, image/font handling, and request waterfalls

## Anti-Patterns

- Adding `use client` to large route trees to fix a small interaction.
- Importing server-only modules into client components.
- Returning persistence entities directly from route handlers or server actions.
- Mutating data without invalidating affected caches.
- Hardcoding URLs, plan IDs, secrets, or environment-specific values.
- Treating App Router loading/error files as optional for user-facing flows.
- Reviewing only the UI while ignoring route handlers, actions, and data contracts.
- Introducing new `middleware.ts`, removed config flags, or sync request API access in Next.js 16 code.

## Verification

- Confirm changed routes build under the project’s Next.js version.
- Run targeted type/lint/tests when available.
- Verify critical user flows in browser automation when UI-visible behavior changes.
- Check auth-required flows with authenticated and unauthenticated states.
- Check cache behavior after mutations.

## Output Contract

Status: done | partial | blocked
Findings: [severity, file, issue, fix direction]
Checked: [routes, handlers, actions, components]
Verification: [commands or manual checks]
Version drift: [current version vs target, migration pressure, or none]
Residual risk: [unverified cache/auth/browser paths]
