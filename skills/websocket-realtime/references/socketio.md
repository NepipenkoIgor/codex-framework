# Socket.IO runtime

Use only installed Socket.IO server/client and adapter APIs. Confirm namespace middleware, recovery, acknowledgement, transport and adapter behavior from pinned types and matching official documentation.

- Install authentication on the exact namespace that accepts connections. Store only verified actor context; authorize every event, room join/leave and publish against current tenant/resource permissions.
- Validate versioned event envelopes and bound payload size, event rate, acknowledgements and inflight operations. Do not spread untrusted objects into server events.
- Derive opaque room names on the server. Client-provided room/tenant IDs are lookup claims, never authorization.
- An acknowledgement confirms only the defined handler boundary; it does not prove exactly-once delivery or persisted business effect. Use stable operation identity, idempotent processing and authoritative status for consequential commands.
- Reconnect/recovery must reauthenticate, restore authorized subscriptions, detect gaps and use bounded replay or snapshot. Timestamps alone are not ordering.
- Add a Redis or other adapter only for verified multi-instance needs and test tenant isolation, outage, duplicate fan-out and deployment compatibility.

Verify namespace auth, wrong-room/tenant events, revocation, invalid/flood payloads, duplicate/ambiguous commands, disconnect during effect, and reconnect inside/outside retention. When a multi-instance adapter is selected, also verify adapter outage, duplicate fan-out, tenant isolation, and deployment compatibility.
