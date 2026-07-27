---
name: frontend-implement-react
description: Implement React features using the repository's pinned component, hooks, state, forms and server/client conventions. Use when React-specific behavior dominates; do not use for Vue or Angular.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
---

# React Implementation

Inspect React/framework manifests, lockfile, renderer, compiler/build, routing, data layer and tests. React 18 pins remain authoritative; do not apply React 19-only APIs until installed types/runtime expose them or migration is requested.

- Preserve existing component/state conventions. Keep state closest to its owner and lift/share it by actual coordination need, not arbitrary component boundaries or prop-depth limits.
- Follow hook ordering and effect ownership; effects synchronize external systems, with cancellation/cleanup and Strict Mode-safe behavior.
- Use `useOptimistic` and `useActionState` when the installed React line exposes them and the operation contract benefits. They are not limited to framework Server Actions, though frameworks may add transport/form conventions. Define idempotency, pending/error, rollback/reconciliation and concurrent operation behavior.
- Preserve server/client boundaries from the installed framework; never expose server secrets or trust UI gating as authorization.
- Keep accessibility, focus, semantic behavior, loading/empty/error and hydration states explicit.

Verify pinned React 18/19 capability, Strict Mode, concurrent optimistic operations, timeout/rejection, navigation/unmount, hydration, keyboard/screen reader and repository checks. Report installed API evidence and untested framework paths.
