---
name: frontend-implement
description: Implement frontend features while preserving repository language, installed stack, server/client contracts, accessibility, and mutation safety. Use when no sharper framework or full-stack specialization owns the task; route React, Vue, Angular, or Next.js-dominant work to the matching specialization.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 4.1
  argument-hint: "feature and acceptance criteria, affected routes/components, framework, data and mutation boundaries"
---

# Frontend Implement

Implement `$ARGUMENTS` in the existing repository. This is the generic fallback, not a substitute for a matching specialization.

## Route first

- React-dominant component work: `frontend-implement-react`.
- Vue/Nuxt-dominant component work: `frontend-implement-vue`.
- Angular-dominant component work: `frontend-implement-angular`.
- Next.js full-stack work involving Server Components, Server Actions, Route Handlers, caching, or server auth/data access: `nextjs-development`.
- Use this skill when the stack has no sharper installed specialization or the work is genuinely framework-neutral. Do not blend conflicting recipes.

## Workflow

1. Read instructions, manifests/lockfiles, target routes/components, shared primitives, API/schema/auth contracts, nearby tests, and authoritative commands.
2. Generate stack context before version-sensitive work. Preserve repository language and pins; use installed types/config/CLI capability and matching official docs. Do not introduce TypeScript, a framework upgrade, a state library, or a validation library incidentally.
3. Define caller-visible acceptance across success, loading, empty, error, retry, responsive, keyboard/focus, and fresh-load/navigation states that matter.
4. Resolve exact task-owned mutation targets, write authority/permissions, ownership of data loading, state, validation, mutation, cache invalidation and server/client serialization, plus effect-appropriate rollback/recovery before editing.
5. Implement the smallest cohesive change using existing primitives and conventions; inspect the actual diff.

## Safety and correctness

- Prefer native semantics, accessible names, keyboard operation, perceivable focus, and existing design tokens/primitives.
- Treat all client input as untrusted. Client validation improves UX but does not replace server schema validation, authentication, tenant/resource authorization, or output encoding.
- For consequential mutations, define stable operation identity and server-side idempotency/concurrency semantics where retries or duplicate activation are possible. Disabling a button is not a correctness boundary.
- Make pending, unknown-after-timeout, conflict, partial failure, retry, and persisted success distinguishable. Never claim success solely because the UI closed or a request returned.
- Avoid exposing secrets, privileged data, or server-only modules across the client bundle/serialization boundary.

## Verification and output

- Run the repository's focused test and affected type/lint/build/component/browser checks. Verify a fresh load when initialization, SSR, hydration, or cache behavior is involved.
- Verify rendered behavior plus server/persisted outcome for mutations, including unauthorized and duplicate/retry paths when relevant.
- Report files and behavior changed, installed capability used, commands/results, and untested provider/browser/deployment risk.
