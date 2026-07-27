---
name: file-upload-storage
description: Implement secure tenant-scoped upload, object storage, metadata, quarantine, processing, retrieval, signed access, retention, and deletion for user/integration files. Use for untrusted files; do not use for static build assets.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.1
  argument-hint: "provider/pins, actor/tenant/resource ownership, size/type/archive limits, processing/quarantine, access/retention"
---

# File Upload and Storage

Read [the full provider guide](references/full-guide.md) only for the selected installed provider and stack.

1. Define actor/tenant/resource ownership, threat model, provider/region, direct versus mediated path, limits, processing, retention/legal hold and failure states.
2. Authorize before issuing upload capability and again before metadata mutation, processing, download or signed URL. Generate opaque server-owned tenant/resource object keys; never trust filenames or paths.
3. Enforce streaming size/count/time limits and storage quotas. Treat extension, declared MIME and browser type as hints; sniff content and validate format structure where risk requires it.
4. Defend against path traversal, Unicode/confusable names, polyglots, archive nesting/bombs, parser exploits and active content. Quarantine as non-public until required malware/content processing succeeds; processing callbacks are authenticated and idempotent.
5. Signed URLs are short-lived, least-privilege, audience/method/object scoped where provider supports it and never substitute for ownership authorization. Prevent public ACL/policy drift and unsafe content disposition.
6. Reconcile metadata/object state across aborted multipart upload, duplicate completion, orphan object/row, retry and deletion. Automated cleanup or provider retry must derive bounded attempts or elapsed time and poison/alert behavior from provider and product evidence. Define encryption, audit, retention, legal hold, erasure, failed multipart and derived-file cleanup.

Test unauthorized/wrong-tenant upload/download/key guessing, oversized/stream-abort/polyglot/MIME mismatch/traversal/archive bomb, quarantine bypass, forged/duplicate callbacks, signed URL scope/expiry, multipart failure and deletion propagation. Report provider policy evidence and unverified scanner/provider paths.
