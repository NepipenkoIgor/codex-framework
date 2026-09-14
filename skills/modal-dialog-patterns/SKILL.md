---
name: modal-dialog-patterns
description: Implement modal dialogs, nonmodal dialogs, drawers, sheets, and alert dialogs with correct focus, dismissal, layering, and mutation semantics. Use when overlay interaction is primary; do not use for a broad accessibility retrofit or unrelated frontend refactor.
metadata:
  owner: codex-framework
  reviewed: "2026-09-14"
  version: 2.1
  argument-hint: "interaction type, trigger/focus context, dismissal policy, installed framework primitive, mutation consequence"
---

# Modal and Dialog Patterns

Derive stack context from repository manifests and lockfiles, installed types/configuration, browser targets, and matching official documentation, then inspect the installed framework/design-system primitive, portal/layer manager, form/mutation contract, and accessibility tests. The repository helper may summarize this evidence when available, but no particular helper command is required. For authorized greenfield work, resolve stable/LTS releases from configured official sources at execution time, verify cross-stack compatibility, and make the generated manifest and lockfile authoritative. Prefer a maintained native/framework primitive that already implements the required semantics, but verify its actual capability; do not replace it or upgrade packages incidentally.

## Choose the Interaction

- A modal dialog makes content outside inert and traps the user's interaction until closed. Use it only when interruption is necessary.
- A nonmodal dialog, popover, disclosure, inline region, or separate page may be better when users must compare or interact with background content. Do not add `aria-modal="true"` to a visually floating but interactive-background surface.
- Use `alertdialog` only for urgent decisions that require immediate attention, not every destructive action. The action consequence determines safe dismissal and initial focus.

## Focus and Dismissal Contract

1. Capture the logical invoker. On open, move focus according to content and risk: often a heading/static introduction for complex content, the least destructive action for irreversible confirmation, or the first task field when appropriate. Never universally focus the first focusable element.
2. For modal content, keep Tab navigation inside and make the rest of the document inert using the verified primitive. For nonmodal content, preserve an understandable route between trigger, dialog, and page.
3. On close, restore focus to the invoker if it still exists and is meaningful; otherwise choose the next logical workflow target. Handle route changes, deleted rows, nested overlays, and virtualized triggers.
4. Escape and outside interaction are product/risk decisions. Provide an explicit accessible close route for ordinary dialogs. Do not dismiss on pointer-down in a way that loses selection, commits a drag, or discards input. Block dismissal only when interruption would corrupt an in-flight state, and explain how the user can recover.
5. Use the native `<dialog>` `showModal()`/`close()` or a maintained framework primitive only when supported behavior, cancellation events, focus, inertness, portal/layering, and browser targets match the contract. Avoid hand-rolled global key listeners when the primitive owns them.

## Mutations and Unsaved State

- A disabled or loading button is not duplicate protection. Before consequential confirmation or retry, bind the exact authenticated actor, tenant, target resource/version and permission at the server boundary. Give it a stable operation identity and server-side idempotency/authorization; handle timeout-after-commit and retry.
- Preserve input on validation, network, authorization, and conflict failures. For unsaved changes, prefer preventing accidental loss in the current dialog; if a nested confirmation is necessary, the layer manager must make only the top dialog interactive and restore focus correctly.
- Destructive copy names the object and consequence. Never infer authorization from the dialog having opened.

## Presentation

- Use the repository's layer tokens and scroll-lock owner; compose with existing popovers/toasts instead of inventing arbitrary z-index constants.
- Keep content usable at zoom, small viewports, virtual keyboard, and long translations. Respect reduced-motion preferences; animation must not delay focus or leave invisible interactive content.
- Do not force every mobile dialog into a sheet or every drawer into a modal. Semantics follow interaction, not shape.

## Verification

- Keyboard and screen-reader behavior for open, initial focus, Tab/Shift+Tab, Escape policy, explicit close, validation error, nested layer, and focus return after invoker removal.
- Background inertness for modal and continued accessibility for nonmodal; accessible name/description; scroll/zoom/virtual keyboard; reduced motion.
- Pointer outside/drag/selection, route change, rapid open-close, concurrent triggers, and portal/layer cleanup.
- Destructive submit under double activation, timeout after server commit, duplicate retry, stale authorization, conflict, and partial failure; prove persisted outcome.
- Browser tests with the actual primitive plus focused unit/integration checks. Report any primitive/browser limitation.

## Output Contract

- Applicable WAI-ARIA/APG and HTML semantic requirements and their source; distinguish this basis from installed primitive APIs and unverified browser support
- Interaction and dismissal semantics
- Focus/layer/scroll ownership
- Mutation idempotency and unsaved-state behavior
- Installed primitive capability evidence
- Verification results and residual assistive-technology/browser risks

Stable interaction semantics come from the [WAI-ARIA APG Modal Dialog Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/) and the [WHATWG dialog element](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-dialog-element); volatile framework callbacks remain behind the installed primitive boundary.
