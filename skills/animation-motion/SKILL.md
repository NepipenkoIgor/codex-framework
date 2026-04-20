---
name: animation-motion
description: Implement animations, transitions, and micro-interactions using CSS, Framer Motion, GSAP, View Transitions API, Angular animations, and Vue transition components
metadata:
  version: 1.6
  argument-hint: "animation type (CSS/Framer Motion/GSAP/View Transitions), UI element (button/modal/page transition), duration/timing preference, reduced-motion requirement"
---

Implement $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

## Motion Principles

Purpose — animate only when it: communicates state changes, provides user feedback, guides attention, establishes spatial relationships, or reduces perceived latency. Never animate for decoration alone.

**Timing:**
| Interaction | Duration |
|---|---|
| Micro (button, toggle, checkbox) | 100–150ms |
| Small reveal (dropdown, tooltip) | 150–200ms |
| Medium (panel, tab, accordion) | 200–300ms |
| Large (modal, drawer, page) | 250–350ms |
| Complex sequence (stagger, onboarding) | 300–500ms |

Never exceed 500ms for a single UI transition.

**Easing:**
| Curve | Use |
|---|---|
| `cubic-bezier(0.0, 0.0, 0.2, 1)` | ease-out — entering elements (default) |
| `cubic-bezier(0.4, 0.0, 1, 1)` | ease-in — exiting elements |
| `cubic-bezier(0.4, 0.0, 0.2, 1)` | ease-in-out — changing position |
| `cubic-bezier(0.34, 1.56, 0.64, 1)` | spring — playful toggles |
| linear | progress bars, continuous rotation only |

## CSS Animations and Transitions

```css
.button {
  transition: background-color 150ms ease-out, transform 100ms ease-out, box-shadow 150ms ease-out;
}
.button:hover { background-color: var(--color-primary-hover); box-shadow: var(--shadow-md); }
.button:active { transform: scale(0.97); }

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}
@keyframes shimmer {
  0%   { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}

.fade-in { animation: fadeIn 200ms ease-out forwards; }
.skeleton {
  background: linear-gradient(90deg, var(--color-surface) 25%, var(--color-surface-hover) 50%, var(--color-surface) 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s ease-in-out infinite;
}
.spinner { animation: spin 600ms linear infinite; }

/* CSS stagger */
.stagger-item {
  animation: fadeIn 200ms ease-out forwards;
  animation-delay: calc(var(--index) * 50ms);
  opacity: 0;
}
```

Rules: always specify which properties transition — never `transition: all`. Use `will-change` sparingly, only before animation starts, remove after.

## Framework-Specific Patterns

For implementation details read the appropriate reference:
- Framer Motion (React) → `references/framer-motion.md`
- GSAP timeline and ScrollTrigger → `references/gsap.md`
- View Transitions API → `references/view-transitions-api.md`
- Angular animations → `references/angular-animations.md`
- Vue transitions → `references/vue-transitions.md`
- Svelte transitions → `references/svelte-transitions.md`

## Micro-Interactions

- **Button:** hover (background + shadow), active (scale 0.97), focus-visible (outline), loading (opacity 0.7, pointer-events none)
- **Toggle/switch:** spring easing `cubic-bezier(0.34, 1.56, 0.64, 1)`, 200ms translate + 150ms color

```css
.toggle-thumb { transition: transform 200ms cubic-bezier(0.34, 1.56, 0.64, 1), background-color 150ms ease-out; }
.toggle[aria-checked="true"] .toggle-thumb { transform: translateX(20px); }
```

## Loading States

- **Skeleton:** match shape to content; shimmer follows reading direction; fade to real content at 150ms
- **Progressive:** 0ms → skeleton | 300ms → subtle progress | 2000ms → "still loading" | 10000ms → retry
- **Optimistic UI:** update immediately, revert on failure, show subtle "saving", confirm on success

## Scroll-Driven Animations

