---
name: in-app-notifications
description: Implement an in-product notification inbox or activity feed with unread state, preferences, deduplication, deep links, retention, and real-time updates. Use when notification state inside the product is primary; do not use for APNs/FCM/Web Push delivery or transactional email infrastructure.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 1.0
  argument-hint: "events, recipients, inbox UX, read state, preferences"
---

## Workflow

1. Inspect instructions, manifests/lockfiles, ORM/schema and generated client/types, database/runtime capability, authoritative domain events, recipient authorization, tenant model, UI patterns, preferences, real-time transport, retention, migrations/tests and analytics. Preserve pins, verify installed capability from generated artifacts/runtime evidence plus matching documentation, and treat ORM/framework migration separately.
2. Define notification types, immutable event identity, recipient snapshot or rule, visibility, deduplication, priority, deep-link authorization, expiry, and preference exceptions.
3. Create notifications durably from transactional events/outbox. Make replay idempotent and unread/read updates concurrency-safe; never trust a client-supplied recipient or deep-link target. Before schema or production mutation, define expand/contract compatibility, rollback or forward-fix, event replay/reconciliation and caller-visible recovery; do not treat migration command success as recovery proof.
4. Implement accessible loading/empty/error/unread states, keyboard behavior, batching, pagination, mark-one/all-read, and optional live updates with reconnect reconciliation.
5. Test duplicate/out-of-order events, cross-tenant reads, deleted targets, preference changes, concurrent read state, retention, reconnect, and accessibility.

## Output

Report event and recipient authority, schema/state transitions, preference and retention rules, UI/accessibility behavior, idempotency/reconciliation, checks, analytics, and residual delivery risk.
