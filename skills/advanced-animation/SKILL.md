---
name: advanced-animation
description: Implement advanced animation and visual effects including Lottie integration (After Effects to web), Three
metadata:
  version: 1.6
  argument-hint: "animation type (Lottie/Three.js/CSS/Canvas/SVG), framework (React/Vue/Angular), trigger (scroll/gesture/load/interaction), performance target (FPS/bundle size)"
---

Implement $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

## Lottie Integration

Pipeline: After Effects → Bodymovin plugin → JSON → lottie-web / lottie-react / lottie-react-native.

```tsx
function SuccessAnimation() {
  const prefersReducedMotion = useReducedMotion();
  if (prefersReducedMotion) return <CheckIcon className="h-16 w-16 text-green-500" />;
  return <Lottie animationData={checkmarkData} loop={false} style={{ width: 64, height: 64 }} />;
}
```

Controls: `play()`, `pause()`, `stop()`, `goToAndStop(frame)`, `setSpeed()`, `setDirection(-1)`. Events: `complete`, `loopComplete`, `enterFrame`.

Optimization: target <100KB JSON for inline, <500KB for hero. Use `lottie_light.min.js` for SVG-only. Use `renderer: 'canvas'` for complex, `'svg'` for simple. Lazy load animation data.

## Three.js and React Three Fiber

```tsx
function Scene3D() {
  const reduced = useReducedMotion();
  return (
    <Canvas camera={{ position: [0, 2, 5], fov: 45 }} dpr={[1, 2]} style={{ height: 400 }}>
      <ambientLight intensity={0.5} />
      <directionalLight position={[5, 5, 5]} intensity={1} />
      <Float speed={reduced ? 0 : 2} floatIntensity={reduced ? 0 : 0.5}>
        <mesh><boxGeometry args={[1, 1, 1]} /><meshStandardMaterial color="#2563eb" /></mesh>
      </Float>
      <OrbitControls enableZoom={false} autoRotate={!reduced} />
      <Environment preset="studio" />
    </Canvas>
  );
}
```

Loading: `useGLTF` from drei, `useGLTF.preload()`, wrap in `Suspense`. Performance: cap `dpr` at 2, use `.glb`, compress with draco/gltf-transform, use instancing. Check WebGL support, fall back to static image.

## SVG Animation

Stroke drawing: `stroke-dasharray: 1000; stroke-dashoffset: 1000;` animated to `0`. Use `getTotalLength()` for precision.

Morphing: use `flubber` — `interpolate(startPath, endPath)` returns a function taking progress 0–1.

CSS: animate `transform`, `fill`, `opacity`. Use `transform-origin` carefully (SVG origins differ from HTML). Keep SVGs inline for CSS styling.

## Canvas Particle System

```typescript
class ParticleSystem {
  private particles: Particle[] = [];
  private running = false;
  private animationId = 0;

  start() { this.running = true; this.loop(); }
  stop() { this.running = false; cancelAnimationFrame(this.animationId); }

  private loop = () => {
    if (!this.running) return;
    this.update(); this.draw();
    this.animationId = requestAnimationFrame(this.loop);
  };

  emit(x: number, y: number, count: number) {
    for (let i = 0; i < count; i++) {
      this.particles.push({
        x, y, vx: (Math.random() - 0.5) * 4, vy: (Math.random() - 0.5) * 4 - 2,
        size: Math.random() * 3 + 1, life: 1, decay: Math.random() * 0.02 + 0.01,
        color: `hsl(${Math.random() * 60 + 30}, 100%, 60%)`,
      });
    }
  }
}
```

Use `requestAnimationFrame`, never `setInterval`. Limit to 200–500 particles. Scale canvas by device pixel ratio. Always provide `stop()`/cleanup on unmount. Pause when off-screen.

## Scroll-Driven Storytelling

```typescript
gsap.registerPlugin(ScrollTrigger);

gsap.timeline({
  scrollTrigger: { trigger: '.feature-section', start: 'top top', end: '+=300%', pin: true, scrub: 0.5 },
})
  .to('.feature-1', { opacity: 1, y: 0, duration: 1 })
  .to('.feature-1', { opacity: 0, duration: 0.5 }, '+=0.5')
  .to('.feature-2', { opacity: 1, y: 0, duration: 1 });
```

CSS Scroll Timeline: `@supports (animation-timeline: scroll()) { .progress { animation: grow linear; animation-timeline: scroll(); } }`

Rules: use `scrub` for scroll-linked. Parallax max 50–100px. Never hijack scrolling. Disable on mobile with `matchMedia`. Animate only `transform`/`opacity`.

## Page Transitions

**FLIP**: record First position, execute DOM change, record Last position, apply Invert transform, Play to identity over 300ms ease-out.

**View Transition API**:
```typescript
document.startViewTransition(async () => { await router.push(url); });
```
```css
.product-image { view-transition-name: product-hero; }
::view-transition-old(root) { animation: fade-out 150ms ease-in; }
::view-transition-new(root) { animation: fade-in 200ms ease-out; }
```
Keep under 300ms total. Fall back to simple crossfade. Disable for `prefers-reduced-motion`.

## Gesture-Driven Animation (Mobile)

