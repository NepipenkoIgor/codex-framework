---
name: mobile-test-flutter
description: Add Flutter unit, widget, integration, golden, lifecycle, and platform-contract tests using the repository's installed runner and conventions. Use for Flutter-specific behavior; not for React Native.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  domain: mobile
  keywords: [flutter test, widget test, integration test, golden, lifecycle, platform channel, process death]
---

Implement Flutter tests for $ARGUMENTS.

## Preserve the test system

Read instructions, `pubspec`/lockfile, installed Flutter/Dart, existing test helpers, runner flags, state/router/plugin abstractions, CI, devices, fonts/locales, and production behavior. Before material test or golden-baseline mutation, resolve the exact task-owned test, golden, fixture and configuration targets, owning package/team and write authority, and define a reversible diff/baseline review path; never mass-update goldens as rollback. Extend the repository's runner and mocking style; do not replace it with a preferred package. Verify APIs from the installed toolchain or matching official docs. For greenfield only, resolve stable toolchains with `scripts/framework-stack-context.py`.

Choose the lowest layer that can falsify the behavior:

- unit tests for pure rules, parsers, reducers, migrations, and retry/idempotency policy;
- widget tests for semantics, text scaling, focus, loading/error/offline states, navigation intent, and lifecycle-driven UI;
- integration/device tests for plugins, secure storage, background work, push/deep links, process death/restoration, renderer/platform behavior, and native channels;
- explicit Dart/native contract tests for channel method names, schemas, structured errors, cancellation, and unavailable-plugin behavior.

Mock only external boundaries needed by the test. Do not mock every plugin or replace the system under test with its mock. Keep one contract/device path for critical native behavior. Tests must not call real production providers, send notifications, mutate user accounts, or use production credentials.

## Determinism and environment

Control clocks, randomness, locale, timezone, permissions, connectivity, storage fixtures, animation policy, and backend responses through supported seams. Use semantic conditions and repository time budgets; no universal `pumpAndSettle`, timeout, retry, device, or OS value. Infinite/repeating animations require an explicit bounded test strategy rather than blind settling.

Golden tests require a pinned and documented rendering environment: Flutter/engine, renderer, platform, fonts, locale, text scale, pixel ratio, surface size, and animation state. Review image differences as behavior evidence; do not mass-update baselines to make CI green.

Cover lifecycle and process death separately from widget disposal. Verify partial secure-token rotation, key invalidation/restore, deep-link and push validation/duplication, background retries, offline conflicts, reduced motion, text scaling, and channel failure when relevant.

## Verification and output

Run focused tests, then repository-authoritative affected suites/analyzer/build checks. Rerun flaky or failed checks only after identifying the cause; bounded repeats characterize flakiness but do not erase it. Clean only task-owned devices/processes/artifacts.

Report behaviors and layers covered, fixtures/mocks, installed environment, commands/results, golden/device evidence, remaining real-device/native/provider gaps, and any production path deliberately not exercised.
