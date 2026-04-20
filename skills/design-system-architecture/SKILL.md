---
name: design-system-architecture
description: Design design system architecture covering tokens, theming, component taxonomy, variant systems, accessibility, icon systems, typography scales, color systems, and documentation strategy
metadata:
  version: 1.6
  argument-hint: "frontend framework (React/Vue/Angular), scale (startup/enterprise), component coverage scope, token/theme system, documentation platform"
---

Design the design system architecture for $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

## Documentation

> Use available docs lookup tools or official docs for current Tailwind CSS, Style Dictionary, Storybook, axe-core, and framework-specific component library docs. Do not rely on training data for configuration syntax.

Frameworks: React, Angular, Vue, Svelte, Web Components. Styling: Tailwind CSS, CSS custom properties. Documentation: Storybook, Chromatic.

## Core Principles

- Tokens are the API between design and code; every visual decision flows through tokens
- Components should be framework-agnostic concepts, even if implementations differ
- Accessibility is a design constraint, not a feature added later
- A design system grows with the product; start small, expand deliberately
- Consistency beats novelty; predictability beats flexibility

## Token Architecture

### Token Tiers

- **Primitive tokens**: raw values (`blue-500: #3b82f6`, `spacing-4: 16px`)
- **Semantic tokens**: purpose-mapped (`color-bg-primary: blue-500`, `spacing-component-gap: spacing-4`)
- **Component tokens**: component-specific (`button-bg: color-bg-primary`)

Rules: components reference semantic tokens, never primitive tokens directly; themes override semantic tokens; this tiered approach enables theming without touching component code.

### Token Categories

Color, Typography (family/size/weight/line-height/letter-spacing), Spacing, Elevation, Border (radius/width), Motion (duration/easing), Breakpoints, Sizing, Opacity, Z-index.

### Naming Convention

`category-property-variant-state` — e.g., `color-bg-primary-hover`, `font-size-sm`, `shadow-md`, `motion-duration-fast`.

### CSS Custom Properties

```css
:root { --blue-500: #3b82f6; --color-primary: var(--blue-500); }
[data-theme="dark"] { --color-bg: var(--gray-900); }
```

Tailwind: map config to CSS custom properties for runtime theming — `colors: { primary: 'var(--color-primary)' }`.

> Use available docs lookup tools or official docs to fetch current Style Dictionary docs for multi-platform token distribution.

## Color System

- Base palette: 50-950 lightness steps for primary, secondary, neutral, success, warning, error, info
- Generate using OKLCH/LCH for perceptual uniformity
- Semantic mapping: `color-bg-primary/secondary/tertiary`, `color-text-primary/secondary/inverse`, `color-border-primary/focus`
- WCAG 2.2 AA: 4.5:1 for normal text, 3:1 for large text and UI components
- Dark mode: map semantic tokens to dark palette values (do not simply invert); elevate surfaces with lighter shades, not shadows

## Typography Scale

Named steps: `text-xs` (12px), `text-sm` (14px), `text-base` (16px), `text-lg` (18px), `text-xl` (20px), `text-2xl` (24px), `text-3xl` (30px), `text-4xl` (36px).

Line height tokens: `leading-tight` (1.2), `leading-normal` (1.5), `leading-relaxed` (1.6). Font weight limited set: 400, 500, 600, 700. Fluid typography with `clamp()` for responsive scaling.

## Spacing System

4px base unit. Scale: 0, 0.5(2px), 1(4px), 2(8px), 3(12px), 4(16px), 6(24px), 8(32px), 12(48px), 16(64px). Named layout tokens: `spacing-page-x`, `spacing-section-gap`, `spacing-card-padding`, `spacing-form-gap`.

Never use arbitrary pixel values; use gap (flexbox/grid) over margin.

## Component Taxonomy

**Atoms**: Button, IconButton, Input, Textarea, Select, Checkbox, Radio, Switch, Badge, Avatar, Icon, Tooltip, Spinner, Skeleton, Divider.

**Molecules**: FormField (Label + Input + Helper + Error), SearchInput, Pagination, Breadcrumbs, Tabs, Dropdown, Toast, Card, EmptyState.

