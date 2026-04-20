---
name: design-system-implement
description: Implement design system components including tokens, themes, variants, compound components, accessibility, icons, animation, and responsive patterns
metadata:
  version: 2.6
  argument-hint: "framework (React/Vue/Web Components), component type (buttons/forms/layout/complex), variant system, token system, animation requirements, accessibility scope"
---

Implement $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

Core principles:

- Build on Tailwind — extend, do not replace
- Every component must handle all states: default, hover, focus, active, disabled, loading, error
- Type-safe props with discriminated unions for variant combinations
- Accessibility is implementation, not an afterthought
- Prefer CSS for styling, JS for behavior
- Composable over configurable — prefer slot/children patterns over prop explosion
- One component, one responsibility; split when complexity grows
- Design for consumption: clear API, predictable behavior, minimal surprise

Design token implementation:

CSS custom properties:

- Define tokens as CSS custom properties on `:root` or a theme scope
- Organize tokens by category: color, spacing, typography, radius, shadow, motion
- Use semantic naming over raw values: `--color-primary`, not `--blue-500`
- Layer tokens: primitive (`--blue-500`) -> semantic (`--color-primary`) -> component (`--button-bg`)

```css
:root {
  /* Primitive tokens */
  --blue-500: #3b82f6;
  --gray-900: #111827;

  /* Semantic tokens */
  --color-primary: var(--blue-500);
  --color-text: var(--gray-900);
  --radius-md: 0.375rem;
  --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);

  /* Motion tokens */
  --duration-fast: 150ms;
  --duration-normal: 200ms;
  --ease-default: cubic-bezier(0.4, 0, 0.2, 1);
}
```

Tailwind theme configuration:

- Extend the Tailwind theme in `tailwind.config`; do not override default values unless intentional
- Map design tokens to Tailwind values using CSS custom properties

```js
// tailwind.config.js — extend pattern
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: 'var(--color-primary)',
        surface: 'var(--color-surface)',
      },
      borderRadius: { DEFAULT: 'var(--radius-md)' },
    },
  },
};
```

Token file organization:
- `tokens/colors.css` — color primitives and semantic color tokens
- `tokens/typography.css` — font family, size, weight, line-height, letter-spacing
- `tokens/spacing.css` — spacing scale if extending beyond Tailwind defaults
- `tokens/shadows.css` — elevation and shadow tokens
- `tokens/motion.css` — duration, easing, and animation tokens
- `tokens/index.css` — imports all token files

Theme switching:

```css
:root, [data-theme="light"] {
  --color-bg: #ffffff;
  --color-text: #111827;
  --color-surface: #f9fafb;
  --color-border: #e5e7eb;
}

[data-theme="dark"] {
  --color-bg: #0f172a;
  --color-text: #f1f5f9;
  --color-surface: #1e293b;
  --color-border: #334155;
}
```

- Toggle by setting `data-theme` on `document.documentElement`
- Persist in `localStorage`; respect `prefers-color-scheme` as default
- Define dark tokens as overrides; do not duplicate the full token set

Component implementation:

Component API design:

- Props must be explicit and typed; no catch-all prop spreading without intent
- Use discriminated unions for mutually exclusive variant combinations
- Default all optional props
- Prefer children/slots over render props for content composition
- Forward refs (React), template refs (Vue), or equivalent for imperative access

State handling in every component:

- Default, Hover, Focus (visible ring — never remove without replacement), Active, Disabled (`aria-disabled="true"`), Loading (spinner/skeleton; prevent duplicate actions), Error (visual indicator with accessible message)

Component file structure:
- `ComponentName.tsx` (or `.vue`, `.svelte`, `.ts` for Angular)
- `ComponentName.types.ts` — props, variants, and internal types
- `ComponentName.stories.tsx` — Storybook stories if present
- `ComponentName.test.tsx` — unit tests if testing is established
- `index.ts` — public export

Variant systems (Class Variance Authority):

```tsx
import { cva, type VariantProps } from 'class-variance-authority';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        primary: 'bg-primary text-white hover:bg-primary/90',
        secondary: 'bg-surface text-text border border-border hover:bg-surface/80',
        ghost: 'hover:bg-surface',
        destructive: 'bg-red-600 text-white hover:bg-red-700',
      },
      size: {
        sm: 'h-8 px-3 text-sm',
        md: 'h-10 px-4 text-sm',
        lg: 'h-12 px-6 text-base',
      },
    },
    defaultVariants: { variant: 'primary', size: 'md' },
  }
);

type ButtonProps = VariantProps<typeof buttonVariants>;
```

