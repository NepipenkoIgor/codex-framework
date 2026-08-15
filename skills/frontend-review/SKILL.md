---
name: frontend-review
description: Review frontend changes for concrete correctness, regression, performance, maintainability, and test risks. Use when a read-only findings report is requested; route broad WCAG, visual-system consistency, or security audits to their dedicated skills and do not implement fixes.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.1
  argument-hint: "PR/diff/module, framework, expected behavior, review and verification scope"
---

# Frontend Review

Review `$ARGUMENTS` read-only. Findings must identify a behavior-changing defect or material regression risk supported by evidence.

## Boundary and workflow

1. Read applicable instructions, the actual diff and callers, manifests/lockfiles, generated types/config, nearby tests, and public browser/server contracts.
2. Reconstruct expected behavior across fresh load/navigation, SSR/hydration, loading/empty/error/retry, focus/keyboard, responsive/theme, authorization, cache, and mutation states affected by the diff.
3. Trace high-risk paths first: server/client ownership, stale async work, data exposure, mutation validation/authorization/idempotency, rendering/hydration, event/focus lifecycle, and performance-sensitive loops.
4. Use the repository's installed framework capability and authoritative commands. A newer documented API is not a defect when the pinned supported stack does not expose it.
5. Exercise focused tests or rendered behavior when safe and useful. Clearly label code-only hypotheses and untested authenticated/provider/browser paths.

## Ownership

- Own diff-scoped frontend correctness and regression findings, including accessibility or UI symptoms caused by the reviewed change.
- Route broad criterion-level WCAG conformance to `accessibility-audit`, system-wide token/variant drift to `ui-consistency-audit`, and threat-model/vulnerability work to `security-audit`.
- Do not inflate style preferences, optional refactors, or unsupported best practices into findings.

## Evidence rules

- Report CSP only from an authoritative deployed/header policy, repository policy test, or explicit target. Inline styles are not universally invalid; nonces/hashes, framework behavior, CSP directives, and browser support determine impact. Never recommend `'unsafe-inline'` as a routine fix.
- Treat hardcoded values as defects only when they violate an authoritative token/component contract or cause observable inconsistency.
- Verify exact framework/runtime/package capability from project pins and installed artifacts before making version-sensitive claims. Determine and check every applicable cross-stack boundary exposed by the repository—runtime engine ranges, peer dependencies, compiler/framework coupling, test tooling, native/build tooling and deployment runtime—and explicitly mark absent or unavailable dimensions instead of silently omitting them.
- A passing unit test, screenshot, or build does not prove authenticated, persisted, hydration, accessibility, or production behavior outside its boundary.
- When acting authority, resource ownership, idempotency or effect recovery/rollback remains unresolved on a material mutation path, report that missing boundary as a blocker rather than assuming safety.

## Output

Findings first, ordered by severity. Each finding includes exact file/line, affected execution path, expected versus observed behavior, reproduction or concrete counterexample, impact, and bounded fix direction. Then report checks/evidence used, open blockers, and residual risk. If no actionable finding is supported, say so explicitly.