**Organisms**: DataTable, Modal/Dialog, Drawer/Sheet, CommandPalette, NavigationSidebar, PageHeader, FilterBar.

## Component API Design

- Explicit typed props; avoid catch-all prop spreading
- Variant props as union types: `size: 'sm' | 'md' | 'lg'`
- Boolean props for binary states: `disabled`, `loading`, `fullWidth`
- Render props or slots for customizable regions
- Compound components: `Card`, `Card.Header`, `Card.Body` (React); named slots (Vue, Svelte, Angular)
- Controlled and uncontrolled modes for forms and modals

Variant system: define along orthogonal axes (size, color, variant, state). Map variant values to token references, not hardcoded values.

## Accessibility Foundation (WCAG 2.2 AA)

- All interactive elements keyboard accessible with visible focus indicators
- Focus management: trap in modals, restore on close
- ARIA attributes: roles, labels, descriptions, live regions
- Color is never the only means of conveying information
- Touch targets: minimum 44x44px
- Motion: respect `prefers-reduced-motion`

Component-level: Button (`aria-disabled`, `aria-pressed`), Input (`aria-describedby`, `aria-invalid`), Modal (`role="dialog"`, `aria-modal`, focus trap), Tabs (roving tabindex), Tooltip (`role="tooltip"`, dismiss on Escape), Menu (arrow key navigation, type-ahead).

Automate with axe-core in unit tests and CI. Integrate `@storybook/addon-a11y`.

## Icon System

- Inline SVG components for tree-shaking and styling flexibility
- Consistent size tokens: `icon-xs` (12px), `icon-sm` (16px), `icon-md` (20px), `icon-lg` (24px)
- Support `currentColor` for color inheritance
- Decorative icons: `aria-hidden="true"`; informational: `aria-label` or visible text; interactive: require `aria-label`
- Use a single icon library (Lucide, Heroicons, Phosphor, Radix Icons)

## Multi-Brand and Theming

- Themes as semantic token overrides: `[data-theme="dark"]`, `[data-brand="acme"]`
- Each brand extends base theme, overriding only brand-specific tokens
- Runtime switching without page reload
- Persist user preference (localStorage); respect `prefers-color-scheme`; apply before first paint (no FOUC)

## Documentation Strategy (Storybook)

- Document every component: description, props table, usage examples, variants gallery
- Organize by atomic level: Atoms / Molecules / Organisms
- Include dark mode toolbar toggle, a11y addon, controls for interactive exploration
- Component documentation structure: Overview, Props/API, Variants, States, Composition, Accessibility, Code examples

## Framework Implementation Notes

- **React**: function components + TypeScript; `forwardRef` for ref-forwarding; `React.ComponentPropsWithoutRef` for native element extension; CSS custom properties + Tailwind (no CSS-in-JS runtime)
- **Angular**: standalone components; `input()`, `output()`, `model()`; `ng-content` slots; OnPush change detection
- **Vue**: `<script setup lang="ts">`; `defineProps`/`defineEmits`/`defineModel`; named slots; scoped styles or Tailwind
- **Svelte**: TypeScript props with `export let`; named slots; CSS custom properties for theming
- **Web Components**: for cross-framework sharing; Shadow DOM for encapsulation; CSS custom properties for theming

## Anti-Patterns

- Arbitrary values not on the token scale (`padding: 13px`)
- Prop-heavy components that handle every use case via configuration
- Theming by overriding component styles instead of token values
- Color as the only means of conveying status
- Adding components before they are used in two or more places

## Implementation Roadmap

**Phase 1**: Token architecture + theme infrastructure (light/dark, CSS custom properties, Tailwind config).

**Phase 2**: Core components — Atoms (Button, Input, Badge, Avatar, Icon, Spinner), Molecules (FormField, Card, Tabs, Toast), Storybook setup.

**Phase 3**: Complex components — DataTable, Modal, Drawer, CommandPalette; pattern documentation.

**Phase 4**: Multi-brand theming, cross-framework support, visual regression testing (Chromatic), contribution guidelines.
