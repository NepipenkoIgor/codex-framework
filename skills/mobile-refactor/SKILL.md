---
name: mobile-refactor
description: Refactor existing Flutter, React Native, Expo, iOS, or Android mobile code while preserving observable behavior and platform contracts. Use when restructuring or migration is the requested outcome; use framework-specific implementation skills for new features and mobile-review for findings only.
metadata:
  owner: codex-framework
  reviewed: "2026-09-14"
  version: 2.1
  argument-hint: "target files, Flutter/RN/native stack, behavior to preserve, measured problem, allowed migration scope"
---

Refactor $ARGUMENTS.

## Scope the preservation contract

Read instructions, manifests/lockfiles, target and callers, native projects, routing/state/storage, tests, analytics, accessibility, lifecycle, offline and release/update contracts. Record installed stack capabilities. Existing pins remain authority; verify version-specific patterns locally or in matching official docs. Use project stack context for checkout-owned pins; reserve latest-version resolution for authorized greenfield selection or migration.

Before material mutation, resolve exact task-owned app/native/configuration targets, owning team and write authority/permissions, plus a reversible diff and migration rollback/recovery boundary.

Define observable behavior that must remain stable: navigation/deep links, auth and tenant boundaries, persisted schema and secure credentials, API/native contracts, loading/error/offline states, analytics, accessibility, background/process restoration, OTA/runtime compatibility, rendering, and performance budgets.

## Refactor by evidence

- Identify a concrete smell, defect, duplication, coupling, or measured bottleneck and the smallest boundary that resolves it.
- Preserve the repository's architecture unless its migration is explicitly in scope with compatibility, data migration, rollout, and rollback.
- Do not extract hooks/widgets/services merely to reduce line count. Do not introduce memoization, cached styles, a new store, router, database, architecture, native module, or list library by default.
- Memoize only when profiling shows meaningful recomputation/render cost and dependency semantics remain correct. Stable identity is not automatically faster.
- Keep server authorization outside UI state. Preserve secure-storage rotation, restore/logout behavior, route validation, platform-channel/native-module error semantics, reduced motion, text scaling, and lifecycle cleanup.
- For cross-platform code, state which guarantees are shared and which remain Flutter, React Native, iOS, or Android-specific. Never imply parity without running each affected path.

Make changes incrementally behind stable interfaces where possible. For state, navigation, storage, native, or New Architecture migrations, define coexistence, persisted-data compatibility, instrumentation, cutover, and rollback before implementation.

## Verification and output

Run existing characterization tests first when feasible, add focused regression tests, then run repository-authoritative affected checks. Verify relevant device/build/lifecycle/process-death, accessibility, offline, native, and update paths. Compare measured performance only in equivalent environments; do not claim improvement from code shape.

For each affected platform, verify persisted-data compatibility with representative pre-change data. When a migration is in scope, exercise upgrade, restart/restoration and the contracted rollback/recovery path, including secure storage where affected. A migration design alone is not execution evidence; report any untested platform or data path explicitly.

Report preserved behavior, evidence motivating the refactor, changed boundaries, migration/rollback, actual checks and device measurements, and unverified platform risks.
