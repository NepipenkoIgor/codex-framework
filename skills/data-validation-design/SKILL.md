---
name: data-validation-design
description: Design read-only server-authoritative validation for API, domain, persistence, configuration, file, and provider boundaries with schema evolution, sanitization, unknown-field, and stable error contracts. Use when validation architecture is unresolved; do not use for routine implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.6
  argument-hint: "inputs/trust boundaries, schema authority and consumers, files/content, compatibility and error contract"
---

# Data Validation Design

Design `$ARGUMENTS` read-only.

For an existing project, derive version-sensitive validation capabilities from manifests/lockfiles, installed schemas/types and matching official documentation, preserving pins. For an explicitly authorized greenfield handoff, resolve stable/LTS releases from configured official sources at execution time, verify cross-stack compatibility, and require the generated manifest and lockfile to become authority; this read-only design does not itself scaffold the project.

1. Inventory every trust boundary: HTTP/body/path/query/header, events/jobs/webhooks, files/archives, configuration/secrets, database/provider data and generated clients. Identify canonical schema owner, consumers and persisted invariants.
2. Distinguish shape/type validation, normalization, domain invariant, authorization, database constraint and output encoding. Client validation is UX only; the server and durable store remain authoritative.
3. Define one canonical contract or explicit adapters to avoid divergent schemas, while allowing layers to enforce different concerns.

## Policy

- Specify missing/null/empty/default semantics, numeric/date/Unicode normalization, enum and unknown-field policy, cross-field rules, size/cardinality/depth limits and stable field paths/error codes. Strip, preserve or reject unknown fields deliberately with forward/backward compatibility in mind.
- Sanitization is context-specific transformation, not a universal substitute for validation or output encoding. Preserve original evidence where audit/security needs it without logging sensitive payloads.
- Files require extension, declared and detected type, size/count/decompression limits, filename/path normalization, archive traversal and bomb defense, malware/content processing, isolated storage and safe serving. Do not trust MIME or filename alone.
- Define schema version compatibility, producer/consumer rollout, historical/persisted data handling, defaults/upcasters and breaking-change gates.
- Error responses must be stable, machine-readable, localized safely and non-leaking; public error changes are API changes.

## Verification and output

Test boundary values, unknown fields, duplicate keys, coercion/Unicode/date ambiguity, cross-field/domain rules, unauthorized resource references, database constraints, malformed provider payloads, file polyglots/traversal/decompression, schema mixed versions and error compatibility. Use property/fuzz testing where it materially improves coverage.

Report trust-boundary matrix, schema ownership, normalization/sanitization/unknown policy, domain and database enforcement, file pipeline, version/error contracts, generated/contract tests and residual unvalidated boundaries.
