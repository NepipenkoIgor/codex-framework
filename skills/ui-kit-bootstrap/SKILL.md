---
name: ui-kit-bootstrap
description: Generate a complete design token system and reusable primitive UI components — spacing, colors, typography, shadows, radius, breakpoints, and core components (Button, Input, Select, Card, Badge, Modal, Table) with consistent size variants, focus states, and accessibility
metadata:
  version: 1.4
  argument-hint: "framework (Tailwind/CSS Modules/Styled), component library target, color palette, token structure"
---

Bootstrap a design token system and UI kit for $ARGUMENTS.


## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing
- docs lookup tools: Check latest Tailwind/Radix/MUI/MudBlazor docs for token integration patterns.
- **Type diagnostics**: Validate component type signatures and token type safety.

## Pre-Flight

Before generating anything:

1. **Detect tech stack** — read `package.json`, `*.csproj`, `tailwind.config.*`, `theme.*` files
2. **Check existing tokens** — search for CSS variables, Tailwind config, theme files, design tokens
3. **Check existing components** — scan for Button, Input, Card patterns already in use
4. **Decide strategy:**
   - No tokens exist → generate from scratch
   - Partial tokens → extend and consolidate
   - Existing system but inconsistent → extract, normalize, replace

## Token Architecture

### Token Layers

```
Primitive tokens (raw values)
  → Semantic tokens (purpose-based aliases)
    → Component tokens (component-specific)
```

Example flow: `blue-500` → `color-primary` → `button-bg-primary`

### Implementation Format

Detect from project and use the matching format:

**CSS Custom Properties (default):**
```css
:root {
  /* Primitive */
  --color-blue-500: #3b82f6;
  /* Semantic */
  --color-primary: var(--color-blue-500);
  /* Component */
  --button-bg-primary: var(--color-primary);
}
```

**Tailwind CSS (if tailwind detected):**
```js
// tailwind.config.js — extend theme with semantic tokens
theme: {
  extend: {
    colors: { primary: 'var(--color-primary)' },
    spacing: { /* use token scale */ },
  }
}
```

**Blazor + MudBlazor (if .csproj detected):**
```csharp
// MudTheme as single source of truth
var theme = new MudTheme {
  PaletteLight = new PaletteLight {
    Primary = "#3b82f6", Secondary = "#6366f1",
    Error = "#ef4444", Success = "#22c55e", Warning = "#f59e0b",
    Surface = "#ffffff", Background = "#f8fafc",
    AppbarBackground = "#ffffff",
    TextPrimary = "#0f172a", TextSecondary = "#64748b"
  },
  Typography = new Typography {
    Default = new DefaultTypography { FontSize = "0.875rem", FontFamily = new[] { "Inter", "sans-serif" } },
    H1 = new H1Typography { FontSize = "2.25rem", FontWeight = 700 },
    Button = new ButtonTypography { FontSize = "0.875rem", FontWeight = 600 }
  },
  LayoutProperties = new LayoutProperties {
    DefaultBorderRadius = "6px"
  }
};
```
CSS variables in `app.css` for spacing, shadows, and anything MudTheme doesn't cover. Reference via `var(--space-4)` in `.razor.css` isolation files. Never hardcode px/hex in Razor component parameters or isolation CSS.

**CSS Modules / Styled Components:** adapt to project conventions.

### Required Token Categories

Generate ALL of these — no category is optional:

**1. Color Palette**
- Primitives: gray (50-950), primary (50-950), danger, warning, success, info — 10 shades each
- Semantic: `--color-primary`, `--color-primary-hover`, `--color-primary-active`, `--color-bg`, `--color-bg-subtle`, `--color-bg-muted`, `--color-surface`, `--color-border`, `--color-border-focus`, `--color-text`, `--color-text-secondary`, `--color-text-muted`, `--color-text-inverse`, `--color-danger`, `--color-success`, `--color-warning`
- Interactive states: default, hover, active, disabled, focus — for each semantic color

**2. Spacing Scale**
```
--space-0: 0;
--space-0.5: 0.125rem;  /* 2px */
--space-1: 0.25rem;     /* 4px */
--space-1.5: 0.375rem;  /* 6px */
--space-2: 0.5rem;      /* 8px */
--space-3: 0.75rem;     /* 12px */
--space-4: 1rem;        /* 16px */
--space-5: 1.25rem;     /* 20px */
--space-6: 1.5rem;      /* 24px */
--space-8: 2rem;        /* 32px */
--space-10: 2.5rem;     /* 40px */
--space-12: 3rem;       /* 48px */
--space-16: 4rem;       /* 64px */
```
Rule: all padding, margin, gap values must use this scale. No arbitrary pixel values.

**3. Typography Scale**
```
--text-xs: 0.75rem;     /* 12px, line-height 1rem */
--text-sm: 0.875rem;    /* 14px, line-height 1.25rem */
--text-base: 1rem;      /* 16px, line-height 1.5rem */
--text-lg: 1.125rem;    /* 18px, line-height 1.75rem */
--text-xl: 1.25rem;     /* 20px, line-height 1.75rem */
--text-2xl: 1.5rem;     /* 24px, line-height 2rem */
--text-3xl: 1.875rem;   /* 30px, line-height 2.25rem */
--text-4xl: 2.25rem;    /* 36px, line-height 2.5rem */
```
Font families: `--font-sans`, `--font-mono` (max 2).
Font weights: `--font-normal: 400`, `--font-medium: 500`, `--font-semibold: 600`, `--font-bold: 700`.