- Keep variant definitions close to the component; do not centralize unrelated variants
- Combine with `cn`/`clsx` utility for conditional class merging; derive variant prop types from cva

Compound components:

- Use for complex UI: Select, Menu, Dialog, Table, Tabs
- Parent provides context; children consume it; each sub-component is independently importable
- Use React Context, Angular DI, Vue `provide`/`inject`, or Svelte context for parent-child communication

```tsx
<Select value={value} onChange={setValue}>
  <Select.Trigger><Select.Value placeholder="Choose..." /></Select.Trigger>
  <Select.Content>
    <Select.Item value="a">Option A</Select.Item>
    <Select.Item value="b">Option B</Select.Item>
  </Select.Content>
</Select>
```

- Support controlled and uncontrolled usage where applicable

Accessibility implementation:

ARIA attributes:
- Use semantic HTML first; add ARIA only when native semantics are insufficient
- Set `role`, `aria-label`, `aria-labelledby`, `aria-describedby`, `aria-expanded`, `aria-selected`, `aria-checked` as appropriate
- Use `aria-live` regions for dynamic updates; prefer `polite` over `assertive`
- Set `aria-disabled` instead of removing elements

Keyboard navigation:
- All interactive elements reachable via Tab
- Arrow key navigation for composite widgets: menus, listboxes, tabs, grids
- Escape to close overlays; Enter/Space to activate; Home/End for list navigation
- Follow WAI-ARIA Authoring Practices for each widget pattern

Focus management:
- Trap focus inside modal dialogs; return focus to trigger on close
- Use `focus-visible` for keyboard-only focus styles
- Manage focus programmatically on route changes or dynamic content insertion
- Provide skip links for repeated navigation blocks

Screen reader support:
- Visually-hidden text for icon-only buttons and links
- Explicitly associate labels with form inputs
- Announce state changes: loading, error, success, count updates

Icon system:

- Wrap SVGs in components with consistent size, color, accessibility props
- Use `currentColor` for fill/stroke; support `size` prop (sm/md/lg or pixel values)
- `aria-hidden="true"` on decorative icons; `aria-label` on meaningful icons
- Tree-shakable imports; avoid importing the full icon set
- Sprite sheets for large icon sets: `<use href="#icon-name">`, cached separately

Animation and motion:

- Tailwind transition utilities for simple state changes (hover, focus, open/close)
- Prefer `transform` and `opacity` for performant animations; avoid animating layout properties
- Use `@keyframes` for repeating or multi-step animations

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

- Framer Motion / React Spring for physics-based, gesture-driven, or layout animations
- Keep animation definitions colocated with components
- Motion principles: purposeful (communicates meaning), fast (150-300ms; never >500ms), subtle, accessible

Responsive implementation:

- CSS container queries for components that adapt to their container, not the viewport

```css
.card-container { container-type: inline-size; }

@container (min-width: 400px) {
  .card { grid-template-columns: 1fr 1fr; }
}
```

- Tailwind responsive prefixes for viewport-based design; keep breakpoints consistent
- Prefer fluid typography and spacing (`clamp()`) over rigid breakpoints
- Test at: 320px, 768px, 1024px, 1280px, 1536px
- Never hide critical actions on small screens

Storybook integration:

- CSF3 format; stories for every variant and state combination
- Include: default, all variants, all sizes, disabled, loading, error, empty, interaction stories
- `argTypes` for all props with correct control types; JSDoc prop descriptions
- Configure Chromatic or similar for visual regression testing

Framework-specific patterns:

React:
- Accept `ref` as a regular prop (React 19+); use `React.ComponentProps<'div'>` instead of `ComponentPropsWithoutRef`; do not wrap with `React.forwardRef()`
- Derive props from HTML element types; extend with component-specific props
- Support `asChild` or `as` prop pattern for render delegation

Angular:
- Standalone components with `input()`, `output()`, `model()` APIs
- `host: { '[class]': 'hostClass()' }` for variant class binding
- `ng-content` for composition; `inject()` over constructor injection

