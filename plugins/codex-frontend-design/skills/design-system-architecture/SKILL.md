---
name: design-system-architecture
description: Design a read-only design-system architecture from product, brand, accessibility, platform, and repository evidence. Use when token, component, theming, governance, or adoption decisions are unresolved; do not use for direct implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.7
  argument-hint: "products and platforms, existing design/code sources, brands/themes, accessibility targets, component scope, adoption constraints"
---

# Design System Architecture

Design `$ARGUMENTS` without changing repository or external state.

## Evidence first

1. Inventory authoritative design sources, existing tokens/components, rendered products and states, brands/themes, target platforms, accessibility/browser policies, build/distribution constraints, and adoption owners.
2. Separate observed reuse and inconsistency from assumptions. A hardcoded value is not automatically wrong; a named utility is not automatically authoritative.
3. Resolve installed framework, runtime, styling, documentation, and token-tool capabilities from manifests, lockfiles, generated types/schema/CLI help, and matching official documentation. For every selected version-sensitive command, API or configuration pattern, record the installed capability source that proves support. Preserve project pins; treat migration as a separate decision. For explicitly authorized greenfield setup only, resolve stable/LTS components from configured official sources, verify cross-stack compatibility, generate manifest/lockfile, and make them authority.
4. Define measurable goals: consistency, accessibility, delivery speed, bundle/runtime cost, cross-brand reach, or migration risk.

## Architecture decisions

- Establish source of truth, ownership, review/versioning, deprecation, release, contribution, and consumer migration contracts before selecting tooling.
- Derive primitive, semantic, and component-token layers only where each layer serves actual theming, platform, or component needs. Components should normally consume semantic or documented component contracts, but exceptions must be explicit and reviewable.
- Derive color, typography, spacing, sizing, elevation, radius, motion, and breakpoint scales from product/brand evidence and target-platform constraints. Do not impose a remembered palette, 4px grid, fixed type scale, atomic taxonomy, or "no arbitrary values" rule without evidence.
- Model components by user interaction and composition contracts, including state ownership, native semantics, keyboard/focus behavior, localization, content limits, responsive behavior, loading/error/empty states, and framework adapters.
- Accessibility targets come from the applicable WCAG criterion and product platform policy. Do not present 44x44 CSS pixels as a universal WCAG AA requirement; target-size criteria have level, exception, and spacing nuances.
- Add a component or abstraction when repeated product need, divergence cost, semantic risk, or platform leverage justifies it. A "used twice" threshold is not architecture evidence.
- Prefer native platform semantics and installed primitives where they meet the contract. ARIA, runtime theming, CSS-in-JS, Tailwind, Storybook, Chromatic, and token compilers are optional capabilities, not defaults.

## Adoption and verification

- Define a representative pilot, compatibility/adoption matrix, token and component contract tests, accessibility/manual checks, visual regression scope, migration order, rollback/deprecation policy, and ownership metrics.
- Include performance, SSR/first-paint theming, package/version compatibility, multi-platform distribution, and consumer failure modes only when relevant.
- Keep volatile package syntax in implementation references; architecture should survive tool replacement.

## Output

- Evidence and unresolved assumptions
- Goals, scope, non-goals, ownership, and source of truth
- Token/component/theme/distribution contracts with alternatives and tradeoffs
- Accessibility and compatibility requirements
- Phased adoption, verification, migration, and rollback plan
- Open decisions and residual risk
