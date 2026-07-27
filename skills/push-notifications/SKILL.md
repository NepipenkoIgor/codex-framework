---
name: push-notifications
description: Implement push delivery across the repository's installed mobile or web stack, including token ownership, preferences, idempotency, provider outcomes, and safe deep links. Use for requested repository changes; do not use for notification strategy alone or treat push as guaranteed delivery.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "platforms, providers, event categories, ownership, delivery evidence"
---

# Push Notifications

## Workflow

1. Read repository instructions, manifests, lockfiles, provider configuration, identity model, event schema, privacy rules, and tests. Generate project stack context before selecting APIs and check runtime engine constraints, peer dependencies, compiler/framework, native/mobile/web adapter, test runner and deployment runtime together. Preserve installed SDK pins; for greenfield work resolve current stable/LTS versions at execution time from configured official sources, verify cross-stack capabilities, then treat the generated manifest and lockfile as authority. Before material registration/delivery mutation, resolve exact targets, owner and write authority/permissions, plus transfer/disable/reconciliation recovery or rollback.
2. Define the event contract before payloads: immutable event/notification ID, recipient subject, tenant, app, environment, provider, category, locale, expiry, collapse policy, and authorization context.
3. Model a registration as one provider endpoint owned by at most one active `(subject, tenant, app, environment, provider)` assignment. Re-registration transfers ownership transactionally; logout disables only the matching assignment if its generation still matches. Never key ownership by user plus token alone.
4. Authenticate registration and prove app/device context as supported. Store token material as sensitive data, avoid logs/analytics, rotate on provider refresh, and make unregister/reassignment idempotent. Define cleanup from current provider responses and product policy, not remembered age limits.
5. Create a durable delivery record keyed by notification ID and endpoint assignment. Claim work safely, send with an idempotent application contract, and record every per-endpoint provider result. A batch API success is not proof that every endpoint succeeded.
6. Classify provider responses using the installed SDK/current official contract: terminal endpoint invalidation, retryable throttling/transient failure, authentication/configuration failure, and payload/policy rejection. Bound retries, honor provider retry guidance, and preserve partial outcomes.
7. Resolve priority, TTL, interruption level, mutable content, background/silent behavior, payload size, topic/condition support, and action limits from current capabilities and the product use case. Do not default to high priority, mutable content, or a fixed cap.
8. Apply consent, category preferences, quiet hours, timezone behavior, frequency policy, and legally required exceptions from an explicit product/compliance contract. Do not hardcode that any category always bypasses user preferences.

## Identity, Dedupe, and Races

- Reject or serialize concurrent register, refresh, logout, and account-switch operations with assignment generations or compare-and-swap semantics.
- Before each send, re-evaluate endpoint ownership and recipient authorization. A token formerly owned by account A must not receive account A data after assignment to B.
- Deduplicate the originating business event and each endpoint delivery separately. Provider message IDs aid reconciliation but are not the business idempotency key.
- Store minimal payloads; fetch sensitive content after authenticated app open when practical.

## Deep Links

Send a typed action identifier plus opaque resource ID, not an arbitrary executable URL. On open, map it through an allowlisted route table, validate scheme/host/path, restore authentication, reauthorize the resource server-side, and use a safe default for invalid or stale actions. Verify cold start, background, foreground, logged-out return, account mismatch, duplicate taps, and a link for a resource the user no longer owns.

## Verification

Test endpoint transfer from A to B racing with A logout; token refresh; duplicate source events; provider timeout; mixed success/failure batch; invalid endpoint; throttling; expired event; preference and quiet-hour boundaries; malicious deep link; and disabled notifications. Assert durable per-endpoint state and caller-visible behavior. Use sandbox/provider test environments where available and label paths not exercised with real provider credentials.

Return changed contracts/files, ownership model, policy decisions, provider/version evidence, executed tests, partial-result evidence, operational alerts, and residual external risks. Never equate accepted-by-provider with delivered or opened.