- Intersection Observer for reveal-on-scroll — animate once, do not replay
- CSS Scroll Timeline as progressive enhancement only
- Keep scroll animations subtle — avoid parallax causing motion sickness

## Page Transitions

- Fade out 150ms ease-in → fade in 200ms ease-out; total under 300ms
- Use `layoutId` (Framer Motion) or `view-transition-name` for shared elements
- Fall back to simple fade when shared element transitions unsupported

## Reduced Motion (Mandatory)

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

Tailwind: `motion-reduce:transition-none motion-reduce:animate-none` on each element.

JS detection (React example — adapt per framework):
```typescript
function useReducedMotion(): boolean {
  return useSyncExternalStore(
    (cb) => { const mq = matchMedia('(prefers-reduced-motion: reduce)'); mq.addEventListener('change', cb); return () => mq.removeEventListener('change', cb); },
    () => matchMedia('(prefers-reduced-motion: reduce)').matches,
    () => false
  );
}
```

Angular: inject `ReducedMotionService` (signal-based), skip GSAP/animation triggers when `prefersReducedMotion()` is true.

Svelte: detect in `$effect()`, conditionally render `transition:fade` vs `transition:fly`.

Blazor: detect via `JS.InvokeAsync<bool>("eval", "window.matchMedia(...).matches")` in `OnAfterRenderAsync`; skip GSAP calls, apply final CSS class instead.

**Rules for all frameworks:**
- Every animation must have a reduced-motion alternative
- Replace transform/position animations with opacity fades (150ms max)
- Keep state feedback (color, opacity) — remove spatial motion (translation, scale, rotation)
- Never remove all visual feedback
- Test by enabling "Reduce motion" in OS accessibility settings

## Performance

| Animate (GPU, compositor thread) | Avoid (layout thrashing) |
|---|---|
| `transform`, `opacity`, `filter` | `width`, `height`, `top`, `left`, `margin`, `padding`, `border-width`, `font-size` |

Target 60fps (16.6ms/frame). Animations using only `transform` and `opacity` run off main thread.

## Spring Physics vs Easing

- **Springs:** gesture responses, interactive elements, animations that interrupt mid-flight
- **Easing:** simple state transitions, CSS-only animations, consistent timing (progress bars)

## Stagger Rules

- Delay: 30–80ms between items
- Cap total: do not exceed 800ms for 20+ items
- Only animate visible items
- For grids, stagger by row or distance from top-left

## Nuxt 3 Transitions

```vue
<script setup lang="ts">
definePageMeta({
  pageTransition: { name: 'slide', mode: 'out-in' },
  layoutTransition: { name: 'fade', mode: 'out-in' },
});
</script>
```

```css
.slide-enter-active { transition: all 300ms ease-out; }
.slide-leave-active { transition: all 200ms ease-in; }
.slide-enter-from { opacity: 0; transform: translateX(40px); }
.slide-leave-to   { opacity: 0; transform: translateX(-40px); }
.fade-enter-active, .fade-leave-active { transition: opacity 200ms ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
```

Global defaults in `nuxt.config.ts`: `app.pageTransition` / `app.layoutTransition`.

`@vueuse/motion` directives: `v-motion-slide-left`, `v-motion-fade-visible-once`, `v-motion-pop`. Programmatic: `useMotion(ref, { initial, enter: { transition: { type: 'spring', stiffness: 250, damping: 20 } } })`.

View Transition API composable: wrap `router.push()` in `document.startViewTransition()` with feature detection fallback. Use `::view-transition-old/new(root)` CSS + `view-transition-name` on shared elements.

## SvelteKit Motion

