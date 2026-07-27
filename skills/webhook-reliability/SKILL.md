---
name: webhook-reliability
description: Implement or review incoming and outgoing webhooks with raw-body signature verification, replay defense, durable idempotency, ordering, retries, secret rotation, provider ambiguity, dead-letter and authorized replay. Use for HTTP event delivery; do not use for ordinary synchronous APIs.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.1
  argument-hint: "direction/provider and pinned SDK, event/schema, signature/rotation/replay, delivery/idempotency/ordering SLO"
---

# Webhook Reliability

Read [the full provider and implementation guide](references/full-guide.md) only for the selected provider/stack.

1. Capture authoritative provider contract and installed SDK/runtime: exact raw bytes, signature header/algorithm, timestamp/tolerance, multiple signatures/secrets during rotation, retry/timeout/order and event identity semantics.
2. Verify signature over untouched raw body before parsing/decompression/transformation; bound body size and timestamp/replay window. Compare signatures safely and avoid logging secrets/raw sensitive payloads.
3. Authenticate endpoint/provider and authorize referenced tenant/resource independently of payload ownership fields. Support overlapping old/new secrets and auditable revocation.
4. Atomically claim stable provider event or delivery identity before side effects. Provider/client timeout may follow commit/effect; reconcile stored/provider outcome rather than assuming failure. Define dedupe retention and same-ID/different-payload conflict.
5. Return according to provider acknowledgement contract after durable acceptance. Process slow work asynchronously with bounded retry, poison/DLQ and authorized exact replay. Ordering is scoped and gaps/stale events need version/reconciliation behavior.
6. For outgoing webhooks, persist outbox intent atomically, protect destination registration from SSRF, sign versioned payloads and distinguish transient/permanent delivery failures.

Preserve parsing and handling for every event/schema version the configured provider may still redeliver or replay through the supported retention horizon. A move to the provider's current API, webhook version or SDK behavior is a separate compatibility migration with old-event fixtures and rollout evidence.

Test raw-body mutation, malformed/expired/rotated signatures, replay/concurrent duplicates, same ID conflict, wrong tenant/resource, timeout-after-effect, 4xx/5xx/network ambiguity, reorder/gap, schema evolution, DLQ/replay and secret rotation. Report signature/event/idempotency/order/retry contracts, evidence and residual provider risk.
