# Webhook provider and implementation notes

Load this reference only after selecting the incoming or outgoing provider path. The provider's current documentation, installed SDK/types, raw-request behavior, and repository contracts remain authoritative.

## Incoming contract

- Record the exact signed bytes, signature header and encoding, algorithm, timestamp/replay semantics, secret-selection and rotation behavior, event identifier, acknowledgement contract, retry classes, ordering scope, and event retrieval API.
- Preserve raw bytes before any parsing, decompression, transcoding, newline normalization, or framework middleware. Bound the body before verification.
- Use the provider SDK verifier only when the installed version supports the observed signature format. Otherwise implement the documented algorithm with safe comparison and test vectors; never guess a shared recipe.
- Accept overlapping current/previous secrets only for an explicit rotation window. Determine timestamp tolerance and dedupe retention from provider behavior, outage/replay requirements, and storage policy rather than a corpus constant.
- Atomically claim the provider event identity and store payload hash/version before effects. Treat the same identifier with different bytes as a conflict requiring investigation.
- Acknowledge only after the provider-required durable boundary. Slow work moves to a durable queue; handler timeout after commit remains an ambiguous outcome to reconcile.

## Outgoing contract

- Create delivery intent in the same authoritative transaction as the source change or through an equivalent durable handoff.
- Register destinations through authenticated tenant/resource authorization. Apply an explicit egress policy that handles scheme, credentials, DNS rebinding, redirects, private/link-local/metadata ranges, port policy, and re-resolution at connection time.
- Version the envelope and signature input. Preserve overlapping verification during rotation without exposing secrets in payloads, logs, tracing, or support output.
- Classify response and transport failures from the consumer contract. Retry only ambiguous/transient delivery with bounded jitter, total deadline, attempt budget, and idempotent delivery identity. Provider or product evidence determines values.
- Scope ordering to a named stream or aggregate. If strict order blocks a poison event, define skip, quarantine, replay, and reconciliation authority explicitly.

## Replay and verification

Replay creates a new auditable delivery attempt linked to the original event; it does not rewrite history. Require authorization, reason, exact target, schema compatibility, effect safety, and a bounded range.

Test official signature vectors, raw-body mutations, malformed and rotated signatures, replay/concurrent duplicates, identifier/hash conflict, wrong tenant/resource, acknowledgement timeout after durable acceptance, retry classification, poison/DLQ behavior, ordering gaps, SSRF/redirect/DNS changes, schema evolution, and authorized replay. Verify persisted business outcome as well as delivery state.
