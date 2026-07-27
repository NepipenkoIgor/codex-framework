---
name: automation-n8n-debug
description: Diagnose and fix a concrete n8n execution, webhook, item-flow, credential, wait/replay, provider, AI, or partial-side-effect failure. Use for an evidenced defect or incident; do not use for greenfield design, implementation, or test-only coverage.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "workflow/execution, environment, expected vs actual outcome, affected nodes/side effects"
---

# n8n Workflow Debugging

## Workflow

1. Resolve exact environment, workflow saved/published version, execution ID/time, pinned n8n/node versions, trigger input, expected business outcome, actual external outcome and authorization to inspect or replay. Generate project stack context before version-specific conclusions.
2. Preserve evidence before editing: redacted execution path, per-node input/output item counts and stable IDs, errors, wait state, credential/project reference, provider request/resource/correlation IDs, business idempotency records, queue/worker logs and webhook response.
3. Find the first divergence on the actual executed graph, not the current canvas. Classify trigger/auth, item linking/shape, expression/code, branch/merge, node capability, credential, quota, timeout, wait/resume, concurrency, provider, AI validation, persistence or observability.
4. Before retry/replay, inventory side effects as completed, failed or unknown per item. Reconcile unknown provider outcomes. Distinguish retry with the currently saved workflow from retry with the original workflow and state which graph/credentials/data will run.
5. Reproduce in an isolated matching instance with sanitized fixtures when production replay is unsafe. Make the smallest responsible fix and add executable regression evidence; do not broadly rewrite the workflow during diagnosis.
6. Remediate affected records/items explicitly, with authorization and idempotency. Verify business/provider state plus execution evidence after the fix; a green node is not enough.

## Critical Incident Cases

- Execution failed after a provider created some resources: do not rerun until every item is reconciled and protected from duplication.
- Saved workflow changed after failure: compare saved versus original graph/node versions and choose replay semantics explicitly.
- Execution data is redacted or unavailable: use correlation IDs, provider/business records and logs; state uncertainty rather than invent payloads or disabling redaction.
- Webhook acknowledged but downstream state is absent/duplicated: correlate source event ID, trigger response, executions, queue and external side effects.
- Long wait did not resume: inspect installed wait/resume capability, execution retention, resume token/auth, deployment/restart and durable business state.

## Safety

Do not expose credentials or unredacted customer payloads to logs, exports, screenshots or test fixtures. Do not disable redaction/retention globally just to debug one incident. Replay production only with exact target, side-effect inventory, idempotency proof, rollback and user authorization.

## Output

Report environment/workflow/execution identity, expected versus actual outcome, first divergence and evidence, side-effect reconciliation, saved/original replay choice, root cause, minimal fix, remediation, exact checks and remaining uncertainty.
