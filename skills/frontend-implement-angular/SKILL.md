---
name: frontend-implement-angular
description: Implement Angular features using the repository's pinned component, reactive state, DI, routing, forms and rendering conventions. Use for Angular-specific work; do not force API-generation migrations.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
---

# Angular Implementation

Inspect Angular/compiler/Node/TypeScript pins, architecture, DI, templates, forms, RxJS/signals, SSR and tests. Installed compiler/types and official compatibility table are authority; migration uses `ng update` as separate scope.

- Preserve constructor or `inject()` DI according to local style and context; neither is universally required. Never call `inject()` outside a valid injection context.
- Use signals, decorator/signal inputs/outputs, `model`, resources and built-in control flow only when installed capability and design justify them. Do not automatically migrate established code.
- Manage subscriptions/resources with the ownership mechanism supported by the pinned line; `takeUntilDestroyed` is useful but not universal for every observable or already-completing stream.
- Functional/class guards and interceptors follow installed support/repository conventions. A route guard is UI/navigation behavior, never authorization; enforce permissions at server/data boundaries.
- SSR/hydration/event replay/after-render APIs are capability-gated. Guard browser globals and prevent cross-request state.
- Angular 20.2+ animation changes follow pinned docs; do not introduce deprecated packages or remove them without explicit migration.

Verify compiler diagnostics, pinned API support, DI context, teardown, SSR/hydration, route bypass/server auth, forms/accessibility and repository tests. Report migration boundaries and untested render modes.
