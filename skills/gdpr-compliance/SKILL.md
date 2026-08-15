---
name: gdpr-compliance
description: Implement engineering controls for data-subject requests, consent evidence, retention, erasure, portability, processor coordination, and privacy evidence. Use when a product must operationalize an approved privacy/legal policy; do not use as legal advice or as a substitute for a data inventory and counsel decision.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  domain: backend
  keywords: [GDPR, privacy, SAR, subject access request, erasure, portability, consent, retention, PII, processor, legal hold]
---

# Privacy Rights Engineering

Engineering patterns only. Legal counsel or the accountable privacy function owns applicability, lawful basis, exemptions, deadlines, retention, and notices.

Treat supplied task and fixture facts as authoritative evidence. If they state that applicable repository or product evidence was inspected, use that inspection while keeping withheld file names, contents, commands, and results unavailable; never replace a supplied inspected-state fact with a blanket claim that no inspection occurred.

## Repository Discovery

Start from the approved record of processing/data map. Trace identifiers and personal data across primary databases, identity systems, object storage, caches, search, analytics, data warehouse/lake, logs, backups, queues/dead letters, support tools, email/CRM, billing, and every processor/subprocessor. Record controller/processor ownership, region, purpose/legal basis, retention rule, deletion/export API, backup behavior, and evidence owner. A hard-coded table list is not proof of completeness.

## Request State Machine

Model each request durably:

```text
received -> identity_pending -> scoped -> approved|refused
         -> executing -> partial_retry|blocked_by_hold -> verified -> delivered -> closed
```

- Verify identity proportionately before revealing or erasing data; minimize and promptly dispose of extra verification evidence.
- Store request type, subject identifiers, authority/representative evidence, received date, policy-derived due date, extension/escalation, scope, legal decisions, per-system steps, attempts, artifacts, reviewer, and timestamps.
- Respond without undue delay and use the approved policy for the one-month rule and permitted extension; never encode “30 days” as universal legal logic.
- A refusal or partial fulfillment records the approved reason and notification/escalation requirements.

## Durable Per-System Execution

Create one idempotent step per data store and processor. Each step has `pending/running/succeeded/failed/not_applicable/retained`, an idempotency key, attempts, evidence, and next action. A workflow is complete only when all required steps are terminal and independently verified. Provider failure results in `partial_retry` or documented escalation, never silent success.

Use a data-subject key/index for caches and derived stores. `DEL "user:*"` does not expand wildcards; delete enumerated keys or use a bounded `SCAN`/maintained index without blocking the cache. Treat backups separately: document restore-time suppression/re-erasure and retention rather than pretending an online delete rewrites immutable backups.

## Access and Portability

- Export only data within the approved subject/scope and protect third-party rights.
- Include processing metadata required by policy, not just raw application rows.
- Generate in an isolated job, encrypt at rest, use a short-lived authenticated delivery channel, bind download to the verified requester, audit access, and delete artifacts on schedule.
- Validate completeness against the data map and processor step manifest; limits/pagination cannot silently truncate the result.

## Erasure, Restriction, and Holds

Build an approved decision matrix per data category: delete, irreversible anonymization, restrict, retain under a documented ground, or escalate. Before an intentionally irreversible deletion or anonymization, append an immutable decision record containing the approved target/scope, authority, hold result, actor, time, and the fact that rollback is impossible; recovery is reconciliation and forward-fix, not invented restoration. Financial/audit records are not blanket exemptions and example retention periods are not legal rules. A legal hold retains only the justified subset and blocks conflicting steps with explicit evidence.

External cancellation, deletion, and anonymization run as idempotent workflow steps. Do not wrap only local tables in a transaction and then mark the request complete after `Promise.allSettled`. Revoke sessions/credentials early where appropriate, preserve a minimal tombstone/idempotency record, and verify processor outcomes.

## Consent and Retention

- Record append-only consent/withdrawal evidence with purpose, policy version, channel, locale, timestamp, and subject; do not collect unnecessary IP/device data by default.
- Consent is one possible legal basis, not a universal prerequisite for every processing purpose.
- Enforce retention from a reviewed policy register by data category and system. Jobs run with dry-run/report mode, legal-hold checks, bounded batches, evidence counts, and alerts for failures or unexpected volume.
- Cookie/client controls must actually prevent non-essential processing before consent when the approved policy requires it; hiding a banner is not enforcement.

## Verification

- Submit a request for another subject and with insufficient authority; no data is disclosed or erased.
- Fail one processor/cache/warehouse step; the request remains partial/retrying and cannot close.
- Compare the export/erasure manifest with schema, data catalog, processors, backups, and restored data.
- Exercise legal hold plus erasure; only the justified subset remains and all other required steps finish.
- Verify every cache key through its maintained subject index or bounded scan; no wildcard assumption.
- Restore a backup into an isolated environment and prove suppression/re-erasure controls run before use.
- Verify delivery links expire, require the intended authenticated requester, and are audited.

## Output Contract

Report the data/processor inventory, identity and authority controls, request state machine, policy-derived deadlines, per-system execution/evidence, export delivery, erasure/hold decisions, backup strategy, consent/retention controls, executed failure cases, and every legal assumption awaiting accountable approval.

## Official Provenance

- European Commission: `https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/dealing-requests-individuals_en`
- European Commission GDPR obligations: `https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/obligations_en`

Re-check official guidance and the applicable supervisory authority before changing policy-dependent behavior.

## Done Criteria

- Identity/authority is verified before consequential fulfillment.
- Inventory includes local, derived, processor, backup, queue, and analytics paths.
- Required steps are idempotent, retryable, evidenced, and cannot fail silently.
- Completion requires verified terminal status for every required step.
- Legal holds, retention, refusal, and deadlines come from approved policy rather than hard-coded examples.
- Failure, restore, replay, and unauthorized-request tests pass.
