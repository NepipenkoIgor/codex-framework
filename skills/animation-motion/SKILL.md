---
name: animation-motion
description: Implement purposeful UI motion, enter/leave lifecycles, gestures, and view transitions with reduced-motion and performance safeguards. Use when motion behavior is primary; do not use for general frontend implementation or accessibility remediation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "state change and purpose, installed framework/library, lifecycle owner, reduced-motion behavior, browser targets"
---

# Animation and Motion

Generate stack context with `python3 scripts/framework-stack-context.py project <path>` and inspect the manifest/lockfile, installed framework/compiler and animation-library APIs/types, motion tokens if they actually exist, component lifecycle, runtime/browser targets, CSP, SSR adapter/hydration, accessibility preferences and test environment as one compatibility chain. Existing pins are authority; use `python3 scripts/framework-stack-context.py latest <technologies...>` only for greenfield selection. Capability-gate framework and browser primitives and keep a behaviorally correct fallback; never invent repository tokens or capabilities absent from evidence.

Load only the selected implementation reference:

- Angular: [angular-animations.md](references/angular-animations.md)
- Motion for React: [framer-motion.md](references/framer-motion.md)
- GSAP: [gsap.md](references/gsap.md)
- Svelte: [svelte-transitions.md](references/svelte-transitions.md)
- View Transitions: [view-transitions-api.md](references/view-transitions-api.md)
- Vue: [vue-transitions.md](references/vue-transitions.md)

## Invariants

- Motion communicates state, causality, continuity or feedback. Keep timing/easing/distance in repository tokens or measured interaction requirements; do not impose universal milliseconds, frame-rate promises or spring constants.
- Transition only named properties. Never use `transition: all`; validate layout/paint cost rather than assuming every transform, opacity or filter is compositor-only.
- Reduced motion changes presentation, not state correctness. Entered content must become visible/interactive; leaving content must complete cleanup/removal; focus, callbacks, promises, inert/hidden state and route completion must not depend on an animation event that will never fire.
- Never execute dynamic animation code with `eval`, `new Function`, string timers or permissive CSP. Use imported modules and typed callbacks; do not weaken CSP for a motion library.
- Prevent animation from intercepting pointer/focus while visually absent, and cancel/cleanup animations, observers, timelines and view-transition names on interruption or unmount.

## Angular Version Boundary

`@angular/animations` is deprecated from Angular 20.2. For an installed line exposing `animate.enter`/`animate.leave`, prefer native CSS/JS integration and plan migration of legacy triggers; do not mix legacy and new animation systems in the same component. Older pinned projects may retain supported legacy APIs until migration is explicitly authorized. Verify leave completion/removal behavior and tests against the installed compiler/runtime.

## Workflow

1. Define state before/during/after motion, ownership, interruption/reversal, initial SSR state, focus/pointer behavior, reduced-motion result, and concrete recovery/rollback for any material behavior touched. Motion must not own or delay a consequential business mutation.
2. Choose the smallest capability: CSS, verified framework primitive, Web Animations, View Transitions or installed library. Use a heavier library only for a demonstrated sequence/gesture need.
3. Specify named properties and repository motion tokens. Avoid layout animation unless the measured UX benefit and performance evidence justify it.
4. Implement cancellation, cleanup and completion independent of visual duration. Capability-gate View Transitions and browser APIs.
5. Verify normal, reduced, interrupted, rapid/repeated, background-tab and hydration paths with actual component lifecycle.

## Verification

- Enter/leave/reversal, removal, focus, pointer hit-testing, route/history, rapid toggles, unmount and exception cleanup. When motion presents a consequential operation, prove the authorized/idempotent mutation's persisted outcome and rollback/error state independently of animation callbacks.
- Reduced-motion preference before load and changed at runtime; final state and callbacks identical except presentation.
- Supported browsers/devices, no-JS/unsupported capability fallback, SSR hydration and CSP with no unsafe evaluation.
- Performance trace for representative content, long lists and concurrent work; layout/paint/composite evidence rather than property folklore.
- Focused unit/component/browser tests and affected build. Visual screenshots alone do not prove lifecycle or accessibility.

## Output Contract

- Motion purpose and state/lifecycle contract
- Selected installed capability/reference and fallback
- Named properties/tokens and reduced-motion behavior
- Test/performance/CSP evidence
- Residual browser, library and device risks

Official sources: [Angular animations migration](https://angular.dev/guide/animations/migration), [Web Animations](https://www.w3.org/TR/web-animations-1/), and [View Transitions](https://www.w3.org/TR/css-view-transitions-1/).
