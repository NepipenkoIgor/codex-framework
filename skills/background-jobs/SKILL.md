---
name: background-jobs
description: Implement durable background job execution, scheduling, retries, cancellation, shutdown, deduplication, and recovery inside an application job system. Use when repository code must enqueue or execute deferred work; do not use for broker topology, cross-service event contracts, workflow-engine design, or diagnosis/review alone.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "job intent, queue/scheduler, business key, side effects, retry/dead-letter policy, runtime shutdown"
---

# Background Jobs

Implement `$ARGUMENTS` with explicit durable ownership from enqueue through terminal recovery.

## Workflow

1. Inspect manifests/lockfiles, configured job library and backend versions, schema, enqueue transaction, worker lifecycle, concurrency, scheduler, deployment termination settings, observability, replay/dead-letter tools, recent failure evidence, and nearby tests. Preserve supported library, runtime and backend pins; verify APIs in installed types/config and version-matched official docs, and treat library or backend migration separately.
2. Define the durable job identity and business operation key, payload schema/version, authorization snapshot versus execution-time authorization, queue/priority, scheduling semantics, deadline, cancellation, retry classification, and terminal states.
3. Make enqueue atomic with the business state that requires the job, usually through a transactional outbox or database-backed job record. Never report success when domain state committed but enqueue was lost.
4. Assume at-least-once execution unless stronger semantics are proven end to end. Before calling an external provider, reserve or load a durable operation. After provider success, settle local state idempotently; on crash or ambiguous timeout, reconcile by operation key rather than repeat blindly.
5. Claim work atomically with lease/visibility semantics supported by the configured system. Renewal failure or lost ownership prevents further protected writes. Bound concurrency by dependency and resource capacity, not a universal worker count.
6. Classify errors: retry only transient, safe-to-repeat failures; honor provider retry guidance; persist attempt and next-run evidence; use bounded exponential/jitter behavior from policy. Validation, authorization, unsupported schema, and permanent provider rejection do not loop.
7. Handle termination explicitly: stop claiming, signal cooperative cancellation, wait only within the platform grace budget, persist/release ownership safely, and let unfinished work be recoverable. A hung call must have a deadline; SIGTERM cannot depend on it returning voluntarily.
8. Dead-letter/quarantine retains payload/version, attempts, cause, side-effect evidence, and operator decision. Replay creates an auditable new attempt under current authorization and schema compatibility; it does not erase the prior failure or bypass deduplication.
9. Verify with process death before the provider call, after provider success, and after local settlement writes; concurrent workers; duplicate schedule/enqueue; lease expiry/renewal failure; cancellation; shutdown with a hung dependency followed by restart recovery; poison payload; provider ambiguity; retry exhaustion into the configured terminal/dead-letter/quarantine state; and deployment/runtime behavior. Dead-letter replay must combine current authorization revalidation with old/unsupported-schema rejection, plus a compatible replay that preserves audit and deduplication.

## Required counterexamples

- Crash after provider success but before local completion must reconcile, not send the email, charge, or export again blindly.
- Two workers racing the same due job must not both perform an unprotected side effect.
- SIGTERM during a hung provider call must stop new claims and yield recoverable ownership within the real grace period.
- Replaying a dead-lettered job must revalidate actor/resource authority and payload version and preserve audit history.
- Cron time zones, overlap, missed-run catch-up, and daylight-saving behavior are explicit product decisions, not library defaults.

## Output

Report installed job/runtime evidence, job and payload contract, enqueue atomicity, claim/lease ownership, side-effect idempotency and reconciliation, retry/dead-letter/replay policy, shutdown/cancellation behavior, exact tests and results, operational metrics/alerts, and any unverified provider or deployment boundary. Include protected counts and task-owned identities for items drained, canceled, recovered, quarantined and replayed plus unresolved items; mark each unavailable execution result `Not available`.

## Provenance

- Kubernetes Pod termination lifecycle: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination
- Kubernetes Job lifecycle and cleanup: https://kubernetes.io/docs/concepts/workloads/controllers/job/