Angular Material:
- Setup: `ng add @angular/material`
- Modern theming API: `mat.define-theme()` with color and typography config; `mat.all-component-themes()` in `html {}`
- Dark mode: `[data-theme="dark"] { @include mat.all-component-colors($dark-theme); }`
- Use Material for complex widgets (datepicker, autocomplete, stepper, sort/paginated table); Tailwind for layout, spacing, typography

Vue:
- `<script setup lang="ts">` with `defineProps`, `defineEmits`, `defineModel`
- `useSlots()` for conditional slot rendering
- `provide`/`inject` for compound component context

Svelte:
- Runes: `let { variant = 'primary', size = 'md' } = $props()`
- `{#snippet}` blocks over slots (Svelte 5); callback props via `$props()` over `createEventDispatcher()`
- Theme toggle: `$effect()` syncing `document.documentElement.dataset.theme`

Framework integration patterns:

### Next.js App Router

```tsx
// app/layout.tsx — theme provider + font token
import { Inter } from 'next/font/google';
import { ThemeProvider } from '@/components/theme-provider';
import '@/styles/tokens/index.css';

const inter = Inter({ subsets: ['latin'], variable: '--font-sans' });

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.variable}>
        <ThemeProvider attribute="data-theme" defaultTheme="system" enableSystem>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
```

- Token delivery via CSS custom properties in `app/globals.css`
- Component library exported from `@/components/ui/` barrel files
- `next/font` for font token integration; `next-themes` or `cookies()` for dark mode

### Nuxt 3

- `useColorMode()` composable for theme switching; `colorMode.dataValue: 'theme'`
- `app.config.ts` for design tokens via `useAppConfig()`
- Auto-imported components from `components/ui/`
- Nuxt Layer for shared design system: `extends: ['../design-system']`

### SvelteKit

- CSS custom properties in `app.css` imported in `+layout.svelte`
- Component library: `$lib/components/ui/` with barrel exports
- Tailwind config extending from `$lib/tokens/`

### Angular Standalone

```typescript
@Injectable({ providedIn: 'root' })
export class ThemeService {
  readonly theme = signal<'light' | 'dark'>('light');

  private readonly _applyTheme = effect(() => {
    const t = this.theme();
    afterNextRender(() => {
      document.documentElement.dataset['theme'] = t;
      localStorage.setItem('theme', t);
    });
  });

  constructor() {
    afterNextRender(() => {
      const stored = localStorage.getItem('theme');
      if (stored === 'light' || stored === 'dark') this.theme.set(stored);
    });
  }

  toggle() { this.theme.update(t => t === 'light' ? 'dark' : 'light'); }
}
```

- Design tokens as CSS custom properties in `styles.css`
- Component library as Angular library: `ng generate library ui`
- `provideAnimations()` for enter/exit transitions

### Blazor

- CSS isolation: `Component.razor.css` for scoped styles
- Design tokens in `wwwroot/css/tokens.css`
- MudBlazor theme: `MudThemeProvider` with custom `MudTheme` object (`PaletteLight`, `PaletteDark`, `LayoutProperties`)
- Cascading value for dark mode: `<CascadingValue Value="@_isDarkMode" Name="IsDarkMode">`

Implementation workflow:

1. Detect the framework and existing design system conventions
2. Identify the component scope: primitive, composed, or page-level pattern
3. Define the component API: props, variants, slots, events, accessibility requirements
4. Implement tokens and theme support if not already established
5. Build the component with all states, variants, and accessibility
6. Add Storybook stories if present in the project
7. Verify responsive behavior across breakpoints
8. Provide a summary with usage examples

Output format:

```
Component:     name and purpose
Framework:     detected framework
Tokens:        design tokens created or used
Variants:      variant dimensions and options
Accessibility: ARIA attributes, keyboard navigation, focus management
States:        all handled states (default, hover, focus, disabled, loading, error)
Responsive:    breakpoint behavior
Composition:   slot/children patterns and compound component structure
```

Output rules:

- Produce concrete component code, not abstract design guidance
- Include TypeScript types with every component
- Include accessibility attributes and keyboard handling
- Handle all interaction states; never ship a component that only handles the default state
- Follow the project's existing patterns for file structure, naming, and exports
- Mention assumptions when design tokens or theme context is not established
- Keep components lean; extract utilities and tokens to dedicated files when non-trivial

## Visual Verification

Use browser automation to verify component appearance, variant states, responsive behavior, and dark/light theme rendering.
