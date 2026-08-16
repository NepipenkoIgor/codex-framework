---
name: mobile-implement-flutter
description: Implement Flutter and Dart features using the repository's routing, state, storage, lifecycle, accessibility, background, and platform-channel contracts. Use when Flutter-specific code or native integration dominates; not for React Native.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  domain: mobile
  keywords: [flutter, dart, routing, state, secure storage, deep link, push, lifecycle, platform channel, accessibility]
---

Implement the Flutter feature requested in $ARGUMENTS.

## Preserve the installed application

Read repository instructions, `pubspec` and lockfile, app entry points, routing/state/data abstractions, platform projects, generated plugin registration, tests, CI, minimum OS targets, and release configuration. Preserve the existing router, state container, file layout, list widget, storage engine, dependency-injection style, and code generation unless the requirement makes a migration necessary.

Before mutation, resolve the exact task-owned Dart files, native iOS/Android files, generated-code boundary, storage records/contracts, tests and configuration targets, their owners, applicable write authority, and recovery for partial or conflicting changes. Do not begin implementation while those mutation targets or ownership remain unresolved.

Verify installed Flutter/Dart/plugin capabilities from the local toolchain, generated APIs, analyzer, or matching official documentation. Treat framework/plugin upgrades separately. For greenfield work, use `scripts/framework-stack-context.py` to resolve stable Flutter and supported production toolchains dynamically; let generated manifests and locks become authority.

## Implementation invariants

- Model loading, empty, content, retryable error, offline/stale, permission-denied, and terminal states required by the feature. Preserve state across rebuilds and define app background/foreground, termination, restoration, and cancellation behavior.
- Validate route and deep-link syntax, origin/host, route name, typed parameters, authorization, object existence, and post-login continuation before navigation. Reject unsupported or stale targets safely.
- Treat push payloads as untrusted hints. Validate sender/environment, type/version, tenant/user scope, route and resource server-side before display or navigation; handle foreground, background, cold-start, duplicate, revoked, and denied-permission cases.
- Store secrets only through the repository's secure-storage boundary. Token rotation must persist the new credential and related metadata atomically or remain recoverable, use concurrency control, and revoke/retire the old token only after the new durable state is confirmed. Handle unavailable/locked storage, restore/reinstall, logout, biometric/key invalidation, and partial failure.
- Choose local database/files/cache from data semantics, encryption threat model, transactions, migration/rollback, backup, and deletion requirements. No storage or directory layout is universal.
- Define background work against installed platform/plugin capabilities and OS quotas. Make it idempotent, bounded, cancellable, and safe under retries, delayed execution, process death, revoked permission, and expired credentials.
- Preserve text scaling, semantics, focus order, contrast, safe areas, orientation, localization, and reduced-motion behavior. Disable or simplify nonessential animation when motion reduction is requested; do not use infinite animation without lifecycle control.
- For platform channels, use explicit versioned method/event contracts, typed validation, structured errors, cancellation/disposal, threading rules, and unavailable-plugin behavior. Test Dart and native sides; never swallow `MissingPluginException` or native failure as success.

Profile before changing rendering, rebuild, image, isolate, or list behavior. Select sliver/list/cache/page sizes from measured workload and memory/frame budgets, not a universal recipe. Confirm installed renderer and capability before Impeller-specific work.

## Verification and output

Add focused unit/widget/integration/native-contract tests following the repository runner. When credentials are in scope, exercise the exact rotation sequence under concurrency and a failure between each state transition: atomically or journaledly persist the new credential plus metadata, recover the partial state, confirm durability, and only then retire the old token. Cover validation, denial, lifecycle/process restoration, duplicate push/deep link, offline/error states, and platform-channel failure where affected. Explicitly render and observe both reduced-motion and enlarged/dynamic-text cases in widget or visible device tests; preserving the settings in implementation without exercising them is insufficient. Verify on the smallest relevant OS/device/build matrix and run affected analyzer/build/test commands.

Report local stack evidence, preserved conventions, trust/lifecycle contracts, changes, migrations/rollback, actual checks/device evidence, and unresolved signing/provider/store/device risks. When push or credentials are in scope, explicitly report push-payload validation across foreground/background/cold-start/duplicate/revoked/denied cases and the atomic, concurrency-safe token-rotation state machine: new credential plus metadata durable first, partial-failure recovery, then old-token retirement.
