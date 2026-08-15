---
name: workflow-engine-design
description: Design platform-neutral durable workflow execution with authoritative state transitions, timers, retries, human waits, idempotent effects, compensation, replay, versioning, and recovery. Use when long-running orchestration semantics are unresolved; route n8n-specific architecture to automation-n8n-architecture, and do not use for simple in-request sequences or direct implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.4
  argument-hint: "workflow states/invariants, effects, timers/human waits, engine/provider, versioning/recovery/compensation"
---

# Workflow Engine Design

Design `$ARGUMENTS` read-only.

1. Inspect repository instructions, manifests/lockfiles, installed engine/configuration, implementation and authoritative state store, nearby tests, recent failure evidence and deployment/runtime constraints. Report inspected evidence without inventing unavailable exact values.
2. Define business invariants, workflow identity, actor/tenant/resource authority, durable states and legal transitions before choosing an engine. A diagram or queue is not durable execution.
3. Identify every effect, timeout, retry, cancellation, human approval, signal, concurrent command and recovery path. Derive retry attempt and elapsed-time bounds from observed/provider operation semantics, engine capability, business deadline and recovery objective; do not merely state that retries are bounded. Decide which store/engine is authoritative for transition state.
4. Preserve repository/provider pins and verify engine determinism, timer, signal, retry and version APIs from matching official documentation.

## Execution contract

- Persist transition intent/state atomically with the authoritative decision or use an explicit outbox/command protocol. Workers may deliver at least once; establish stable workflow/step/effect identity before side effects and reconcile timeout-after-effect.
- Only a currently authorized actor/system command can cause a transition. Reauthorize human approvals and external signals against workflow version/state; reject stale, duplicate or wrong-tenant events.
- Use durable engine timers for long waits; process memory and ordinary scheduled callbacks are not authoritative across restart. Human waits need expiry, escalation, delegation, revocation and audit.
- Define concurrency/version preconditions so two workers or approvals cannot both advance one transition. Ordering is scoped to workflow/aggregate identity.
- Compensation is a business action, not database rollback: define eligibility, idempotency, partial failure, retry and manual reconciliation. Some effects are irreversible.
- Replay must separate deterministic state reconstruction from external effects, preserve historical code/schema compatibility, and support dry-run/canary/checkpoint/stop conditions.
- Version running workflows explicitly; do not change nondeterministic code beneath history without the engine's compatible migration mechanism.

## Verification and output

Test crash before/after state and effect, duplicate/concurrent workers/signals, stale approval, timer across restart, cancellation races, timeout-after-effect, compensation partial failure, engine outage, replay without repeated effects and mixed-version workflows.

Report state/transition authority, durable persistence, step/effect identities, retry/timer/human/cancellation semantics, compensation/replay/version migration, observability/manual recovery, alternatives and residual risk.
