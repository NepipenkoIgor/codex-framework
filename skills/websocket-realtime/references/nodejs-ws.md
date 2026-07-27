# Node WebSocket runtime

Use only the repository's installed WebSocket server and Node runtime APIs. Confirm upgrade hooks, payload limits, compression, ping/pong, drain and proxy behavior from local types and matching official documentation.

- Authenticate and validate Origin or a bounded first-message ticket at establishment, then authorize every message, join, leave and publish against current server-side actor, tenant and resource state.
- Parse inside an error boundary after checking frame/message size. Validate a versioned schema and reject unsupported types without exposing internal details.
- Derive rooms/subscriptions on the server; never trust a client-provided room or tenant as authority. Re-check permission expiry/revocation during the connection.
- Bound per-socket queues and buffered bytes. Define drop/coalesce/reject/disconnect behavior and pause upstream producers where supported.
- Heartbeat/half-open detection, reconnect and resume follow measured proxy/runtime behavior, not fixed intervals.
- For multiple instances, choose sticky routing, durable replay or an authenticated tenant-isolated backplane only when deployment evidence requires it.
- On shutdown, stop new upgrades, notify/drain within an owned deadline, persist/reconcile consequential inflight effects, then close.

Verify malformed/oversized frames, wrong-tenant joins and publishes, token expiry/revocation, duplicate handlers, slow consumers, half-open sockets, reconnect inside/outside retention, and deployment drain. When the selected deployment is multi-instance, also verify fan-out isolation, backplane failure behavior, and deployment compatibility.
