---
name: audit-logging
description: Implement security and compliance audit-event capture, attribution, tamper evidence, protected query, retention, legal hold, and sink reconciliation. Use when consequential actions require an evidentiary trail; do not use for general observability logs, analytics events, or policy/legal decisions without implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 3.0
  argument-hint: "event classes, actors/tenants/resources, transaction boundaries, sink, query roles, retention/hold policy"
---

# Audit Logging

Implement `$ARGUMENTS` as an evidence system with explicit trust, durability, privacy, and lifecycle limits. Do not promise absolute immutability merely because application updates are disabled.

## Workflow

1. Inspect instructions, manifests/lockfiles and exact pinned runtime, database/object-store, broker, sink and client versions; verify their required behavior against matching official documentation. Then inspect identity and tenant model, consequential operations, transaction boundaries, current logs/outbox/broker/sink, administrators and query roles, privacy classification, retention register, legal holds, erasure model, incident/compliance requirements, clock/source trust, monitoring, and tests as one compatibility chain. Existing pins are authority; upgrades are separate migrations.
2. Define one versioned, owner-approved and provenance-linked evidence policy joining the event/classification matrix, sink capabilities, integrity/threat guarantee, sensitive-data classification, retention and legal-hold rules: authenticated or unresolved actor/service, acting-on-behalf-of/delegation, tenant, action, resource, authorization decision, request/trace, source/environment, timestamp/order evidence, outcome, reason, minimized changes, sensitivity, durability/failure class, retention and hold policy.
3. Capture identity and tenant from trusted authenticated context, not caller-provided fields. Record denied and failed high-risk attempts as well as successes, while distinguishing attempted, authorized, committed, provider-accepted, and reconciled outcomes.
4. Close transactional gaps. When business mutation and outbox share a database, write them atomically. Otherwise use durable acceptance plus idempotent sink append and reconciliation. For regulated fail-closed classes, reject the action unless durable capture is guaranteed; for policy-approved fail-open classes retain a durable pending record and alert. An in-memory fallback is not evidence.
5. Minimize before ingestion. Never record passwords, tokens, signing keys, OTPs, raw card data, full request bodies, or unnecessary sensitive fields. Tokenize or separately protect reversible identity/PII; access to detokenization is narrowly authorized and audited.
6. Implement append-only controls and tamper evidence appropriate to the adversary: restricted writer roles, sequence/hash/signature or immutable-storage controls, replication/export, access logs, integrity verification, and separation of duties. Database triggers alone do not protect against owners, administrators, backups, or sink compromise; document the actual guarantee.
7. Authorize queries by actor, tenant, purpose, event sensitivity, time range, and field-level redaction. Use bounded pagination/export, audit access to audit data, prevent search or error channels from leaking other tenants or hidden PII, and verify support/compliance role boundaries.
8. Derive retention, archive, deletion, and legal-hold behavior from the approved register and applicable legal owner. Holds override ordinary deletion only for scoped evidence; release returns records to policy. Preserve deletion/tombstone/integrity evidence without claiming that every audit byte is legally undeletable.
9. Bound sink backpressure and outage behavior by event class. Monitor capture lag, dropped/rejected events, outbox backlog, sink rejects, sequence/integrity gaps, clock skew, storage/retention failures, and reconciliation drift.
10. Verify business commit/outbox crash points, duplicate delivery, sink outage/backpressure, actor/service/delegation and tenant attribution, denied/failed/success states, tamper attempts by each role, integrity verification, secret/PII scanning, query authorization, export bounds, retention plus legal hold plus identity erasure, and restore/reconciliation.

## Required counterexamples

- “No UPDATE/DELETE method” or a trigger does not prove absolute immutability against a database owner or compromised sink.
- Logging an authorization header, OTP, reset token, or raw payload creates a new secret store and is prohibited.
- A successful business mutation followed by a best-effort log insert leaves an evidentiary gap.
- A tenant administrator cannot automatically query global security events or detokenized identities.
- Retention, deletion, and legal-hold rules are policy/legal inputs; example periods or “never delete” are not universal.

## Output

Report event/classification and trust matrix, attribution and outcome states, durability/failure policy, tamper-evidence threat model and guarantees, privacy/tokenization, query authorization, retention/hold/deletion policy inputs, sink/backpressure/reconciliation monitoring, failure/security tests and results, and legal/compliance assumptions requiring owner approval. Include protected aggregate lifecycle totals for pending, rejected and dropped events plus held, deleted and integrity-gap records, without exposing tenant or sensitive event data.

## Provenance

- NIST computer security log management: https://csrc.nist.gov/pubs/sp/800/92/final
- OWASP application logging security guidance: https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