```typescript
function DraggableCard() {
  const translateX = useSharedValue(0);
  const translateY = useSharedValue(0);

  const gesture = Gesture.Pan()
    .onUpdate((e) => { translateX.value = e.translationX; translateY.value = e.translationY; })
    .onEnd(() => { translateX.value = withSpring(0); translateY.value = withSpring(0); });

  const style = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }, { translateY: translateY.value }],
  }));

  return <GestureDetector gesture={gesture}><Animated.View style={[styles.card, style]} /></GestureDetector>;
}
```

Spring config: stiffness 100–300 for UI, 50–100 for large drags. Damping 10–20 for quick settle, 5–10 for bouncy. Use `withDecay` for fling gestures.

## Performance Budgets

| Type | Target FPS | Max Bundle |
|------|-----------|------------|
| CSS transitions | 60fps | 0KB |
| Framer Motion | 60fps | ~30KB gzipped |
| Lottie | 60fps | ~20KB + JSON |
| GSAP + ScrollTrigger | 60fps | ~25KB gzipped |
| Three.js | 60fps | ~150KB gzipped |

Measure in DevTools Performance panel; zero frames >16.6ms. Test on mid-range Android.

## Progressive Enhancement

```
Level 1 (No JS / Reduced Motion): static content, instant state changes
Level 2 (CSS Only): transitions, keyframes, spinner, shimmer
Level 3 (Lightweight JS): Framer Motion, IntersectionObserver, View Transitions
Level 4 (Advanced): Lottie, ScrollTrigger, Canvas effects
Level 5 (Heavy): Three.js, gesture animation, shaders
```

Each level must work without levels above. Lazy load Level 4–5 assets.

## Reduced Motion (Mandatory)

```typescript
function useReducedMotion(): boolean {
  return useSyncExternalStore(
    (cb) => { const mq = matchMedia('(prefers-reduced-motion: reduce)'); mq.addEventListener('change', cb); return () => mq.removeEventListener('change', cb); },
    () => matchMedia('(prefers-reduced-motion: reduce)').matches,
    () => false
  );
}
```

Per type: CSS — near-zero duration, keep opacity. Lottie — static final frame or icon. Three.js — stop rotation, static scene. Canvas — do not render. Scroll — disable, show all content. Gestures — keep functional, remove decorative spring.

## Framework-Specific Patterns

**Angular — `@angular/animations`**: use `trigger`, `transition`, `animate`, `state`, `stagger`. Run all animation loops in `NgZone.runOutsideAngular()` to prevent unnecessary change detection. Use `ChangeDetectionStrategy.OnPush` on heavy-animation components.

Angular GSAP: wrap in `gsap.context(() => {...}, containerEl)` inside `ngAfterViewInit`, call `ctx.revert()` in `ngOnDestroy`.

Angular Lottie: `ngx-lottie` with `LottieModule.forRoot({ player: playerFactory })`.

Angular Three.js: `angular-three` (NGT) with `NgtCanvas`, `NgtsOrbitControls`, `NgtsFloat`.

**Vue — `<Transition>` / `<TransitionGroup>`**: use `mode="out-in"`, stagger via `@before-enter`/`@enter` hooks. `@vueuse/motion` for declarative motion. GSAP: composable pattern with `gsap.context()` in `onMounted`, `ctx.revert()` in `onUnmounted`. Mark GSAP instances with `markRaw()`, use `shallowRef` for Three.js objects. TresJS for Three.js. Nuxt: `pageTransition` / `layoutTransition` in `definePageMeta` or `nuxt.config.ts`.

**Svelte**: built-in `fade`, `fly`, `slide`, `scale`, `draw` transitions compile to vanilla JS. `svelte/motion` tweened + spring stores (~2KB). `animate:flip` for list reordering. GSAP via Svelte action pattern for scoped cleanup. SvelteKit: `onNavigate` + `document.startViewTransition` for page transitions.

**Blazor**: CSS transitions via Tailwind class toggling — zero interop cost. GSAP/Lottie/Three.js via `IJSObjectReference` module imports. Call `init()` once in `OnAfterRenderAsync`, let JS handle all frames. Batch animation params in a single interop call. Dispose in `DisposeAsync`.

**React / Next.js**: `<AnimatePresence mode="wait">` in layout for page transitions. `next/dynamic` with `ssr: false` for Three.js. Use `useDeferredValue` for non-urgent UI alongside heavy animations. Mark animation components `'use client'`.

## Anti-Patterns

- Canvas or WebGL running off-screen without visibility detection -- GPU work continues when invisible
- Multiple competing `requestAnimationFrame` loops -- each adds frame budget pressure independently
- Heavy animations on the critical render path -- delays LCP and blocks Time to Interactive
- No WebGL fallback -- blank canvas on unsupported devices with no degraded experience
- Lottie file larger than the surrounding page content -- animation payload exceeds its visual value

## Output Format

```
Effect:            [name and description]
Tool:              [CSS / Lottie / Three.js / GSAP / Canvas / Reanimated]
Progressive Level: [1-5]
Trigger:           [scroll / gesture / state / load / interaction]
Performance:       [FPS target, bundle cost]
Reduced Motion:    [alternative behavior]
Fallback:          [unsupported technology fallback]
```

Done: ✓ 60fps on mid-range devices ✓ reduced-motion alternative for every animation ✓ core works without animation ✓ heavy assets lazy loaded ✓ feature detection for advanced APIs ✓ loops cleaned up on unmount ✓ bundle within budget ✓ fallback when unsupported
