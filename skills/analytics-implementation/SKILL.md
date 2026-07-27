---
name: analytics-implementation
description: Implement provider-neutral product analytics from an approved tracking plan, including typed events, identity transitions, consent enforcement, deduplication, server authority, and delivery evidence. Use for requested repository changes; do not use for analytics strategy or error tracking.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "approved tracking plan, provider/transport, identity lifecycle, consent policy, verification access"
---

# Analytics Implementation

## Workflow

1. Inspect the approved tracking plan/schema registry, metric ownership, identity and tenant lifecycle, consent/legal policy, provider/transport configuration, server domain events, existing wrapper, manifests/lockfiles, data residency/retention and verification surfaces. Before material mutation, resolve the exact repository/provider targets, their owners and permissions, and the rollback/reconciliation path for each affected boundary. Do not invent naming conventions, event counts, property limits or frameworks.
2. Define each event once with stable event name/version, semantic trigger, authoritative producer, subject/tenant, immutable event ID, occurrence time, allowed properties/types/classification, consent purpose, destinations, retention and downstream migration policy. Generate provider mappings at the adapter boundary rather than conflicting Title Case/snake_case taxonomies.
3. Track irreversible or money/security/authorization outcomes from committed server/domain events or a transactional outbox, not from clicks or optimistic UI. Client interaction events may describe intent, never final business truth.
4. Make server/outbox delivery idempotent by immutable event ID. Classify retries and partial destination results, persist delivery attempts where the contract requires it, and reconcile timeouts. Provider acceptance is not proof of downstream query availability or exactly-once processing.
5. Model anonymous, authenticated, account switch, logout, merge/link and tenant/group transitions explicitly. Keep anonymous and known IDs separate until approved linking; reset all user/group/session state on logout/switch. Never assume a provider's `identify` automatically merges historical data.
6. Enforce consent and data-use policy before SDK initialization, collection and destination forwarding when the approved legal policy requires it. Purpose, withdrawal, region, age, GPC/DNT and necessary-processing exceptions are accountable policy decisions, not universal booleans.
7. Minimize properties. Do not send raw or hashed email as a default privacy technique: hashing predictable identifiers remains linkable/personal data and may violate destination policy. Exclude secrets, tokens, free text and unnecessary URLs/IP/device data.

## Lifecycle and Delivery

Use lifecycle APIs supported by the installed platform. Browser `beforeunload` is unreliable and cannot prove abandonment; derive funnels from durable step events/session expiry or use supported beacon/background delivery only as best-effort interaction telemetry. Mobile background/termination delivery is also capability-dependent.

Validate schema before enqueue and at ingestion; quarantine incompatible versions rather than silently reshaping them. Use bounded queues, backpressure and explicit loss policy. Derive retry attempt and elapsed-time bounds from provider delivery semantics, request/job deadlines, queue capacity, event freshness and observed delivery evidence; persist a terminal or operator-visible unresolved state after exhaustion. Prevent retry storms and analytics from blocking product-critical requests.

## Verification

Test duplicate source event, timeout-after-accept, out-of-order identity events, anonymous-to-known transition, logout/account/tenant switch, consent absent/withdrawn/changed, ad blockers/offline/background close, malformed or PII-bearing properties, server rollback, partial destination failure and schema evolution.

Verify network/request payload, persisted outbox/delivery state, provider debugger or ingestion response, and downstream query/debug evidence where available. Report the highest boundary actually observed; do not claim delivery from a wrapper call or browser console alone. Use task-owned browser sessions and close only sessions started for this test.

## Output

Report tracking-plan/version changes, event authority/schema, identity and consent transitions, minimization, provider adapter/dedupe, delivery evidence by boundary, executed checks, and unresolved legal/provider/data-quality risks.
