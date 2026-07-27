---
name: mobile-architecture
description: Design mobile module, navigation, state, data, offline, native boundary, build-flavor, and release architecture before feature implementation. Use when cross-cutting React Native, Expo, or Flutter decisions are unresolved; do not use to implement an already-designed feature, debug a concrete defect, or configure store deployment alone.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 1.0
  argument-hint: "platforms, product modules, offline/data/native constraints"
---

## Workflow

1. Inspect the installed framework/SDK, platforms, navigation, state/data layers, native modules, offline behavior, build flavors, deep links, auth, tests, CI, and release channels.
2. Derive module ownership, navigation/deep-link state, server/client source of truth, cache/offline/conflict behavior, sensitive storage, native boundaries, and platform divergence from product constraints.
3. Compare options against repository conventions, team ownership, runtime performance, accessibility, migration cost, OTA/native compatibility, and failure recovery; record an ADR.
4. Define interfaces and a minimal vertical slice. Preserve installed pins; treat framework or new-architecture adoption as a separate migration.
5. Verify cold start, deep link, offline/reconnect, process death, auth expiry, background/foreground, platform differences, accessibility, build flavor, and rollback assumptions.

## Output

Report installed stack evidence, constraints, selected architecture and alternatives, module/data/navigation/native boundaries, migration sequence, executable validation, owners, and residual platform risks. Route any later accepted platform-specific implementation to `mobile-implement`; this design skill does not perform it.
