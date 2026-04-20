---
name: dark-mode
description: Implement dark mode and theme switching using CSS custom properties, Tailwind dark mode, system preference detection, and persistent theme storage
metadata:
  version: 2.4
  argument-hint: "UI framework (React/Vue/Angular), styling system (Tailwind/CSS-in-JS/styled-components), persistence method (localStorage/system preference), component scope"
---

Implement $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

## Implementation Strategy Selection

Choose the approach that fits the project:

| Strategy | How it works | Best for |
|----------|-------------|----------|
| CSS custom properties | Token variables on `:root` / `[data-theme]` | Any framework, full control, multi-theme |
| Tailwind `dark:` class | `darkMode: 'class'` in config, `dark:` prefix | Tailwind projects, two themes only |
| Tailwind + CSS variables | Tailwind consuming `var(--color-*)` tokens | Tailwind + design system, multi-theme |
| `data-theme` attribute | `[data-theme="dark"]` selectors | Multi-theme (light, dark, high-contrast) |
| `prefers-color-scheme` media | No JS needed, OS-controlled | Simple sites, no user toggle |

Decision guide:
- Two themes (light/dark) with Tailwind -> Tailwind `dark:` class strategy
- Multi-theme or design system -> CSS custom properties with `data-theme` attribute
- Need SSR without hydration mismatch -> cookie-based theme with server detection
- Simple marketing site -> `prefers-color-scheme` media query only

## CSS Custom Properties Token System

### Token Architecture

Layer tokens from primitive to semantic: define raw palette values as primitive tokens (`--gray-900`, `--blue-600`), then reference them in semantic tokens scoped to `[data-theme]`.

```css
/* Semantic tokens -- light theme (default) */
:root, [data-theme="light"] {
  --color-bg: #ffffff;
  --color-surface: #f9fafb;
  --color-surface-raised: #ffffff;
  --color-text: #111827;
  --color-text-secondary: #4b5563;
  --color-text-tertiary: #9ca3af;
  --color-border: #e5e7eb;
  --color-border-strong: #d1d5db;
  --color-primary: #2563eb;
  --color-primary-hover: #1d4ed8;
  --color-success: #22c55e;
  --color-error: #ef4444;
  --color-warning: #eab308;
  --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1);
}

/* Semantic tokens -- dark theme */
[data-theme="dark"] {
  --color-bg: #030712;
  --color-surface: #111827;
  --color-surface-raised: #1f2937;
  --color-text: #f3f4f6;
  --color-text-secondary: #9ca3af;
  --color-text-tertiary: #6b7280;
  --color-border: #1f2937;
  --color-border-strong: #374151;
  --color-primary: #3b82f6;
  --color-primary-hover: #2563eb;
  --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.3);
  --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.4);
}
```

### Tailwind Integration with CSS Variables

```javascript
// tailwind.config.js
module.exports = {
  darkMode: 'class', // or 'selector' for Tailwind v4
  theme: {
    extend: {
      colors: {
        bg: 'var(--color-bg)',
        surface: 'var(--color-surface)',
        'surface-raised': 'var(--color-surface-raised)',
        primary: 'var(--color-primary)',
        'primary-hover': 'var(--color-primary-hover)',
        border: 'var(--color-border)',
      },
      textColor: {
        DEFAULT: 'var(--color-text)',
        secondary: 'var(--color-text-secondary)',
        tertiary: 'var(--color-text-tertiary)',
      },
      boxShadow: {
        sm: 'var(--shadow-sm)',
        md: 'var(--shadow-md)',
        lg: 'var(--shadow-lg)',
      },
    },
  },
};
```

## Tailwind CSS Dark Mode (Class Strategy)

### Configuration

```javascript
// tailwind.config.js
module.exports = {
  darkMode: 'class', // or 'selector' for [data-theme="dark"]
};
```

### Usage Pattern

Every color utility needs a `dark:` counterpart — bg, text, border, shadow, fill. Semantic pairings: `bg-white dark:bg-gray-950`, `text-gray-900 dark:text-gray-100`, `border-gray-200 dark:border-gray-800`. Partial dark mode (some components unthemed) is worse than none — audit every component.

