---
name: accessibility-implement
description: Implement scoped WCAG 2.2 accessibility repairs in components and flows using native semantics, keyboard/focus behavior, forms, announcements, and verified assistive-technology outcomes. Use for requested repository changes; do not use for audit-only work.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "affected flow, target WCAG level, user impact, browsers and assistive technologies, existing primitives"
---

# Accessibility Implementation

Generate stack context with `python3 scripts/framework-stack-context.py project <path>` and inspect the rendered UI, semantic/accessibility tree, installed primitives, existing browser/AT support matrix, design tokens, client and server validation/mutation behavior, motion lifecycle implementation, and tests. Explicitly report the relevant inspected evidence before choosing a repair. Existing pins are authority; verify framework-specific APIs against installed types and official docs. Scope conformance claims to the pages/states actually tested.

## Invariants

- Use the correct native HTML element and browser behavior first. Add ARIA only when semantics or state are missing; ARIA does not add keyboard behavior, validation, focus, or authorization.
- For forms, use native labels, `required`, suitable types/autocomplete and the Constraint Validation API when the product contract permits browser validation. If custom validation replaces or supplements it, preserve programmatic name/description, invalid state, error association, focus/summary behavior and server-authoritative validation. Do not add `aria-required` or `role="alert"` mechanically when native semantics already communicate the state.
- Heading ranks represent document/section hierarchy, not font size. Avoid introducing skipped ranks into a subsection, but do not enforce a blanket adjacent-level rule: returning from a deeper subsection to a higher-rank sibling is correct, and reusable fixed regions need a consistent contextual hierarchy.
- Live regions are scarce interruption channels. Announce only changes users cannot otherwise perceive and need to act on; choose status/alert semantics by urgency, keep the region stable, deduplicate messages, and avoid announcing every keystroke, loading tick, toast, or simultaneously focused error.
- Accessibility output is a user-visible disclosure surface. Never place payment details, credentials, tokens, private provider responses, or other sensitive data in live regions, accessible names/descriptions, validation messages, DOM attributes, logs, screenshots, or retained assistive-technology evidence; expose only the minimum safe action and correlation boundary.
- Reduced motion must preserve state transitions and lifecycle completion. Replace or suppress nonessential movement while ensuring exit cleanup, focus restoration, callbacks, hidden/inert state and completion events still occur. Never use a global near-zero-duration hack as the only policy.
- Distinguish modal dialogs, nonmodal dialogs, alert dialogs, disclosures, popovers and menus by interaction semantics. Visual overlay shape does not justify `aria-modal`, focus trapping or menu keyboard behavior.

## Workflow

1. Reproduce the affected user flow with keyboard and accessibility-tree inspection; identify violated normative criterion, user impact, states and exact ownership.
2. Prefer repairing the shared native/design-system primitive when the defect is shared and scope permits; otherwise make the smallest local fix without duplicating focus/live-region managers.
3. Define keyboard, focus, naming, state, validation, announcement, motion and error behavior before code. Preserve authorization and mutation correctness at the server boundary.
4. For a production consequential flow, resolve the exact deployment target, change authority, ownership, and a tested rollback or recovery path before mutation.
5. Implement with existing tokens and primitives. Do not change visual order independently of DOM/focus order without a verified reading sequence.
6. Test automated rules plus manual keyboard, zoom/reflow and representative screen-reader behavior. Automation cannot certify conformance.

## Verification

- Semantic/accessibility tree, accessible names/descriptions/states, landmarks and meaningful heading hierarchy across loading, empty, error, disabled and success states.
- Exercise representative assistive-technology heading-navigation commands through the changed page states and verify announced level/name and navigation order; outline or accessibility-tree inspection alone is not heading-navigation evidence.
- Complete keyboard flow, focus visibility/not-obscured, modal/nonmodal behavior, removed trigger, route change and no keyboard trap.
- Native and custom constraint validation, client bypass, server errors, error summary/focus and no duplicate announcements.
- Reduced-motion preference during enter/exit, interrupted transition and unmount; high contrast/forced colors, text spacing, zoom/reflow and target-size requirements.
- Use the exact representative browser/screen-reader names from the inspected repository support matrix, or record the missing policy as a blocker requiring an owner; run focused automated checks and affected repository tests. Report every untested AT/browser combination.
- For payment or other consequential mutations, bypass client controls, exercise server failure and recalculation races, and prove the correct persisted outcome plus provider/server reconciliation; accessible announcements or UI success are not mutation evidence.

## Output Contract

- User impact and normative criteria
- Semantic, focus, validation, announcement, motion and dialog decisions
- Exact changed primitives/file paths and test evidence
- Scope of the conformance claim
- Untested assistive-technology/browser combinations and residual product risks

Official foundations: [WCAG 2.2](https://www.w3.org/TR/WCAG22/), [ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/), [HTML forms](https://html.spec.whatwg.org/multipage/forms.html), and [WAI headings](https://www.w3.org/WAI/tutorials/page-structure/headings/).
