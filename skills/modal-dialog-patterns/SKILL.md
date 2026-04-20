---
name: modal-dialog-patterns
description: Implement modal, dialog, drawer, and overlay patterns including focus trapping, keyboard handling, stacking, animations, and accessible dismiss patterns
metadata:
  version: 1.4
  argument-hint: "modal type (confirmation/form/drawer/sheet), trigger context, framework, animation needed"
---

Implement $ARGUMENTS.

## Documentation

> Use **available docs lookup tools or official docs** when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Overlay Type Selection

| Type | Use when | Anatomy |
|------|----------|---------|
| Modal / Dialog | Focused task requiring user input or confirmation | Centered, backdrop, max-w-lg |
| Drawer / Sheet | Supplementary content, filters, settings, navigation | Side-attached, slides in |
| Bottom Sheet | Mobile-first actions, confirmations, pickers | Anchored to bottom, swipeable |
| Popover | Contextual info, mini-actions | Anchored to trigger, no backdrop |
| Command Palette | Search + action list, keyboard-driven | Centered, search input |
| Alert Dialog | Destructive confirmation | Centered, non-dismissible by outside click |

## Accessibility (Non-Negotiable)

### Focus Trap

When an overlay is open, Tab/Shift+Tab must cycle only within the overlay. Focus must not escape to background content.

> Use available docs lookup tools or official docs to fetch current `react-aria` FocusScope, Radix Dialog, or Angular CDK Dialog docs for implementation syntax.

Rules:
- Auto-focus first focusable element on mount
- Return focus to the trigger element on close
- `role="dialog"` + `aria-modal="true"` for standard modals
- `role="alertdialog"` for destructive confirmations
- `aria-labelledby` pointing to dialog title; `aria-describedby` when description present

### Keyboard Handling

| Key | Action |
|-----|--------|
| Escape | Close (except alert dialogs during destructive flows) |
| Tab / Shift+Tab | Cycle within focus trap |
| Enter | Activate button / submit form |
| Space | Activate button |

## Stacking and Layering

```css
:root {
  --z-overlay: 200;
  --z-modal: 300;
  --z-popover: 400;
  --z-toast: 500;
}
```

Nested modals: prefer replacing content within the same modal. When unavoidable, use a stack manager — only the topmost modal responds to Escape and outside click.

## Animations

```css
@keyframes modalIn { from { opacity: 0; transform: scale(0.95) translateY(8px); } to { opacity: 1; transform: scale(1) translateY(0); } }
@keyframes slideInRight { from { transform: translateX(100%); } to { transform: translateX(0); } }
@keyframes slideUp { from { transform: translateY(100%); } to { transform: translateY(0); } }

@media (prefers-reduced-motion: reduce) {
  .modal-enter, .modal-exit, .drawer-enter, .drawer-exit,
  .sheet-enter, .sheet-exit, .backdrop-enter, .backdrop-exit {
    animation-duration: 0.01ms !important;
  }
}
```

Rules:
- Enter slightly longer than exit (200ms enter, 150ms exit)
- Ease-out entering, ease-in exiting
- Animate only `transform` and `opacity` for GPU compositing
- Always respect `prefers-reduced-motion`

## Dismissal Patterns

- **Outside click**: use `mousedown` (fires before focus changes), not `click`
- **ESC key**: listen on `document`, clean up on unmount
- **Close button**: always include visible X in top-right; `aria-label="Close"` for icon-only
- **Swipe**: bottom sheets and drawers support swipe-to-dismiss on touch devices

## Unsaved Changes Guard

Track form dirty state. If dirty when closing, show a nested `role="alertdialog"` confirmation. Never silently discard user input.

## Scroll Locking

Prevent background scroll when overlay is open. iOS Safari requires `position: fixed` + saved `scrollY` offset approach — `overflow: hidden` on body alone is insufficient.

## Mobile Responsiveness

- Modals → full-screen or bottom sheet on mobile (`max-width: 639px`)
- Drawers → full-width on mobile
- Touch targets: minimum 44x44px
- Swipe-to-dismiss on bottom sheets and drawers

## Framework Integration

### React — Radix Dialog (recommended)

> Use available docs lookup tools or official docs to fetch current `@radix-ui/react-dialog` docs for implementation syntax.

Radix provides focus trap, return focus, Escape handling, outside click, portal rendering, and ARIA attributes automatically. Style with Tailwind using `data-[state=open]:` variants.

### React — Headless UI

Use `<Dialog>` + `<Transition>` with `enter`/`leave` props. Same accessibility primitives as Radix.

### Angular — CDK Dialog

`inject(Dialog).open(Component, { autoFocus: 'first-tabbable', restoreFocus: true })`. Use `MatDialogRef` / `MAT_DIALOG_DATA` for Material Dialog.

> Use available docs lookup tools or official docs to fetch current `@angular/cdk/dialog` docs.

## Performance

- Conditional rendering (`{isOpen && <Modal>}`) defers mount until open
- Use `React.lazy()` / dynamic import for heavy modal content
- Always render via portal (document root) to avoid z-index stacking context issues
- Keep open/close state in the closest parent that needs it

## Anti-Patterns

- No focus trap, no return focus, no Escape key — baseline accessibility failures
- No scroll lock — users scroll behind the modal
- Dismissing alert dialogs on outside click
- Arbitrary z-index values
- Full-screen modal on desktop for a simple confirmation
- No loading state on confirm button — duplicate submissions

## Implementation Workflow

1. Choose overlay type (modal / drawer / bottom sheet / command palette)
2. Choose library: Radix or Headless UI (React), CDK Dialog (Angular), or custom
3. Implement: focus trap → return focus → Escape → outside click → scroll lock (iOS-safe)
4. Add enter/exit animations with `prefers-reduced-motion` fallback
5. Add mobile responsiveness (bottom sheet or full-screen on small viewports)
6. Add unsaved changes guard for form modals
7. Verify: ARIA roles, keyboard navigation, screen reader announcements

## Done Criteria

- Focus trapped within overlay when open; returns to trigger on close
- Escape closes overlay (except alert dialogs)
- Outside click closes overlay (except alert dialogs)
- Enter/exit animations with reduced-motion fallback
- Background scroll locked (including iOS)
- Modal adapts to mobile: bottom sheet or full-screen on small viewports
- Form modals guard against accidental close with unsaved changes
- Close button has `aria-label="Close"`
- Dialog has `role="dialog"` or `role="alertdialog"` with `aria-modal="true"` and `aria-labelledby`
- Loading state on confirm button prevents duplicate submissions