```html
<div class="bg-white dark:bg-gray-950 text-gray-900 dark:text-gray-100">
  <p class="text-gray-600 dark:text-gray-400">Description</p>
  <button class="bg-blue-600 dark:bg-blue-500 hover:bg-blue-700 dark:hover:bg-blue-600 text-white px-4 py-2 rounded">
    Action
  </button>
</div>
```

## System Preference Detection

### matchMedia API

```typescript
function getSystemTheme(): 'light' | 'dark' {
  if (typeof window === 'undefined') return 'light';
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function onSystemThemeChange(callback: (theme: 'light' | 'dark') => void): () => void {
  const mq = window.matchMedia('(prefers-color-scheme: dark)');
  const handler = (e: MediaQueryListEvent) => callback(e.matches ? 'dark' : 'light');
  mq.addEventListener('change', handler);
  return () => mq.removeEventListener('change', handler);
}
```

### Resolution Order and Persistence

Priority: User choice (localStorage/cookie) → System preference (`prefers-color-scheme`) → Default (light).

For **client-side only**: use `localStorage`. For **SSR**: use a cookie so the server can read it on initial render. For **authenticated users**: persist in user profile and sync on login.

## FOUC Prevention (Flash of Unstyled Content)

### Inline Script in `<head>` (Critical)

Place this blocking script before any stylesheet or body content:

```html
<script>
  (function() {
    var theme = localStorage.getItem('theme');
    if (!theme) {
      theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    document.documentElement.setAttribute('data-theme', theme);
    document.documentElement.classList.toggle('dark', theme === 'dark');
  })();
</script>
```

Rules:
- Must be synchronous (no `async`/`defer`)
- Must execute before first paint
- Must be in `<head>` before stylesheets
- Keep it minimal -- no imports, no fetch calls

### SSR Theme Detection (Cookie-Based)

Read the theme cookie on the server and render the correct `data-theme` attribute in the initial HTML:

```typescript
// Server: read cookie, set attribute
const theme = getCookie('theme') ?? 'light';
const html = `<html data-theme="${theme}" class="${theme === 'dark' ? 'dark' : ''}">`;
```

## Server-Side Rendering

**Next.js**: use `next-themes` with `attribute="data-theme"`, `suppressHydrationWarning` on `<html>`, and check `mounted` before rendering theme-dependent UI. Use `resolvedTheme` to handle "system" mode.

**Nuxt**: use `@nuxtjs/color-mode` module; it injects FOUC prevention automatically.

**SvelteKit / Angular**: add blocking `<script>` in app shell (before stylesheets) to resolve theme before first paint. Use framework-specific state (Svelte: `$state`, Angular: signals) with persistent storage.

## Component-Level Theme Overrides

Force a specific theme on a component subtree regardless of the global theme:

```html
<!-- Force light mode for this card, even in dark mode -->
<div data-theme="light" class="rounded-lg border p-6">
  <p>This card is always light.</p>
</div>
```

This works because CSS custom properties are inherited and scoped by the closest ancestor with `data-theme`.

## Color Contrast Validation

WCAG AA minimums: normal text 4.5:1, large text/icons/interactive 3:1, focus indicators 3:1. Run `axe-core` or Lighthouse in both themes. Common dark-mode failures: gray-on-gray text, low-contrast borders, placeholder text.

## Image and SVG Handling in Dark Mode

- Alternate images: use `<picture>` with `<source media="(prefers-color-scheme: dark)" srcset="...">` for distinct dark variants
- Generic darkening: `[data-theme="dark"] img:not([data-no-invert]) { filter: brightness(0.9); }`
- SVGs and icons: use `fill: currentColor` so they inherit from text color automatically
- Logos: provide light and dark variants; toggle visibility via CSS on `[data-theme]`, or use a monochrome SVG with `currentColor`

## Third-Party Component Theming

