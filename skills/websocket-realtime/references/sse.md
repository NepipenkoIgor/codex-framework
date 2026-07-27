# Server-Sent Events

Use SSE for one-way server-to-browser delivery when HTTP streaming and repository/proxy capabilities support it. Verify response flushing, buffering, compression, idle behavior and browser client APIs against the deployed path.

- Authenticate the request with the supported cookie, header or bounded ticket mechanism and authorize the requested tenant/resource stream. Native EventSource can use cookies; a custom client is needed only for requirements such as custom headers or nonstandard handling.
- Define versioned event type, stable ID/cursor, data schema, scope, retry/reconnect ownership, retention and error/reset semantics. Validate and encode data without embedding secrets.
- Establish replay and live subscription atomically or through a cursor-safe handoff so events cannot be lost or interleaved across the boundary. If the cursor is outside retention, send an explicit reset/snapshot path rather than unbounded replay.
- Heartbeats are transport liveness aids, not application data. Derive cadence from measured proxy/provider idle limits and handle write failure/abort cleanup.
- Bound per-client backlog and fan-out. Define coalescing, disconnect or snapshot recovery for slow consumers; stop upstream work when the request aborts.
- Do not assume fixed browser connection or HTTP/2 stream limits; verify supported browsers, negotiated protocol and infrastructure constraints.

Verify wrong-tenant stream access, cookie/header expiry and revocation, initial replay/live race, duplicate/gap/out-of-retention cursors, malformed/oversized events, proxy buffering/idle close, slow clients, disconnect cleanup, reconnect storms and deployment drain.
