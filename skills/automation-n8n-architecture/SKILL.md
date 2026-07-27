---
name: automation-n8n-architecture
description: Design n8n workflow boundaries, state, triggers, waits, retries, quotas, human review, AI decisions, and replay-safe side effects. Use when unresolved architecture is the requested deliverable; do not implement, debug, or test the workflow.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "business outcome, trigger, waits, side effects, integrations/quotas, installed n8n"
---

# n8n Workflow Architecture

Produce a design, not workflow JSON. Do not require hidden follow-on skills: the deliverable must contain enough contracts and invariants for a later implementation request.

## Workflow

1. Inspect repository workflow exports/source-control conventions, manifests/lockfiles, pinned n8n version, installed nodes, deployment/queue mode, credential/project boundaries, existing data stores and operations. Run `scripts/framework-stack-context.py project <path>` and verify the detected line through installed node/CLI/schema capability plus matching official documentation; use only capabilities supported by that line and treat an upgrade as separate scope.
2. Define the business outcome and authority. Separate trigger acceptance, normalization, deterministic decision, model-assisted proposal, human decision, durable state, external side effect, notification and final response.
3. Define stable schemas and immutable correlation/event/item IDs at every boundary. State which system owns deduplication, business state and external result.
4. Choose one workflow or sub-workflows from cohesion, permissions, reuse, execution ownership and recovery—not node count. Define inputs/outputs/version compatibility for every child workflow.
5. Model transient, terminal, malformed, quota, timeout-after-success and partial-batch outcomes. Bound concurrency/retries from provider quotas and workload evidence; define backpressure, dead-letter/manual review and reconciliation.
6. Model long human waits as durable business state with expiry, authorization and idempotent resume. Do not rely on a fragile in-memory wait or assume one n8n execution can remain available forever; verify installed wait/resume/retention capability.
7. Treat AI output as untrusted proposal. Validate schema and policy; require deterministic guardrails and explicit human or service authorization before irreversible, monetary, destructive, permission or external-publication actions.
8. Define observability and privacy: correlation IDs, redacted checkpoints, audit evidence, cost/quota metrics, alert owner, runbook, replay procedure and retention.

## Required Counterexamples

- Duplicate webhook arrives during the first execution: only one logical business outcome and side effect occurs.
- Human approval returns after a long delay, deployment or credential rotation: state can resume or expire safely with current authorization.
- AI proposes an irreversible action: invalid/unsafe output cannot cross the side-effect boundary.
- Provider quota is exhausted during a batch: accepted work is durably accounted for, concurrency backs off, partial state is reconcilable, and blind replay does not duplicate completed items.

## Output

Return trigger/data contracts, phase and sub-workflow boundaries, durable state model, idempotency/replay keys, wait/approval/AI authorization, quota/concurrency policy, failure matrix, installed n8n capability evidence, observability/runbook and unresolved product decisions.
