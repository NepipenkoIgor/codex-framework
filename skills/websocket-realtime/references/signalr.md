# SignalR runtime

Use the installed ASP.NET Core/SignalR client and server capabilities. Verify hub filters, transport fallback, group, streaming, reconnect and scale-out APIs against pinned framework documentation.

- Authenticate connection establishment, but authorize every hub method and resource operation using the current caller and server-loaded tenant/resource. Group membership is routing state, not authorization.
- Construct group names from validated server-owned tenant/resource scope. Reauthorize before add, publish and sensitive stream; remove/close on membership or token revocation.
- Validate method arguments and bound payload, stream items, send rate, inflight work and cancellation. A client-supplied group or user identifier is never authority.
- Automatic reconnect does not restore application subscriptions, ordering or missed state by itself. Reauthenticate, rejoin authorized groups and reconcile with cursor/version or snapshot.
- Add a backplane/service only for demonstrated multi-instance fan-out, with tenant isolation, failure behavior and deploy compatibility.
- Hub completion/acknowledgement is not exactly-once business delivery. Consequential effects need operation identity, server idempotency and persisted outcome reconciliation.

Verify cross-tenant method/group access, revocation, malformed/oversized/flood calls, cancellation, duplicate commands, reconnect/rejoin and missed-state recovery, and graceful deployment drain. When the selected deployment is multi-instance, also verify scale-out isolation, backplane/service outage, and deployment compatibility.
