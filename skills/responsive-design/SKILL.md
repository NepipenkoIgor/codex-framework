---
name: responsive-design
description: Implement responsive layouts using Tailwind CSS, fluid typography, container queries, responsive images, mobile-first patterns, and adaptive UI strategies
metadata:
  version: 1.5
  argument-hint: "minimum viewport width, breakpoint strategy (mobile-first/desktop-first), typography needs"
---

Implement $ARGUMENTS.

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Mobile-First vs Desktop-First

Mobile-first (default -- use unless project convention differs):
- Start with the smallest screen layout as the base CSS
- Add complexity with `min-width` media queries (Tailwind: `sm:`, `md:`, `lg:`, `xl:`, `2xl:`)

```html
<div class="flex flex-col gap-4 md:flex-row md:gap-6 lg:gap-8">
  <main class="w-full md:w-2/3 lg:w-3/4">...</main>
  <aside class="w-full md:w-1/3 lg:w-1/4">...</aside>
</div>
```

Desktop-first (use when): redesigning an existing desktop app; primary audience is desktop (admin panels, dashboards).

## Fluid Typography

| Role | clamp() |
|------|---------|
| H1 | `clamp(1.75rem, 1.25rem + 2.5vw, 2.5rem)` |
| H2 | `clamp(1.25rem, 1rem + 1.25vw, 1.75rem)` |
| Body | `clamp(0.875rem, 0.825rem + 0.25vw, 1rem)` |
| Small | `clamp(0.75rem, 0.7rem + 0.25vw, 0.875rem)` |

Rules:
- Never use viewport units alone for font-size -- breaks zoom accessibility
- Always use `clamp()` with rem base + vw scaling
- Minimum: 14px body, 12px captions; max line length: 65ch

## Container Queries

```css
.card-wrapper { container-type: inline-size; container-name: card; }
@container card (min-width: 400px) { .card { display: grid; grid-template-columns: 200px 1fr; } }
@container card (max-width: 399px) { .card { display: flex; flex-direction: column; } }
```

- Container queries: reusable components in different layout contexts
- Media queries: page-level layout changes

## CSS Grid Responsive Patterns

```css
/* Auto-flow cards: minimum 280px, fill available space */
.card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1.5rem; }
```

```html
<!-- Dashboard layout -->
<div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
  <div class="lg:col-span-8"><!-- Main --></div>
  <div class="lg:col-span-4"><!-- Sidebar --></div>
</div>
```

## Breakpoint Strategy

| Prefix | Min-width | Target |
|--------|-----------|--------|
| (none) | 0px | Mobile portrait (320-639px) |
| sm | 640px | Large phone/small tablet |
| md | 768px | Tablet portrait |
| lg | 1024px | Tablet landscape, laptop |
| xl | 1280px | Desktop |
| 2xl | 1536px | Large desktop |

Testing checklist: verify at 320, 375, 768, 1024, 1280, 1536px.

## Touch Targets

- Minimum: 44x44px (WCAG 2.5.8); recommended 48x48px
- Minimum 8px gap between targets
- Bottom sheets preferred over centered modals on mobile

## Viewport and Safe Areas

```html
<meta name="viewport" content="width=device-width, initial-scale=1" />
```

- Never set `maximum-scale=1` or `user-scalable=no`
- Use `env(safe-area-inset-*)` for fixed elements on notched devices

## Modern CSS Techniques

### Dynamic Viewport Units

```css
.hero { min-height: 100dvh; } /* adapts to browser chrome on mobile */
.modal { height: 100svh; }    /* never extends behind browser chrome */
```

### CSS `has()` Selector

```css
.form-group:has(.input:invalid) { border-color: var(--color-error); }
```

### CSS Subgrid

```css
.product-card { display: grid; grid-template-rows: subgrid; grid-row: span 3; }
```

Supported in Chrome 117+, Firefox 71+, Safari 16+.

## Framework-Specific Patterns

### Angular

```typescript
isMobile = toSignal(
  inject(BreakpointObserver).observe([Breakpoints.Handset]).pipe(map(r => r.matches)),
  { initialValue: false },
);
```

Use `BreakpointObserver` for structural changes (show/hide components); Tailwind prefixes for styling.

### Blazor (MudBlazor)

```razor
<MudGrid Spacing="4">
  <MudItem xs="12" sm="6" md="4">...</MudItem>
</MudGrid>
<MudHidden Breakpoint="Breakpoint.SmAndDown"><AppSidebar /></MudHidden>
```

For JS-driven breakpoint detection use `IJSRuntime` in `OnAfterRenderAsync`.

### SvelteKit

```svelte
<script lang="ts">
  let innerWidth = $state(0);
  let isMobile = $derived(innerWidth < 768);
</script>
<svelte:window bind:innerWidth />
```

Use `@tailwindcss/vite` plugin; `@container` variant for component-level queries.

### Vue / Nuxt

Use Tailwind responsive prefixes for styling. For programmatic breakpoints: `useBreakpoints()` from VueUse or a `matchMedia` composable.

> Use available docs lookup tools or official docs to fetch current Tailwind, MudBlazor, Angular CDK, and SvelteKit docs for implementation syntax.

## Anti-Patterns

- Only viewport breakpoints for reusable components — use container queries instead
- Viewport units alone for font-size — always pair with `clamp()` and a rem base
- Overriding viewport zoom (`user-scalable=no`) — WCAG 1.4.4 violation
- Hiding content instead of reflowing

## Implementation Workflow

1. Detect framework and existing responsive patterns
2. Identify layout type: page, component, or content
3. Choose mobile-first or desktop-first
4. Implement base layout with fluid sizing (`clamp`, `%`, `fr`)
5. Add breakpoint overrides for layout changes
6. Add container queries for components in variable contexts
7. Verify at 320, 375, 640, 768, 1024, 1280, 1536
8. Test touch targets (44px+), safe areas, zoom at 200%

## Done Criteria

- Layout works at all key viewports: 320, 375, 640, 768, 1024, 1280, 1536
- No horizontal overflow at any viewport width
- All text readable without zooming (14px+ body minimum)
- Touch targets meet 44x44px minimum on mobile
- Typography uses fluid scaling with `clamp()`
- Layout survives 200% text zoom
- Safe areas handled for fixed elements on notched devices
- Container queries used for reusable components in variable contexts
