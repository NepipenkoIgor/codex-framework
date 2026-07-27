---
name: websocket-realtime
description: Implement WebSocket, SSE, SignalR, or Socket.IO transport with explicit authentication, authorization, delivery, ordering, resume, backpressure, and revocation semantics. Use when real-time repository changes are requested; do not use for ordinary request-response APIs or provider-specific LLM streaming.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.3
  argument-hint: "feature, transport and installed stack, auth/tenant/resource model, delivery/order/resume and scale constraints"
---

# WebSocket and Realtime

Implement `$ARGUMENTS` using only the references needed for the selected installed transport:

- [Server-Sent Events](references/sse.md)
- [Node WebSocket](references/nodejs-ws.md)
- [Socket.IO](references/socketio.md)
- [SignalR](references/signalr.md)
- [Frontend integration](references/frontend-integration.md)
- [Binary protocols](references/binary-protocols.md)
- [Collaborative editing](references/collaborative-editing.md)

## Establish the protocol

1. Read instructions, manifests/lockfiles, proxy/LB/runtime config, auth and tenant/resource contracts, existing event schemas, client lifecycle, backplane, and tests.
2. Generate stack context; verify transport/library APIs, browser/proxy/provider limits, heartbeat support, buffering and scale-out behavior against installed capability and matching official docs.
3. Choose SSE for one-way HTTP streaming or WebSocket/SignalR/Socket.IO for bidirectional semantics based on actual needs; fallbacks, rooms, sticky sessions and a backplane are capabilities, not universal requirements.
4. Define message type/version, stable ID, tenant/resource scope, payload limit, validation, delivery guarantee, ordering scope, acknowledgement, resume cursor, retention, and error/close semantics before implementation.

## Security and tenant isolation

- Authenticate during connection establishment or a bounded first-message handshake, then authorize every client message and every join/subscribe/publish against server-side actor, tenant, resource and current permissions. Connection authentication alone is not message authorization.
- Never trust client-sent user/tenant/resource ownership. Namespace and authorize rooms/channels by tenant and resource; prevent guessed joins and cross-tenant backplane fan-out.
- Validate browser Origin where relevant, protect tickets/tokens from URL/log leakage, bound ticket reuse/TTL, use TLS, schema/size/rate limits, and sanitize rendered content.
- Re-evaluate expiry, membership and revocation during long-lived connections. Define forced leave/close and queued-message handling when tokens or permissions are revoked.

## Delivery, flow control, and lifecycle

- Do not promise exactly once. For durable effects use at-least-once delivery plus idempotent server processing/deduplication and persisted outcome; ephemeral presence may use at-most-once.
- Define ordering only within a named scope such as stream/room/aggregate. Use server sequence/version or opaque cursor, detect gaps, and reconcile by bounded replay or authoritative snapshot. Timestamps alone are not a reliable total order.
- Reconnect with bounded jitter and reauthenticate/reauthorize before resume. Derive a bound on total attempts or elapsed time from observed proxy/provider behavior, operation deadlines and product recovery policy; exhaustion becomes an explicit disconnected/recovery state. A cursor outside retention requires snapshot/reset; do not blindly flush stale queued commands.
- Bound per-connection and per-room buffers, inflight acknowledgements and send rate. Specify drop/coalesce/reject/disconnect/load-shed behavior for slow consumers; an unbounded queue is a memory outage.
- Clean up subscriptions on abort/close, detect half-open connections with transport-supported heartbeat, and drain deployments without claiming no message loss unless durable replay proves it.

## Verification and output

Test connect and per-message authorization, wrong-tenant room guesses, token expiry/revocation, malformed/oversized/flood messages, duplicate delivery, injected out-of-order and sequence-gap delivery with detection/reconciliation, disconnect during effect, resume inside/outside retention, reconnect exhaustion, stale queued commands, slow consumers/backpressure, proxy idle timeout, and graceful drain. When the selected deployment is multi-instance, also test backplane/adapter outage, duplicate fan-out, tenant isolation, and deployment compatibility. Verify caller-visible plus persisted outcome for mutations.

Report installed transport capability, auth/tenant/resource contract, protocol/version, delivery/order/resume/retention, backpressure/revocation/reconnect, scale/deploy behavior, executed checks, and residual proxy/provider risk.
