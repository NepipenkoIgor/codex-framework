# Realtime frontend integration

Use only the installed framework and transport capability. Confirm client APIs, SSR behavior, proxy/runtime support and cleanup semantics from manifests, types and matching official documentation; do not apply a remembered React, Vue, Nuxt, Angular, SignalR or browser recipe.

## Client lifecycle

- Model connection state explicitly: idle, connecting, authenticated, live, reconnecting, resynchronizing, degraded and closed. Do not equate an open socket with an authorized or current view.
- Establish identity with the repository's supported cookie, header, subprotocol or short-lived ticket mechanism. Avoid durable bearer secrets in URLs, logs or persisted browser storage.
- On reconnect, reauthenticate and reauthorize subscriptions before resume. Send the last authoritative cursor/version, detect gaps, and choose bounded replay or snapshot/reset according to retention.
- Keep outbound commands separate from ephemeral UI events. Give consequential commands stable operation identity and reconcile ambiguous timeout; do not blindly flush a stale in-memory queue.
- Bound inbound render work and outbound buffers. Coalesce replaceable state, preserve required events, and surface overload/resync rather than allowing memory growth.

## Framework ownership

- Create one connection owner at the appropriate application/session boundary; components subscribe through existing state primitives. Avoid one transport per render or component instance.
- Register and remove handlers symmetrically. Abort connection/retry work on logout, tenant switch, navigation boundary or unmount as the product contract requires.
- Marshal updates through the framework's installed scheduler/reactivity capability. Avoid stale closures, mutation outside the supported state model, and callbacks after disposal.
- SSR must not create a browser transport on the server. Define hydration/fresh-load state, initial authoritative snapshot and duplicate-event handling.
- Long-lived clients must react to token expiry, permission revocation, removed membership and server-driven resync/close.

## Verification

Test clean first load, navigation and remount, duplicate handler prevention, logout/tenant switch, offline/online, reconnect storms with controlled jitter, resume inside and outside retention, wrong-tenant subscription, revocation, duplicate/out-of-order/gap events, stale queued commands, slow rendering, background/foreground behavior, proxy idle closure and deployment drain. Measure UI state plus authoritative persisted outcome for mutations.
