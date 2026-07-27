---
name: pwa-implementation
description: Implement installable web applications, service-worker lifecycle, owned caching, offline reads and mutation replay, update UX, and push boundaries. Use when offline/install/update behavior is the primary outcome; do not use for generic performance tuning or notification delivery alone.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "installed framework, offline data classes, cache ownership, mutation semantics, update policy, push scope"
---

# PWA Implementation

For an existing repository, run `python3 scripts/framework-stack-context.py project <path>` and treat manifests, lockfiles, installed types, browser targets, deployment headers, and current service-worker behavior as authority. For greenfield work, resolve the selected framework and production runtime with `python3 scripts/framework-stack-context.py latest <technologies...>`. Do not silently migrate packages. Confirm service-worker, Background Sync, install-prompt, and framework-plugin capabilities in current official documentation and provide fallbacks where browsers differ.

## Invariants

- Namespace caches by application, deployment/channel, schema, and data partition. During activation delete only cache names owned by this application and explicitly retired by its migration policy; never delete another feature's or origin tenant's caches.
- A waiting worker may coexist with pages running the previous bundle. Keep network/storage contracts compatible across that overlap, or require safe page closure/reload before activation. `skipWaiting()` and `clients.claim()` are choices, not defaults.
- Do not put secrets, authorization responses, personalized HTML, or tenant/user-bound data in a shared cache. If offline private data is required, define partitioning, expiry, encryption/threat model, logout/account-switch purge, and server reauthorization.
- Cache only methods and responses whose semantics permit replay. Mutation queues are durable state machines, not cached requests.
- Service-worker code is an origin-wide trust boundary. Constrain routes, request destinations, redirects, credentials, opaque responses, cacheability headers, and storage growth.

## Workflow

1. Inventory scope, existing registrations, route ownership, browser matrix, manifest, cache prefixes, storage schemas, authentication/tenant boundaries, update behavior, and nearby tests.
2. Classify each resource: immutable public asset, navigation shell, public API read, private read, mutation, or never-cache. Define offline freshness and invalidation from product requirements rather than generic durations.
3. Define the worker lifecycle and rollback: install failure, waiting-version compatibility, activation, controlled cleanup, multi-tab update consent, unsaved work, and a kill switch.
4. Implement the smallest compatible primitive: native service worker, installed framework integration, or current plugin verified against the installed framework line. Do not copy package names or configuration from memory.
5. For offline mutations, persist an operation ID, authenticated subject/tenant, ordering key, dependency, payload schema/version, creation time, retry state, and visible status. Reauthorize on replay; use server-side idempotency; preserve required order; bound retries; surface permanent rejection and conflicts for user resolution. Logout or account switch must cancel/quarantine and purge subject-bound work.
6. Treat Background Sync as an enhancement. Replay on foreground/resume when it is absent, denied, or delayed. Do not promise a delivery deadline.
7. Add install/update UI only when the browser exposes the capability. Never infer installability from one non-standard event.
8. Add push only with contextual permission, server-side subscription ownership and revocation, payload minimization, and safe notification navigation.

## Verification

- Install, first control, update while old tabs remain open, activation failure, rollback/kill switch, unsaved form, and multi-tab convergence.
- Offline public/private reads; tenant switch and logout; revoked access; cache-control changes; storage pressure and eviction; foreign cache survival after activation.
- Mutation replay under duplicate delivery, timeout after server commit, dependency ordering, conflict, permanent authorization failure, schema change, and partial queue progress. Prove the persisted server outcome, not merely queue removal.
- Supported browsers with capability absence and foreground fallback; manifest/install UI; accessible offline and update announcements.
- Focused repository tests, production build, browser network/cache inspection, and deployment header/scope verification. Lighthouse can supplement but not prove correctness.

## Output Contract

- Resource/data classification and cache ownership
- Lifecycle, update compatibility, offline replay, auth/tenant, and logout contracts
- Installed capability and official-documentation evidence
- Tests and observed browser outcomes
- Residual unsupported-browser, eviction, deployment, and external-delivery risks

Official foundations: [Service Worker specification](https://w3c.github.io/ServiceWorker/), [MDN CacheStorage](https://developer.mozilla.org/en-US/docs/Web/API/CacheStorage), and [MDN Background Synchronization](https://developer.mozilla.org/en-US/docs/Web/API/Background_Synchronization_API).
