---
name: automation-ai-workflows
description: Design AI-assisted automation that combines deterministic orchestration, bounded model decisions, validation, human review, and replayable side effects. Use when a workflow genuinely needs probabilistic reasoning; do not use an LLM for deterministic transforms or routing rules.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.2
  argument-hint: "trigger, deterministic steps, model decisions, tools, risk, human review and recovery"
---

# AI-Assisted Automation

Generate project stack context and inspect manifests/lockfiles, installed model/provider adapter and types, workflow runtime, schema validator, checkpoint store, side-effect provider and matching official documentation as one capability chain. Verify the pinned SDK's exposed usage-reporting and accounting fields, units, terminal semantics and error/partial-response behavior from installed types plus matching documentation; if the SDK cannot report a required unit, keep the gap explicit and meter only from an authoritative external boundary rather than inventing usage. Existing pins are authority and migration is separate. Read [the full pattern guide](references/full-guide.md) when the task needs provider/tool, approval, checkpoint, replay or side-effect patterns; load only the relevant section and keep volatile provider mechanics behind the selected adapter.

This skill owns the probabilistic boundary and read-only workflow design. When the requested deliverable is executable n8n nodes, credentials, deployment or runtime repair, hand implementation to `automation-n8n-implement` (or diagnosis to `automation-n8n-debug`) after preserving this design contract. If n8n is absent, state that evidence rather than silently absorbing neighboring ownership.

## Boundary Design

- Keep triggers, server-side authorization, schema validation, branching, retries, persistence, and side effects deterministic. Recheck authorization at execution time against the current actor, tenant, resource and approved action; model output and stale approval are never authority.
- Give the model the smallest explicit decision or transformation with a versioned schema.
- Treat model output as untrusted: parse, validate, constrain, and reject or repair before use.
- Separate recommendation from execution for destructive, financial, legal, security, or externally visible actions.
- Bound context, model/tool calls, iterations, concurrency, latency, and spend.
- Persist correlation IDs, prompt/model versions, decisions, validation results, side effects, and recovery state without sensitive prompt leakage.

## Workflow

1. Draw the deterministic state machine and identify the irreducibly probabilistic step. Demonstrate with the task's ambiguity, open-ended input or evaluation evidence why deterministic rules cannot satisfy it; merely labeling a classification probabilistic is not proof. If deterministic rules can satisfy it, remove the model.
2. Define input/output schemas, confidence/abstention rules, and human escalation.
3. Before invoking the model, durably persist the accepted workflow identity, immutable input reference, authorization context and resumable checkpoint. Implement idempotent side effects and subsequent checkpoints before adding the model.
4. Build a representative evaluation set including adversarial, ambiguous, empty, and provider-failure cases.
5. Test replay, duplicate triggers, invalid output, tool failure, approval expiry, provider success followed by timeout/lost response, budget exhaustion, human rejection, current server-side authorization denial, and recovery from every durable checkpoint. Add executable cases that activate the deterministic disable control and verify its owner-authorized effect, then exercise the versioned rollback or recovery path and assert restored state without duplicating or losing accepted side effects; naming a switch or rollback owner without these cases is not evidence.
6. Deploy with quality, latency, cost, abstention, and side-effect metrics plus a deterministic disable path and a versioned rollback or recovery strategy. Keep confidence/quality thresholds in versioned product policy backed by the evaluation set, not in provider glue or reusable skill prose.

## Output Contract

- Deterministic state machine and model boundary
- Schemas, confidence/escalation, security, and budget controls
- Evaluation, disable-control, rollback, and failure-recovery evidence
- Concrete read-only rollout and promotion plan: cohort/canary sequence, entry/exit gates, accountable approver, stop/disable conditions, rollback and in-flight reconciliation. Report deployment as unexecuted unless the authorized implementation owner actually ran it.
- Operational metrics and residual model risk
