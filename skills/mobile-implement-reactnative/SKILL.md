---
name: mobile-implement-reactnative
description: Implement React Native or Expo features using the repository's navigation, state, storage, lifecycle, accessibility, native-module, and release-runtime contracts. Use when React Native or Expo-specific behavior dominates; not for Flutter.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  domain: mobile
  keywords: [react native, expo, navigation, secure store, deep link, push, ota, native module, accessibility]
---

Implement the React Native or Expo feature requested in $ARGUMENTS.

## Establish the installed stack

Read instructions, `package.json` and lockfile, Expo/native configuration, routing/state/data boundaries, iOS/Android projects, runtime/update policy, tests, CI, and release channels. Determine managed, prebuild, or bare ownership; installed React Native/Expo/React, architecture and JS engine; minimum OS; and native module compatibility from repository evidence.

Preserve current navigation, state, storage, list, styling, file, and test patterns unless migration is explicitly justified. Verify version-specific APIs using installed types/CLI/config schema or matching official docs. For greenfield work, use `scripts/framework-stack-context.py`; do not hardcode SDK, React Native, React, Node, list, pixel, or performance thresholds.

## Trust and lifecycle invariants

- UI state and model output never authorize access or actions. Server/API boundaries authenticate the session, derive tenant/user scope, authorize resources, validate targets and payloads, and enforce idempotency.
- Validate deep links, universal/app links, notification routes, and navigation params by scheme/origin, route allowlist, typed schema, auth state, resource existence, and environment. Preserve an approved post-login continuation without open redirects.
- Treat push data as untrusted and handle foreground, background, cold start, duplicates, revoked access, denied permissions, and stale resources.
- Use the repository secure-storage abstraction for credentials. Make refresh/rotation concurrency-safe and recoverable across partial writes, app kill, logout, biometric/key invalidation, backup/restore, reinstall, or device migration. SecureStore/Keychain/Keystore availability and restore semantics must be tested or documented, not assumed.
- Define persistence migrations, encryption threat model, deletion, offline conflict policy, stale-data display, and process restoration from product requirements.
- Register and dispose subscriptions, timers, gestures, native listeners, network calls, and animations across focus, blur, background, unmount, and process restart. Respect reduced motion and avoid unbounded animations.
- Preserve dynamic type/text scaling, screen-reader roles/names/state, focus order, contrast, safe areas, orientation, and localization. Do not disable font scaling to protect a fixed layout.

## Native and release boundaries

Treat native modules as versioned contracts with typed input/output, structured errors, permission handling, cancellation, threading, and unavailable-module behavior. Verify both JS and native implementations where affected.

For OTA updates, verify runtime-version compatibility, native module/schema compatibility, rollout channel, asset/data migrations, crash monitoring, and rollback before publication. Before publication, execute the repository/provider-supported rollback exercise against a non-production or otherwise explicitly authorized safe channel: identify the exact current/candidate/rollback runtime and update identities, roll forward, trigger or simulate the abort criterion, roll back, and read back the active update plus restored data/schema compatibility. A rollback artifact or owner without this executable evidence is insufficient. An OTA bundle cannot safely introduce native capabilities absent from the installed binary.

Profile actual devices/build modes before changing memoization, virtualization, image caching, bridge/JSI placement, or animation. Select list/window/batch dimensions and performance budgets from measurements and accessibility behavior, not fixed item counts or pixels.

## Verification and output

Add repository-native component/integration/E2E/native-contract tests. Cover authorization rejection, deep-link/push validation, secure-token partial failure and restore, offline/lifecycle/process-death behavior, text scaling/reduced motion, native failures, and OTA runtime mismatch where affected. When lists, images or performance-sensitive rendering are involved, record the installed component capability and actual-device/profile evidence used to select window/batch dimensions, pixel choices and budgets. Run focused and affected checks plus the smallest relevant simulator/emulator/device and release/profile matrix.

Report stack/runtime evidence, preserved conventions, changes, trust/lifecycle/OTA contracts, migrations/rollback, actual checks/device evidence, and unresolved provider/signing/store/device risks.
