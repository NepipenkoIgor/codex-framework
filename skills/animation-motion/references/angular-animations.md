# Angular Motion

Inspect the installed Angular compiler/core and existing providers before selecting an API.

- Angular 20.2 deprecated `@angular/animations` and introduced `animate.enter` / `animate.leave`. On a capable installed line, prefer those compiler primitives with native CSS or typed JS callbacks. Follow the [official migration guide](https://angular.dev/guide/animations/migration).
- Do not mix legacy triggers and `animate.enter`/`animate.leave` in one component, including incompatible content-projection boundaries. Keep a legacy pinned component intact until its migration is in scope.
- Leave callbacks must signal completion through the documented installed API so Angular can remove the element. Reduced motion, cancellation and test environments must reach the same final DOM and cleanup state.
- Keep class/keyframe names component-scoped where possible. Import third-party animation code as modules; do not use evaluated strings or weaken CSP.
- Verify installed TestBed animation controls. Unit environments may not emit native animation events; use browser tests for lifecycle timing and visual behavior.

Official sources: [enter/leave animations](https://angular.dev/guide/animations) and [migration from legacy animations](https://angular.dev/guide/animations/migration).
