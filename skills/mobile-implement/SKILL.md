---
name: mobile-implement
description: Implement cross-platform mobile features using repository-native patterns for lifecycle, navigation, offline behavior, secure storage, accessibility, and platform adaptation. Use for mobile work whose framework is unknown or spans platforms; use the React Native or Flutter specialization when platform-specific APIs dominate.
metadata:
  version: 2.1
  argument-hint: "platform, feature, lifecycle states, offline/security/accessibility requirements"
  owner: mobile
  reviewed: "2026-07-26"
---

# Mobile Implementation Baseline

This is the universal mobile baseline. It deliberately does not prescribe a router, state library, database, animation engine, or notification provider.

## Discovery

1. Generate project stack context and detect framework, versions, build system, navigation, state, storage, testing, and release conventions. Existing manifests and resolved lockfiles are authority. For greenfield work, resolve stable releases and support from the configured official sources, verify a mutually compatible stack, scaffold through the selected project-creation owner, and then make the scaffold-generated manifest and lockfile authoritative for installed versions and available capabilities; re-check installed types before implementation.
2. Read nearby screens, services, platform configuration, and tests before choosing a pattern.
3. Identify supported OS versions, device classes, orientations, accessibility requirements, and offline expectations.
4. Verify version-sensitive APIs in current official documentation.
5. Before material mutation, resolve exact task-owned app/native/configuration targets, owning team and write authority/permissions, plus effect-appropriate rollback/recovery.

## Invariants

- Model loading, empty, error, retry, offline, background, restored, and permission-denied states where relevant.
- Keep server state, durable device state, ephemeral UI state, and credentials separate.
- Store credentials only in platform-backed secure storage; clear task-relevant session data on logout.
- Derive automated retry attempts and total elapsed time from operation/provider semantics, mobile background-execution windows, queue freshness and observed recovery evidence; after exhaustion expose a durable unresolved/recoverable state rather than inventing constants.
- Validate deep-link and notification payloads before navigation or mutation.
- Handle cold start, foreground, background, interruption, and process restoration.
- Respect safe areas, text scaling, reduced motion, screen readers, keyboard navigation where supported, and platform touch-target guidance.
- Avoid blocking the UI thread and unbounded in-memory lists; paginate and virtualize measured hot paths.
- Preserve repository architecture and dependency choices unless evidence justifies a migration.

## Platform Boundary

Use platform channels or native modules only when the required capability is absent or inadequate in the current framework. Define the typed contract, cancellation/error semantics, lifecycle ownership, and tests before implementing both sides.

## Offline and Sync

Choose explicitly among cache-only, read-through cache, queued writes, and full offline-first sync. Define identifiers, conflict policy, retry/backoff, idempotency, tombstones, and what the user sees when reconciliation fails.

## Workflow

1. Write observable acceptance criteria for supported devices and lifecycle states. Boot or attach to a visible repository-configured simulator, emulator, or device and launch the app early; track exact task-owned target, app/server session, and ports.
2. Extend the existing navigation and state boundaries.
3. Implement the smallest vertical slice with accessible loading/error/empty states.
4. Add persistence or sync only where product behavior requires it.
5. Integrate permissions with contextual explanation and denied-state recovery.
6. Test unit logic, component/widget behavior, platform integration, and one critical end-to-end path.
7. Interact with the visible app throughout implementation and verify on the affected platforms and at least one small and one large layout. Headless/unit/widget checks supplement rather than replace device evidence.

## Verification

- Run the repository's formatter, analyzer/type checker, unit/component tests, and relevant platform build.
- Exercise cold start, background/foreground, offline/reconnect, denial, rotation/resize, and accessibility behavior affected by the change.
- Confirm secrets are absent from logs and insecure storage.
- Report any platform or device state not exercised.

## Output Contract

- Platform/framework and existing conventions used
- Lifecycle, offline, security, and accessibility behavior implemented
- Files and platform configuration changed
- Checks and device/simulator evidence
- Unverified platform states or residual risk
