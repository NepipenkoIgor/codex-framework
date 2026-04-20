---
name: accessibility-implement
description: Implement accessible components — ARIA live regions, focus management, keyboard navigation, skip links, screen reader testing, and WCAG 2.2 AA compliance patterns
metadata:
  version: 1.3
  argument-hint: "target component/page, WCAG level (A/AA/AAA), issues to fix (contrast/keyboard/ARIA)"
---

Implement accessibility for $ARGUMENTS.


## Tool Integration

- **Type diagnostics** — verify type-safety
- **browser automation**: use browser navigation and snapshot tools to verify focus management, keyboard navigation, and color contrast in a live browser — always navigate first before any interaction

Frameworks in scope:
- React (react-aria, @headlessui/react, Radix UI)
- Angular (CDK a11y module)
- Vue (headless-ui/vue)
- Blazor (native ARIA attributes)

## Focus Management

### Focus Trap
Contain focus within modals, dialogs, drawers:
```typescript
// React — using react-aria
import { FocusScope } from 'react-aria';
<FocusScope contain restoreFocus autoFocus>
  <Dialog>{children}</Dialog>
</FocusScope>
```

### Roving Tabindex
For composite widgets (toolbars, menus, tab lists):
- Container: `tabIndex={0}` on the group
- Items: `tabIndex={-1}` on all, `tabIndex={0}` on active item
- Arrow keys move focus between items
- Home/End jump to first/last item

```typescript
function useRovingTabIndex(items: HTMLElement[]) {
  const [activeIndex, setActiveIndex] = useState(0);
  const onKeyDown = (e: KeyboardEvent) => {
    let next = activeIndex;
    if (e.key === 'ArrowDown' || e.key === 'ArrowRight') next = (activeIndex + 1) % items.length;
    if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') next = (activeIndex - 1 + items.length) % items.length;
    if (e.key === 'Home') next = 0;
    if (e.key === 'End') next = items.length - 1;
    setActiveIndex(next);
    items[next]?.focus();
    e.preventDefault();
  };
  return { activeIndex, onKeyDown };
}
```

### Focus Restoration
When closing a dialog/popover, return focus to the trigger element:
```typescript
const triggerRef = useRef<HTMLButtonElement>(null);
const onClose = () => { setOpen(false); triggerRef.current?.focus(); };
```

## ARIA Live Regions

### Dynamic Content Announcements
```html
<!-- Status messages (non-urgent) -->
<div role="status" aria-live="polite">3 results found</div>

<!-- Error/alert messages (urgent) -->
<div role="alert" aria-live="assertive">Payment failed. Please try again.</div>

<!-- Loading states -->
<div aria-live="polite" aria-busy="true">Loading results...</div>
```

Rules:
- `polite` for non-critical updates (search results, form feedback)
- `assertive` for errors, alerts, time-sensitive info
- The live region element must exist in DOM before content changes
- Never use `aria-live` on elements that update rapidly (typing indicators)

### Toast/Snackbar Announcements
```typescript
// Create a persistent live region, update its content
const announcer = document.getElementById('a11y-announcer');
announcer.textContent = ''; // Clear first
requestAnimationFrame(() => { announcer.textContent = message; });
```

## Keyboard Navigation Patterns

### Skip Navigation
```html
<a href="#main-content" class="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:bg-white focus:px-4 focus:py-2">
  Skip to main content
</a>
<!-- ... header/nav ... -->
<main id="main-content" tabindex="-1">
```

### Common Keyboard Patterns

| Widget | Keys | Behavior |
|--------|------|----------|
| Menu | Arrow keys | Navigate items |
| Menu | Enter/Space | Activate item |
| Menu | Escape | Close, return focus to trigger |
| Tabs | Arrow keys | Switch tabs |
| Tabs | Home/End | First/last tab |
| Dialog | Escape | Close dialog |
| Dialog | Tab | Cycle within focus trap |
| Combobox | Arrow keys | Navigate options |
| Combobox | Enter | Select option |
| Combobox | Escape | Close listbox |
| Accordion | Enter/Space | Toggle panel |
| Tree view | Arrow keys | Navigate nodes |
| Tree view | Left/Right | Collapse/expand |

