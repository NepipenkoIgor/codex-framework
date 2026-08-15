---
name: automation-n8n-implement
description: Implement executable n8n workflows with validated data contracts, credential isolation, item-level idempotency, retries, partial-batch recovery, and deployment evidence. Use for workflow changes; route design, incident diagnosis, and test-only requests to their dedicated n8n skills.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.1
  argument-hint: "trigger/workflow, nodes/providers, input/output schemas, side effects, target environment"
---

# n8n Workflow Implementation

Do not load the broad reference for ordinary repository discovery or a main-only task. Read [node and provider capability notes](references/full-guide.md) only after a concrete selected trigger, node, provider, credential, pagination or AI capability creates a specific version-sensitive question that the installed types/UI/CLI and matching official docs do not answer.

## Workflow

1. Read repository instructions, workflow exports/source-control format, pinned n8n manifest/lock, installed node versions/UI/types/CLI help, project/credential boundaries, deployment/queue mode and existing tests. Generate project stack context, verify capabilities against matching official documentation, preserve the installed n8n line and treat upgrade as separate scope.
2. Define trigger and final-output schemas, normalized item schema, immutable event/item/correlation IDs, side-effect authority, secrets/PII classification and exact target environment.
   Before canceling executions, disabling or activating a workflow, rotating/revoking credentials, deploying, or making any other material containment or recovery mutation, resolve the exact workflow/run/execution/credential target, applicable authority and permissions, resource ownership, caller-visible impact, and rollback or compensating recovery. Do not treat incident urgency or task ownership as mutation authority.
3. Normalize once at ingress. Validate every external and AI-produced field before branching or side effects. Preserve item identity across split/merge/batch/sub-workflow boundaries.
4. Resolve credentials only through n8n credential/project/external-secret facilities supported by the installed deployment. Never embed or export secrets in workflow JSON, expressions, pinned data, execution data, logs or errors.
5. Before each non-idempotent provider action, persist or query the business idempotency state. On timeout after possible success, reconcile by provider/business key before retrying. HTTP/node success alone is not proof of durable external outcome.
6. Handle partial batches per item: record completed/failed/unknown identifiers, retry only eligible items, preserve original order only where required, and prevent a replayed item from repeating a completed side effect.
7. Apply quotas, pagination, concurrency, retries and waits from installed node/provider capability and workload evidence. Derive both maximum attempts and total elapsed time from operation/provider evidence; route terminal/malformed failures to review/dead-letter and transient failures to bounded retry with provider guidance.
8. Import/validate through supported installed tooling in an isolated environment, exercise failure cases, export/review without secrets, then deploy/activate only to the explicitly authorized target with rollback evidence.

## Verification

Test duplicate webhook/item, provider timeout-after-success, replay after partial batch, credential missing/wrong-project/leaked into execution data, malformed input, empty page, pagination loop, quota/rate limit, child-workflow mismatch, process restart and disabled/unpublished state. Assert provider/business outcomes, not only green nodes.

## Output

Report installed n8n/node capabilities, changed workflows/contracts, credentials and environment boundary, item/idempotency state, retry/partial-batch/reconciliation behavior, exact checks and deployment evidence, and untested provider paths.