**MudBlazor**: define light/dark palettes on `MudTheme`, bind `IsDarkMode` to toggle. **Radix UI / Headless UI**: map their CSS variable tokens to your theme tokens via `[data-theme]` selectors. **Material UI**: pass `mode` (light/dark) to `createTheme()`. **Angular Material**: define light/dark themes with `mat.define-theme()`, apply both via `html` and `[data-theme="dark"]` selectors.

## Transition Animations

### Smooth Color Transitions

```css
:root {
  --theme-transition-duration: 200ms;
  --theme-transition-easing: ease-out;
}

* {
  transition:
    background-color var(--theme-transition-duration) var(--theme-transition-easing),
    border-color var(--theme-transition-duration) var(--theme-transition-easing),
    color var(--theme-transition-duration) var(--theme-transition-easing),
    box-shadow var(--theme-transition-duration) var(--theme-transition-easing),
    fill var(--theme-transition-duration) var(--theme-transition-easing),
    stroke var(--theme-transition-duration) var(--theme-transition-easing);
}
```

### Respect Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  * {
    transition-duration: 0.01ms !important;
  }
}
```

### View Transition API (Progressive Enhancement)

```typescript
function setThemeWithTransition(theme: 'light' | 'dark') {
  if (!document.startViewTransition) {
    applyTheme(theme);
    return;
  }
  document.startViewTransition(() => applyTheme(theme));
}
```

## Testing Themes

- Visual regression: screenshot every major page/component in both modes; use `page.emulateMedia({ colorScheme: 'dark' })` in Playwright
- Toggle test: verify `html[data-theme]` attribute changes on toggle click
- Persistence test: click dark, reload, assert `data-theme="dark"` still set
- Run `axe-core` or Lighthouse a11y audit in both themes to catch contrast failures

## Common Pitfalls

- **Flash of wrong theme**: blocking inline `<script>` in `<head>` required before stylesheets
- **SSR hydration mismatch**: use cookie-based server detection or framework helpers (`next-themes`, `@nuxtjs/color-mode`)
- **Conditional JSX before mount**: causes hydration mismatch; use `mounted` guard or prefer CSS toggling
- **Missing `dark:` variants**: test every component in both modes; bg, text, border, shadow all need pairs
- **Mixing prefers-color-scheme with class toggling**: pick one strategy, not both
- **Dark background too harsh**: use `gray-950` or `gray-900`, not pure black
- **localStorage alone with SSR**: use cookies so server can read theme on initial render
- **No transitions when switching**: jarring UX; add `transition` on color properties
- **Images/logos/SVGs not handled**: provide distinct dark variants or use `currentColor` for icons

## Implementation Workflow

1. Choose strategy: CSS variables, Tailwind `dark:` class, or hybrid
2. Define color tokens for both themes (surfaces, text, borders, primary, status)
3. Add FOUC prevention blocking `<script>` in `<head>`
4. Implement theme provider/service; build toggle component with system option
5. Persist: `localStorage` for CSR, cookie for SSR
6. Audit all components in both modes; handle images, logos, SVGs, third-party widgets
7. Add smooth CSS transitions; respect `prefers-reduced-motion`
8. Test: visual regression, persistence across reload, SSR hydration check

## Output Format

```
Strategy:          [CSS variables / Tailwind dark: / hybrid]
Persistence:       [localStorage / cookie / database]
SSR Handling:      [next-themes / @nuxtjs/color-mode / cookie detection / inline script]
FOUC Prevention:   [inline head script / server-side cookie]
Tokens:            [token categories defined]
Toggle UI:         [component type and location]
Transitions:       [smooth / view-transition / none]
Third-Party:       [component libraries themed]
Testing:           [visual regression approach]
```

## Done Criteria

- Theme toggle works between light, dark, and system modes
- No flash of wrong theme on page load (FOUC prevented)
- Theme persists across page reloads and sessions
- System preference changes are detected and applied (when set to "system")
- No hydration mismatch with SSR
- Every surface, text, border, shadow, and icon has correct theme-aware values
- Color contrast meets WCAG AA in both modes (4.5:1 text, 3:1 interactive)
- Smooth transition between themes with reduced-motion respect
- Images and logos handled for both themes
- Third-party components themed consistently
- Visual regression tests pass in both modes