## Accessible Forms

### Label Association
```html
<!-- Explicit association (preferred) -->
<label for="email">Email address</label>
<input id="email" type="email" aria-required="true" aria-describedby="email-hint email-error" />
<span id="email-hint">We'll never share your email</span>
<span id="email-error" role="alert">Please enter a valid email</span>
```

### Error Announcements
- Use `aria-invalid="true"` on invalid fields
- Use `aria-describedby` pointing to error message element
- Error message element should have `role="alert"` for immediate announcement
- On form submission error: focus the first invalid field

### Required Fields
- Use `aria-required="true"` (not just HTML `required` — some screen readers handle differently)
- Visual indicator (asterisk) with hidden text: `<span aria-hidden="true">*</span>`

## Color & Visual

### Contrast
- Text: 4.5:1 minimum (AA), 7:1 enhanced (AAA)
- Large text (18px+ bold, 24px+): 3:1 minimum
- UI components and focus indicators: 3:1 against adjacent colors
- Use `prefers-contrast: more` media query for high contrast mode

### Reduced Motion
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

```typescript
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
```

## Screen Reader Testing

### Testing Methodology
1. **VoiceOver (macOS):** Cmd+F5 to toggle. Navigate with VO keys (Ctrl+Option + arrows). Test rotor (VO+U).
2. **NVDA (Windows):** Free. Insert key as modifier. Browse mode vs focus mode.
3. **Mobile:** VoiceOver (iOS) or TalkBack (Android). Swipe navigation.

### What to Verify
- [ ] All interactive elements are focusable and operable via keyboard
- [ ] All images have appropriate alt text (or `alt=""` for decorative)
- [ ] Form fields have associated labels announced by screen reader
- [ ] Error messages are announced when they appear
- [ ] Dynamic content changes are announced via live regions
- [ ] Heading hierarchy is logical (h1 → h2 → h3, no skips)
- [ ] Landmarks are present (`<main>`, `<nav>`, `<aside>`, `<header>`, `<footer>`)
- [ ] Modal focus is trapped and restored on close
- [ ] Custom widgets follow WAI-ARIA authoring practices

## Framework-Specific

### React — react-aria
```typescript
import { useButton, useFocusRing, useTextField } from 'react-aria';
// Handles ARIA attributes, keyboard, focus management automatically
const { buttonProps } = useButton({ onPress }, ref);
const { isFocusVisible, focusProps } = useFocusRing();
```

### Blazor
```razor
<button @onclick="OnClick" aria-label="@AriaLabel" aria-expanded="@IsExpanded" aria-controls="panel-1">
  @ButtonText
</button>
<div id="panel-1" role="region" aria-labelledby="heading-1" hidden="@(!IsExpanded)">
  @ChildContent
</div>
```

## Anti-Patterns
- Using `div` or `span` as buttons without `role="button"` and keyboard handler
- `aria-label` that duplicates visible text (redundant announcement)
- Using `tabindex` > 0 (breaks natural tab order)
- Removing focus outlines without providing alternative focus indicator
- Using `aria-hidden="true"` on focusable elements
- Placeholder text as the only label

## Done Criteria

- [ ] All interactive elements keyboard accessible
- [ ] Focus indicators visible on all focusable elements
- [ ] Skip navigation link present and functional
- [ ] ARIA live regions for dynamic content
- [ ] Form errors announced and fields linked to error messages
- [ ] Color contrast meets AA (4.5:1 text, 3:1 UI components)
- [ ] `prefers-reduced-motion` respected
- [ ] Screen reader tested (VoiceOver or NVDA)
- [ ] No ARIA anti-patterns
- [ ] Heading hierarchy is logical
