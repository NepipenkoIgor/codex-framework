---
name: responsive-design
description: Implement responsive page and component layouts across viewport, container, zoom, text spacing, writing direction, and input modes. Use when adaptive layout behavior is primary; do not use for general styling or a broad accessibility audit.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "content constraints, embedding containers, browser/device matrix, zoom/reflow target, framework and SSR behavior"
---

# Responsive Design

Derive stack context from manifests/lockfiles, installed types/configuration, actual DOM/content, containing blocks, design tokens, framework adapter, CSS processor, Tailwind/build plugins, content detection, browser targets, rendering mode, localization, SSR/hydration and visual/browser tests as one compatibility unit. A repository helper may summarize this evidence but is not required. Existing manifests and lockfiles are authority; for authorized greenfield work resolve stable/LTS releases from configured official sources at execution time, verify compatibility, and make the generated manifest and lockfile authoritative. Verify container-query, viewport-unit, image, and framework APIs against current official docs and installed capability.

Load at most one relevant deep dive. Resolve the choice explicitly before implementation and report either the single selected reference or `none` with the task evidence showing that the main workflow is sufficient. Never conditionally name a reference without resolving whether it was loaded, and do not force an unrelated deep dive merely to satisfy routing. Do not load Tailwind detail merely because Tailwind is installed; select it only when installed utility syntax itself is the unresolved subject.

- responsive image selection or art direction: [responsive-images.md](references/responsive-images.md)
- adaptive navigation and disclosure: [responsive-navigation.md](references/responsive-navigation.md)
- tabular reflow: [responsive-tables.md](references/responsive-tables.md)
- installed Tailwind utility syntax: [tailwind-responsive.md](references/tailwind-responsive.md)

## Layout Contract

- Start from content and actual container constraints, not remembered device widths. A component embedded in a sidebar, split pane, translated page, or zoomed viewport may need container queries; page chrome and browser-wide behavior may need media queries.
- Prefer source order and one stable semantic DOM that reflows. Duplicating desktop/mobile trees risks duplicate IDs, focus targets, announcements, state, and hydration.
- Use flexible tracks with explicit minimum-content behavior (`min-width: 0`, wrapping, overflow policy). Preserve long unbroken strings, enlarged text, localization, RTL/vertical writing modes where required, safe areas, virtual keyboards, and user font settings.
- Do not disable pinch zoom. Verify WCAG 1.4.10 reflow at the normative equivalent viewport and 1.4.4 text resize, plus repository-supported higher zoom and text-spacing cases. Horizontal scrolling may be appropriate for intrinsically two-dimensional content, but not for the page as a whole.
- For WCAG 2.2 AA, SC 2.5.8 requires a pointer target that can contain a 24 by 24 CSS-pixel square, or a valid spacing, equivalent, inline, user-agent-control, or essential exception. Document any exception. The 44 by 44 CSS-pixel target is SC 2.5.5 Enhanced (AAA), though it can be a product preference.
- SSR must not guess a breakpoint and emit materially different markup unless the server has a reliable, cache-safe input and hydration contract. Prefer CSS for presentation; for JS-only behavior use capability/media observation after hydration with a stable initial state and cleanup.

## Workflow

1. Inventory content extremes, component containers, viewport/input/browser matrix, SSR/hydration, zoom/text-spacing, localization, persistent/fixed UI, images, tables, and existing breakpoints.
   If an unsafe responsive hotfix is already deployed, first resolve its exact affected flows, deployment target and rollback authority, define a measurable rollback trigger, and roll it back or isolate it before implementing the replacement.
2. Define invariants and failure policy: what may wrap, stack, scroll, collapse, truncate, move, or remain visible. Preserve task order and access to functionality.
3. Implement the smallest set of fluid rules. Add breakpoints only where measured content constraints fail; name repository tokens by intent rather than device folklore.
4. Use container queries only after establishing the query container and fallback. Avoid style/layout containment that clips required overflow or changes sizing unexpectedly.
5. Verify real content and interactions, not a list of canonical widths. Inspect computed layout and accessibility tree before adding more variants.

## Verification

- Narrow/wide viewport and each distinct embedding container; intermediate widths around every content-driven breakpoint.
- Browser zoom/reflow, text-only enlargement, WCAG text-spacing overrides, long translations, RTL, long URLs/numbers, dynamic errors, validation, virtual keyboard, and safe areas.
- Keyboard, touch, mouse, coarse/fine pointer, orientation, focus visibility and order; target-size measurements with documented exceptions.
- SSR response versus hydrated DOM, resize/orientation changes, no-JS behavior, slow hydration, and browser capability fallback.
- For every affected critical journey such as checkout, prove the complete user-visible success path still reaches its authoritative persisted/provider outcome at representative responsive states; visibility and interaction checks alone are insufficient.
- Visual/browser tests plus DOM/accessibility assertions and affected build/tests. A screenshot at preset device widths is not sufficient proof.

## Output Contract

- Content/container and breakpoint decisions
- Reflow, zoom, target-size, SSR/hydration, and overflow contracts
- Exactly one resolved reference-selection result (the selected path, or `none` with task evidence) and installed capability evidence
- Test matrix and observed results
- Residual browser, localization, content, and design risks

Normative sources: [WCAG 2.2](https://www.w3.org/TR/WCAG22/), [SC 2.5.8 understanding](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum), and [CSS Containment](https://www.w3.org/TR/css-contain-3/).