**4. Border Radius**
```
--radius-none: 0;
--radius-sm: 0.25rem;   /* 4px — inputs, small elements */
--radius-md: 0.375rem;  /* 6px — buttons, cards */
--radius-lg: 0.5rem;    /* 8px — modals, larger containers */
--radius-xl: 0.75rem;   /* 12px — feature cards */
--radius-full: 9999px;  /* pills, avatars */
```

**5. Shadows**
```
--shadow-sm: 0 1px 2px rgb(0 0 0 / 0.05);
--shadow-md: 0 4px 6px rgb(0 0 0 / 0.07);
--shadow-lg: 0 10px 15px rgb(0 0 0 / 0.1);
--shadow-xl: 0 20px 25px rgb(0 0 0 / 0.1);
```

**6. Focus Ring**
One global focus style — never per-component:
```
--focus-ring: 0 0 0 2px var(--color-bg), 0 0 0 4px var(--color-primary);
```
Applied via: `&:focus-visible { outline: none; box-shadow: var(--focus-ring); }`

**7. Transitions**
```
--transition-fast: 150ms ease;
--transition-normal: 200ms ease;
--transition-slow: 300ms ease;
```

**8. Breakpoints**
```
--bp-sm: 640px;
--bp-md: 768px;
--bp-lg: 1024px;
--bp-xl: 1280px;
```

## Primitive Components

Generate these components using ONLY tokens. Every component must support:
- **Size variants**: `sm`, `md` (default), `lg`
- **States**: default, hover, active, disabled, focus-visible
- **Accessibility**: focus ring, aria labels, keyboard navigation

### Button
```
Variants: primary, secondary, outline, ghost, danger, link
Sizes: sm (h-8, text-sm, px-3), md (h-10, text-sm, px-4), lg (h-12, text-base, px-6)
States: hover (darken 10%), active (darken 15%), disabled (opacity 0.5, pointer-events none), focus-visible (focus ring)
Icons: leading icon, trailing icon, icon-only (square aspect)
Loading: spinner replaces content, maintains width
```

### Input
```
Variants: default, error, success, disabled
Sizes: sm (h-8, text-sm), md (h-10, text-sm), lg (h-12, text-base)
States: default border, focus (primary border + ring), error (danger border + ring), disabled (muted bg)
Anatomy: optional label (above), optional helper text (below), optional leading/trailing icon
Required: label association (htmlFor/id), error announcements (aria-describedby)
```

### Select
Same size/state system as Input. Consistent height, padding, border, focus behavior.

### Textarea
Same border/focus/error system as Input. Resizable vertically only.

### Card
```
Variants: default (border), elevated (shadow), interactive (hover shadow lift)
Padding: uses spacing tokens (default: space-6)
Anatomy: optional header, body, footer — each uses consistent internal spacing
```

### Badge
```
Variants: primary, secondary, success, warning, danger, outline
Sizes: sm (text-xs, px-1.5, py-0.5), md (text-xs, px-2, py-1), lg (text-sm, px-2.5, py-1)
```

### Modal / Dialog
```
Overlay: semi-transparent black
Container: max-width token, radius-lg, shadow-xl, padding space-6
Sizes: sm (max-w-sm), md (max-w-lg), lg (max-w-2xl), full (max-w-full minus margin)
Focus trap: required
Close: Escape key + close button (top-right)
```

### Table
```
Header: semibold text, muted bg, border-bottom
Rows: consistent padding (space-3 vertical, space-4 horizontal), border-bottom
Hover: subtle bg change on interactive tables
Sizes: sm (text-xs, compact padding), md (text-sm, standard), lg (text-base, spacious)
```

## Size Consistency Rules

ALL interactive elements at the same size variant must have the same height:
- `sm` → 32px (h-8)
- `md` → 40px (h-10)
- `lg` → 48px (h-12)

This means: Button `md` = Input `md` = Select `md` = 40px tall. They sit side-by-side perfectly.

## File Structure

```
src/
  styles/
    tokens/
      colors.css (or .ts for CSS-in-JS)
      spacing.css
      typography.css
      shadows.css
      index.css (imports all)
    globals.css (reset + token import + base styles)
  components/
    ui/
      Button/
      Input/
      Select/
      Card/
      Badge/
      Modal/
      Table/
```

Adapt to project conventions (components/, shared/, ui/, etc.).

## Validation Checklist

After generating, verify:
- [ ] No hardcoded color hex/rgb anywhere in components — all reference tokens
- [ ] No hardcoded px for spacing — all reference spacing scale
- [ ] No hardcoded font-size — all reference typography scale
- [ ] All interactive elements at same size variant have identical height
- [ ] Focus ring is identical across all interactive elements
- [ ] Hover/active/disabled states are consistent across all components
- [ ] All form elements share identical border width, radius, and focus behavior
- [ ] Dark mode (if applicable) only changes token values, not component code
- [ ] Every component has proper aria attributes

## Anti-Patterns

- Defining tokens but using hardcoded values in components — tokens must be the ONLY way to set visual properties
- Per-component focus styles — one focus ring, applied globally
- Different heights for Button and Input at same size — they must align
- Inline styles or one-off CSS classes that bypass the token system

## Tool Integration

- docs lookup tools: Check latest Tailwind/Radix/MUI/MudBlazor docs for token integration patterns.
- **Type diagnostics**: Validate component type signatures and token type safety.

Done: ✓ all token categories defined ✓ primitive components generated ✓ size variants consistent ✓ focus ring unified ✓ states consistent ✓ accessibility covered ✓ no hardcoded values ✓ file structure matches project conventions
