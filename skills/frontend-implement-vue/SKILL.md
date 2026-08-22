---
name: frontend-implement-vue
description: Implement Vue or Nuxt features using the repository's pinned component, state, routing and SSR conventions. Use for Vue-specific work; preserve established Options API and JavaScript unless migration is requested.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
---

# Vue Implementation

Inspect Vue/Nuxt manifests, lockfile, SFC style, JS/TS usage, router/store/SSR conventions and tests. Use only APIs exposed by installed Vue/Nuxt/types. Explicitly check each applicable relationship among runtime engine ranges, dependency peers, Vue/Nuxt/compiler coupling, test runner and deployment runtime; mark absent or unavailable dimensions rather than replacing them with a generic compatibility claim. Before material mutation, resolve exact task-owned targets, owner and write authority/permissions plus effect-appropriate rollback/recovery.

- Preserve established Options API, Composition API, JavaScript or TypeScript style. Do not convert working components as incidental modernization.
- Keep props readonly, emit explicit, computed values pure and watchers/effects scoped with cleanup. Use composables for cohesive reusable behavior, not every function.
- SSR state, stores and clients must be created per request; never leak a mutable singleton between users. Serialize only authorized data and verify hydration.
- Use `<script setup>`, macros, reactivity transform, Suspense, server utilities and Nuxt data APIs only when installed capability and repository convention support them.
- UI route guards improve navigation but never replace server authorization.

Verify request isolation, hydration, navigation/unmount cleanup, stale async results, Options/Composition interoperability, JS/TS build, accessibility and repository tests. Require caller-visible or persisted outcome evidence for material mutations; configuration or command success alone is insufficient. Report capability evidence, exact changes and checks, migration boundaries, unresolved external/provider/browser paths and residual SSR, authorization or compatibility risk.
