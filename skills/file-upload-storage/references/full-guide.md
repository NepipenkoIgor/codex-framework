# Upload and storage provider notes

Load this reference only for the selected provider and installed SDK/runtime. Discover current multipart, conditional-write, checksum, encryption, signed-access, lifecycle, event, and deletion capabilities from installed types/CLI help and matching official documentation.

## Choose the transfer boundary

- Mediated upload is useful when the application must inspect the stream before storage; direct signed upload is useful for large payloads but still requires server-authorized object scope and an authenticated, idempotent completion step.
- Derive opaque object keys on the server from authoritative tenant/resource identity. Preserve a sanitized display name separately; never interpolate a client path or filename into authority.
- Bind signed capability to the narrowest supported object, method, content constraints, checksum and expiry. Values come from workload, threat model, network conditions, provider limits and product policy, not shared defaults.
- For multipart/resumable transfer, persist upload identity and expected object contract, validate every completion, make completion idempotent, and abort/reconcile abandoned parts.

## Validation and processing

1. Enforce streaming byte/count/time and tenant quota limits before unbounded buffering or parsing.
2. Compare declared type, extension, magic bytes and decoded structure as risk requires. Treat mismatches, polyglots, archives, active content and parser failures as untrusted.
3. Keep new objects private/quarantined until required malware, content and transformation checks finish. Authenticate callbacks and bind them to object version/checksum; duplicate or stale callbacks are no-ops.
4. Apply metadata removal, image transcoding, document sanitization or archive expansion only when the product/privacy threat model requires it. Preserve legally or functionally required metadata deliberately; no format-wide rule is universal.
5. Publish or derive content under a new immutable identity where practical. If identity is mutable, define cache invalidation and stale signed-link behavior explicitly.

## Access and lifecycle

- Authorize actor, tenant, resource, object version and operation before download or signed-link issuance. A valid object key or signed URL is not proof of application ownership.
- Select response disposition, content type, CSP/sandbox and separate serving origin according to active-content risk.
- Define encryption/key ownership, audit, retention, legal hold, erasure, versioning, replication and regional constraints. Lifecycle rules must not delete held or still-referenced objects.
- Reconcile object and metadata state after timeout, duplicate completion, orphan upload, processing failure, replacement and deletion. Use provider inventory/events as evidence, not as unquestioned authority.

Verify wrong-tenant/key guessing, signed-scope and expiry, oversized/aborted streams, MIME/structure mismatch, polyglot and archive bounds, quarantine bypass, forged/duplicate callbacks, multipart ambiguity, cache behavior, retention/hold conflict, object/row orphaning, derived-file cleanup and caller-visible deletion.
