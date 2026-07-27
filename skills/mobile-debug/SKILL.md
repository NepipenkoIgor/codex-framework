---
name: mobile-debug
description: Reproduce, localize, and fix concrete Flutter, React Native, Expo, iOS, or Android failures using repository and device evidence. Use for a reported crash, build, navigation, lifecycle, rendering, performance, or native-integration defect; not for greenfield work or review-only requests.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "symptom, affected build/platform/device, reproduction, expected behavior, recent change"
---

Debug $ARGUMENTS.

## Establish evidence

Read repository instructions, manifests and lockfiles, native project files, build configuration, tests, and recent relevant changes. Before changing project files, resolve exact task-owned targets, owning package/team and write authority/permissions; retain a reversible-patch and rollback boundary. Record the installed Flutter/Dart or React Native/Expo/React versions, Xcode/SDK/CocoaPods and Gradle/AGP/Kotlin/JDK/Android SDK compatibility, build type, architecture/renderer, OS, device, and distribution channel from actual evidence.

Preserve installed pins. Verify commands and version-gated behavior from installed CLI help, generated configuration/types, or matching official documentation. For a new toolchain only, use `scripts/framework-stack-context.py`; an incident is not authority to upgrade dependencies.

Reproduce the smallest failing path and capture the first causal error, symbolicated native/JS/Dart stack, logs, network/storage/lifecycle state, and a non-failing comparison where available. Separate app code, native integration, dependency/toolchain, provider/backend, and device/OS hypotheses. Falsify each with a focused observation.

## Safe diagnosis

- Do not begin with broad Watchman deletion, Metro/Flutter cache resets, DerivedData removal, Pod deintegration/update, Gradle clean/refresh, dependency forcing, SDK upgrades, or reinstalling the app. Those destroy evidence or change the environment. Use the narrowest reversible action only after evidence implicates that layer.
- Never prescribe a fixed JDK, SDK, deployment target, device matrix, CLI keybinding, or native flag without reading the project compatibility contract.
- Treat simulator and physical-device capability as discovered facts. Push, biometrics, background execution, graphics, networking, and store behavior vary by OS/toolchain and may be simulatable.
- Clean up only processes, devices, logs, or temporary artifacts started by this task; retain exact ownership identifiers.
- Do not weaken signing, transport security, certificate checks, permissions, R8/ProGuard, or production safeguards to make a symptom disappear.

For Flutter rendering issues, determine whether the installed build actually uses Impeller or another backend and whether the relevant profiling/capture capability exists. Do not infer default renderer behavior from a remembered Flutter release. For React Native, determine architecture, JS engine, managed/bare/prebuild boundaries, and native module compatibility from the project.

## Fix and verify

Before mutation, define a reversible patch/config rollback and any persisted-data, OTA or store-build recovery needed if the fix regresses. Then apply the smallest root-cause fix. Preserve navigation and deep-link contracts, persisted data and secure credentials, app lifecycle/process restoration, accessibility and reduced motion, offline behavior, native channel/module error semantics, and OTA/runtime compatibility.

Add a regression check at the lowest layer that reproduces the defect. Then run repository-authoritative focused and affected checks. Where the bug depends on native/runtime behavior, verify the relevant simulator/emulator or physical-device path, background/foreground or process-death transition, release/profile configuration, and caller-visible result. Rerun after any failed check.

Report reproduction, evidence and localized cause, changed files, installed stack/capability evidence, checks and device matrix actually run, cleanup performed, and unverified external/device boundaries. A successful build or cache clear is not proof of the user-visible fix.
