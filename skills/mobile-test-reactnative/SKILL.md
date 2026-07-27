---
name: mobile-test-reactnative
description: Add React Native or Expo component, integration, E2E, lifecycle, and native-contract tests using the repository's installed runner and device stack. Use for React Native or Expo behavior; not for Flutter.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  domain: mobile
  keywords: [react native test, expo test, jest, vitest, rntl, detox, maestro, native module, process death]
---

Implement React Native or Expo tests for $ARGUMENTS.

## Preserve the installed harness

Read instructions, package manifest/lockfile, Expo/native configuration, installed React/RN/Expo and runner versions, existing helpers/mocks, navigation/state/storage, CI, runtime/update policy, and production behavior. Before mutation, resolve exact task-owned test/fixture/baseline targets, owning package/team and write authority, plus a reversible diff and device-state recovery/cleanup path; otherwise block execution pending discovery. Use the repository's Jest, Vitest, React Native Testing Library, Detox, Maestro, or other established stack; do not replace it by recipe. Verify APIs from local types/CLI/config or matching official docs. For authorized greenfield work, resolve stable/LTS React Native or Expo, React, runtime, runner and native toolchain releases from configured official sources at execution time, verify their compatibility, and make the generated manifest and lockfile the authoritative installed-stack record; a repository helper may assist but is not required.

Choose the narrowest proving layer:

- unit/component tests for pure logic, semantics, text scaling, states, and interaction;
- integration tests for navigation, persistence, network/offline policy, auth boundaries, and lifecycle wiring;
- simulator/emulator/device E2E for push/deep links, permissions, secure storage, process death/restoration, background behavior, OTA/runtime and native modules;
- JS/native contract tests for method/event schemas, structured errors, cancellation, threading assumptions, and missing-module behavior.

Mock only boundaries required for isolation. “Mock all native modules” can hide registration, schema, permission, restore, or native failures; retain contract/device coverage for critical integrations. Never call real production services, publish updates, send real notifications, or use production accounts/secrets.

## State and flake control

Control clocks, randomness, locale/timezone, connectivity, permissions, backend responses, storage, animations, and app launch state through supported seams. Reset only state owned by the test. Do not reload the entire JS runtime before every test unless isolation requires it, and do not use fixed universal timeouts, device models, pixels, SDK, or Node versions.

Wait for observable semantic conditions rather than sleeps. For animations, use reduced-motion/test configuration or bounded completion signals. Preserve tests that cross native boundaries; a passing JS mock is not proof of a device contract.

Cover cold start, foreground/background, focus/unmount, process death, secure-token partial rotation and restore/key invalidation, deep-link/push validation and duplicates, offline conflict/stale data, text scaling/reduced motion, native error paths, and OTA runtime mismatch when affected.

## Verification and output

Run focused tests and then repository-authoritative affected suites, type/lint/build, and the smallest relevant simulator/emulator/device/build matrix. Include explicit accessibility evidence for semantics/labels/state, text scaling, reduced motion, focus/reading order and relevant assistive-technology behavior rather than inferring it from rendered text. Diagnose flakes and rerun after fixes; bounded repetitions measure stability but are not a substitute for cause analysis. Clean only task-owned sessions and artifacts.

Report behavior/layers covered, fixtures and mocks, installed environment, state and JS-runtime reset strategy (including why any per-test runtime reload is necessary), commands/results, device/native evidence, and residual provider/signing/store/device gaps.
