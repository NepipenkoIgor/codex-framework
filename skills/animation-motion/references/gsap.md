# GSAP Patterns

## Timeline

```typescript
import { gsap } from 'gsap';

const tl = gsap.timeline({ defaults: { ease: 'power2.out', duration: 0.3 } });

tl.from('.hero-title', { y: 30, opacity: 0 })
  .from('.hero-subtitle', { y: 20, opacity: 0 }, '-=0.15')
  .from('.hero-cta', { y: 20, opacity: 0 }, '-=0.15')
  .from('.hero-image', { scale: 0.95, opacity: 0 }, '-=0.2');
```

## ScrollTrigger

```typescript
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
gsap.registerPlugin(ScrollTrigger);

gsap.from('.section', {
  scrollTrigger: {
    trigger: '.section',
    start: 'top 80%',
    end: 'top 20%',
    scrub: false,
  },
  y: 40,
  opacity: 0,
  duration: 0.5,
  stagger: 0.1,
});
```

## Usage Guidelines

- Use GSAP for complex multi-element sequences that CSS cannot handle
- Use GSAP for scroll-driven animations with precise trigger control
- Clean up GSAP instances on component unmount -- use `gsap.context()` for scoped cleanup
- Prefer CSS transitions for simple state changes -- GSAP is overhead for basic hover effects

## Reduced Motion

```typescript
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
if (prefersReducedMotion) {
  gsap.globalTimeline.timeScale(20); // effectively instant
}
```
