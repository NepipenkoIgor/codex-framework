---
name: mobile-review
description: Review Flutter, React Native, Expo, iOS, or Android changes for correctness, security, lifecycle, accessibility, performance, and platform contracts. Use when findings and risk assessment are requested; do not implement fixes.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  argument-hint: "diff/files, affected framework/platform/builds, expected behavior, available test evidence"
---

Review $ARGUMENTS.

## Ground the review

Read instructions, diff and callers, manifests/lockfiles, native configuration, routing/state/storage/API contracts, tests, and release/runtime policy. Establish the installed framework/toolchain and affected platforms from evidence. Preserve existing pins; for an authorized greenfield choice, resolve stable/LTS versions with the framework stack-context command and matching official compatibility sources, then treat the generated manifest and lockfile as the authoritative version contract. Verify version-sensitive claims against local types/configuration or matching official documentation; do not recommend latest patterns that require an unrequested migration.

Trace changed execution paths in risk order: first establish the affected caller-visible/native path and authority/data/lifecycle invariants, then falsify the highest-impact path, and only then run dependent static, build, device and lifecycle checks whose prerequisites are supported by earlier evidence. Report only actionable defects with severity, concrete evidence, file/line, affected behavior, and a reproduction or missing executable check. Do not treat stylistic preference, lack of memoization, unpinned transitive packages, a root/jailbreak heuristic, or use of an unfashionable library as a defect without a demonstrated contract or risk.

## Review boundaries

- Security: server-side auth/tenant enforcement, validated deep links and push payloads, secure credential rotation/logout/restore, secrets/PII, transport/signing, native and OTA runtime compatibility. Device root detection is bypassable defense-in-depth, not proof of trust.
- Data: storage schema migration, atomicity, concurrency, deletion/retention, backup/restore, offline conflicts, stale data, and process death. “Encrypted storage” does not make all data or backups secure; “offline-first” does not define conflict resolution or durability.
- Lifecycle: foreground/background, focus/unmount, cancellation, listeners/timers, cold start, restoration, permissions, duplicate events, background quotas, and native failure paths.
- UX/accessibility: loading/error/empty/offline states, safe areas, keyboard, orientation, localization, text scaling, screen readers, focus, contrast, touch targets, and reduced motion.
- Performance: require profiling or a clear complexity/resource regression. Memoization, list replacement, cache sizing, image dimensions, and isolate/native offload need workload evidence.
- Platform contracts: framework/native channel or module types/errors/threading, min OS/build modes, signing, store/distribution, and OTA/native/schema compatibility.

Check tests at the correct layer, including process death/restoration, native contracts and device/build paths when unit mocks cannot prove behavior. Do not require every possible platform test; identify the smallest missing check that would falsify the risky claim.

## Output

List findings highest severity first. If none are substantiated, say so and name residual untested boundaries. For every planned test, static check, build and visible lifecycle interaction, state the expected acceptance evidence before execution and then distinguish actual result from unavailable evidence. Summarize installed version evidence and checks reviewed; do not claim code is secure, performant, encrypted, offline-safe, or cross-platform solely from configuration or passing unit tests.
