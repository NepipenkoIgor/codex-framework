---
name: ui-consistency-audit
description: Audit a defined UI sample against the repository's authoritative design tokens, primitives, product patterns, and rendered states. Use for a read-only consistency findings report; do not use when remediation or design-system architecture is the primary deliverable.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.3
  argument-hint: "sampled routes/components/states, authoritative design sources, themes/viewports/locales"
---

# UI Consistency Audit

Audit `$ARGUMENTS` read-only. Do not edit code, designs, tokens, or external state.

## Establish authority and sample

1. Record exact routes, components, variants, states, themes, viewports, locales, and auth roles sampled.
2. Identify authority in order of repository/product evidence: approved design source or specification, token source and generated outputs, shared primitives and documented variants, then repeated rendered product patterns. Do not invent a token scale or declare the most common value correct.
3. Inspect source plus rendered states. Static search is candidate discovery, not proof of a visual or interaction defect.
4. Mark inaccessible/authenticated/browser states untested rather than extrapolating counts or site-wide conclusions.

## Review dimensions

- color/contrast usage, typography, spacing, sizing, alignment, borders, elevation, iconography, motion, responsive behavior, theming, localization, and content density;
- component identity and variant/state contracts across default, hover, focus, active, selected, disabled, loading, error, empty, and success states where applicable;
- native semantics, keyboard/focus behavior, accessible names, and design-system accessibility contracts, routing broad WCAG conformance work to `accessibility-audit`;
- token/source drift, generated-output drift, one-off exceptions, duplicated primitives, and platform-specific requirements.

An arbitrary value may be a legitimate documented exception and must not be reported as drift solely because it differs from a repeated value. A disabled control must be judged by why it is unavailable and whether an understandable alternative exists; `pointer-events: none` is not a universal disabled-state requirement and can remove useful pointer semantics. Keyboard focus must remain perceivable, while `:focus-visible` may intentionally differ by input modality and avoid a mouse-focus ring. Make these exception, disabled-alternative and modality checks explicit in the audit plan and findings; listing states alone is insufficient.

## Evidence safety

Screenshots, DOM/accessibility trees, text content, network logs, and design files can contain PII, secrets, or confidential product data. Use least-privileged read-only access, minimize capture, redact evidence, and do not retain or publish sensitive artifacts without authorization.

## Output

For each confirmed finding include severity, exact source and rendered state, authoritative expected contract, observed divergence, user/product impact, evidence method, and remediation direction. Separate confirmed defects, candidates needing product/design decisions, intentional exceptions, and coverage gaps.

Do not fabricate consistency scores, counts, token names, or pixel recommendations. Report only measured counts within the declared sample, with search method and exclusions. End with prioritized themes, positive patterns evidenced in the sample, and residual untested scope.
