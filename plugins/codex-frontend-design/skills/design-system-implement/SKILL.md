---
name: design-system-implement
description: Implement or migrate design tokens, accessible primitives, component variants, theming, documentation, and adoption tooling in an existing frontend stack. Use when reusable design-system code is the deliverable; do not use for architecture-only decisions or one-off page styling.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.1
  argument-hint: "approved contracts, installed framework/tooling, token/component scope, consumer migration and rollback"
---

# Design System Implementation

Read [the full framework/component guide](references/full-guide.md) only for the selected installed stack and primitive family.

## Establish the implementation contract

1. Read instructions, manifests/lockfiles, authoritative token/design sources, existing primitives and consumers, generated outputs, build/distribution config, and behavior/accessibility/visual tests.
2. Generate stack context. Verify version-sensitive APIs against installed types/schema/CLI help and matching official documentation; preserve pins unless migration is explicitly authorized.
3. Resolve token/component source of truth, public API, theme and SSR/first-paint behavior, package/version compatibility, deprecation policy, exact pilot consumers, mutation owner and write authority/permissions before editing; define a reversible token/component/consumer rollback.
4. Prefer native HTML semantics and behavior. Add ARIA only where native semantics cannot express the required contract, then implement its keyboard/focus/state behavior.

## Implementation and migration

- Implement the smallest approved token slice and representative primitive required by a real consumer; do not generate arbitrary palettes, scales, variants, or catalogs.
- Preserve accessible name/role/state, focus, keyboard, disabled/loading/error, high contrast, forced colors, reduced motion, RTL, localization, zoom/text scaling, and responsive behavior relevant to the component.
- Do not introduce a second styling/runtime/token system without an explicit coexistence and removal plan.
- Keep volatile framework/tool syntax isolated from stable consumer contracts. Do not force framework, language, or package upgrades as incidental adoption.
- Migrate a representative consumer end-to-end, including fallback/rollback and compatibility with unmigrated consumers. Generated output and source tokens must have a drift check.

## Verification and output

Run focused behavior, accessibility, theme, type, visual, build/package, SSR/first-paint, and consumer integration checks that the repository supports. Measure relevant bundle/runtime/style impact and verify native interaction in a browser when the primitive changes behavior.

Report implemented contracts and authoritative sources, installed capability, migrated consumers, compatibility/deprecation/rollback behavior, executed checks and evidence, remaining adoption risk, and unresolved external boundaries such as design-tool sources, package registries, hosted visual services or browsers that were not exercised.
