---
name: frontend-refactor
description: Refactor existing frontend code while preserving characterized behavior, repository language, framework boundaries, and public contracts. Use when maintainability or structure changes are explicitly requested; do not use for feature work, diagnosis-only, or an unrequested migration.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.5
  argument-hint: "target and refactor goal, behavior to preserve, framework and verification scope"
---

# Frontend Refactor

Refactor `$ARGUMENTS` within the authorized repository scope.

## Preserve before improving

1. Read instructions, manifests and lockfiles, target code, callers, public exports, styles, data/auth boundaries, nearby tests, and authoritative commands.
Generate project stack context for version-sensitive choices. Existing pins remain authority; for explicitly authorized greenfield creation only, resolve stable/LTS releases from official sources, verify cross-stack compatibility, generate manifest/lockfile and make them authoritative.
2. Characterize current caller-visible behavior before editing: inputs/outputs, rendered states, accessibility semantics, navigation, persistence/network effects, errors, loading, focus, responsive behavior, SSR/hydration, and performance where relevant.
3. Identify the concrete maintenance defect and the smallest boundary that removes it. Establish an executable regression or explicit manual baseline when existing coverage is insufficient.
4. Before editing, confirm the exact mutation boundary and repository authority, plus a recovery path that restores the characterized behavior (normally reverting the scoped diff and prior generated artifacts). Stop when the baseline is uncertain, required capability is incompatible, authority is insufficient, or rollback cannot preserve a consequential contract.
5. Apply incremental changes and inspect the actual diff for accidental behavior or dependency changes.

## Refactoring constraints

- Preserve repository language, installed framework/API capability, validation approach, file conventions, and build/test harness unless migration is explicitly in scope.
- Do not turn JavaScript into TypeScript, adopt Zod, change framework generation, replace state management, or upgrade dependencies as an incidental "cleanup". Propose migrations separately with compatibility and rollback plans.
- Preserve public component props/events/slots, routes, serialization, CSS/layout contracts, server/client ownership, accessible names/roles/focus, and mutation semantics unless the request authorizes a contract change.
- Extract code when cohesion, reuse, testability, or ownership improves. Do not require arbitrary size/duplication thresholds or build generic abstractions for hypothetical reuse.
- Prefer existing dependencies and native framework capabilities. Performance changes require a measured or strongly evidenced problem and comparison at the affected boundary.
- Client validation, disabled buttons, and request deduplication do not replace server validation, authorization, concurrency control, or idempotency.

## Version boundary

Generate stack context before using version-sensitive recipes. For an existing project, manifests, lockfiles, runtime config, installed types, and target deployment are authoritative. Check the applicable engine, peer dependency, compiler/framework, test-runner and deployment-runtime constraints as one compatible set; do not force irrelevant dimensions. Preserve supported pins and apply an API only when installed capability exposes it. A language/framework/toolchain upgrade is a separately authorized migration.

## Verification

- When the repository exposes authoritative focused-test, affected-test, type-check and build commands, run all four; add lint, unit/component and browser checks applicable to the change.
- Compare fresh-load behavior, not only hot-reload or client navigation, when initialization, SSR, caching, or hydration is affected.
- Verify caller-visible outcomes and relevant failure states; command success alone is not proof.
- Any required check failure blocks completion: correct the scoped change, rerun the focused check, then rerun affected checks invalidated by the correction.
- Report the behavior baseline, structural change, compatibility decisions, commands/results, and residual unverified risk.