```svelte
<script lang="ts">
  import { fade, fly, slide, scale } from 'svelte/transition';
  import { flip } from 'svelte/animate';
  import { tweened, spring } from 'svelte/motion';
  import { cubicOut, elasticOut } from 'svelte/easing';

  let visible = $state(true);
  const progress = tweened(0, { duration: 400, easing: cubicOut });
  const coords = spring({ x: 0, y: 0 }, { stiffness: 0.1, damping: 0.4 });

  let items = $state([{ id: '1', text: 'A' }, { id: '2', text: 'B' }]);
</script>

{#if visible}
  <div in:fly={{ y: 20, duration: 300, easing: cubicOut }} out:fade={{ duration: 150 }}>Content</div>
  <div transition:scale={{ start: 0.8, duration: 250, easing: elasticOut }}>Scale bounce</div>
{/if}

{#each items as item (item.id)}
  <div animate:flip={{ duration: 300 }} transition:fade={{ duration: 200 }}>{item.text}</div>
{/each}

<progress value={$progress} />
```

**Page transitions** (`+layout.svelte`): `onNavigate()` + `document.startViewTransition()` with `::view-transition-old/new(root)` CSS keyframes.

**`$effect()` for CSS class trigger:**
```svelte
$effect(() => {
  count; // track dependency
  flash = true;
  const t = setTimeout(() => { flash = false; }, 300);
  return () => clearTimeout(t);
});
```

**Custom transition function:**
```typescript
function myTransition(node: HTMLElement, { duration = 300 }) {
  return { duration, css: (t: number) => `opacity: ${t}; transform: translateY(${(1-t)*20}px);` };
}
```

`svelte/easing` defaults: `cubicOut` for enter, `cubicIn` for exit, `elasticOut` for bounce.

## Blazor Motion (.NET 8+)

```razor
<!-- Tailwind class toggle -->
<div class="transition-all duration-300 ease-out
     @(_visible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4 pointer-events-none")">
    Content
</div>
```

```css
/* Component.razor.css */
.fade-in { animation: fadeIn 300ms ease-out forwards; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
```

```csharp
// Entry animation via OnAfterRenderAsync
protected override async Task OnAfterRenderAsync(bool firstRender)
{
    if (firstRender) { _animate = true; StateHasChanged(); }
}
```

**GSAP via JS interop** — for simple calls use `JS.InvokeVoidAsync("gsap.to", _element, new { y=0, opacity=1, duration=0.5, ease="power2.out" })`. For complex sequences wrap in a JS module, call via `IJSObjectReference`, dispose in `DisposeAsync()`.

**Blazor.Animate:** `<Animate Animation="Animations.FadeIn" Duration="TimeSpan.FromSeconds(0.3)">`.

**MudBlazor:** `<MudCollapse Expanded="@_expanded">`, `<MudPopover Open="@_open">` — built-in enter/exit transitions.

## Anti-Patterns

- Animating layout properties (`width`, `height`, `top`, `left`) -- forces layout recalc and paint on every frame
- `transition: all` -- animates unexpected properties and breaks future style additions
- Competing uncoordinated animations -- multiple elements fighting for visual attention
- Animating all elements on page load simultaneously -- overwhelming and blocks perceived interactivity
- Missing exit animations for toggled elements -- content disappears instantly, breaking spatial continuity

## Implementation Workflow

1. Detect framework and existing animation patterns
2. Identify purpose: feedback, transition, reveal, or decorative
3. Choose tool: CSS for simple, Framer Motion/GSAP for complex, View Transitions for routes
4. Define timing, easing, and reduced-motion behavior
5. Implement with GPU-friendly properties only
6. Test with DevTools Performance panel
7. Test with `prefers-reduced-motion: reduce`

## Output Format

```
Animation:      name and purpose
Tool:           CSS / Framer Motion / GSAP / View Transitions / framework-native
Trigger:        what initiates the animation
Properties:     which CSS properties are animated
Duration:       exact timing in ms
Easing:         exact curve or spring config
Reduced Motion: alternative behavior
Performance:    compositor-only or trade-offs
```

## Done Criteria

- Animations serve a clear purpose
- Timing responsive: micro-interactions <200ms, transitions <350ms
- Easing matches interaction: ease-out entering, ease-in exiting, spring for gestures
