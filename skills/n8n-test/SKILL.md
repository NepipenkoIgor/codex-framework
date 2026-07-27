---
name: n8n-test
description: Build executable tests for n8n workflow logic, test webhooks, supported CLI/import/API boundaries, saved-versus-original replay, credentials, and failure recovery. Use when n8n test evidence is the deliverable; do not use for ordinary workflow implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "workflow/trigger, installed n8n version, test boundary, side effects, credential environment"
---

# n8n Workflow Testing

## Discovery

Read repository instructions, workflow exports/source-control format, pinned `n8n` manifest/lock/container image, installed CLI help, node versions, credentials/variables/projects, execution-retention settings, queue mode, and current official docs. Run `scripts/framework-stack-context.py project <path>`. Preserve the installed n8n line unless migration is explicitly requested.

## Test Boundaries

1. Test pure transformations, validation, routing and idempotency outside Code nodes where the repository already owns extractable code. Use exact decimal/domain rules rather than example shortcuts.
2. Validate workflow JSON against the installed n8n import/schema/tooling boundary or round-trip it through an isolated instance. A hand-written check for node names, connection shapes or credential IDs is only a narrow lint and must not claim workflow validity.
3. For webhook workflows, use the installed supported test-webhook/manual execution flow or an isolated active production-webhook path. Test registration/listening lifecycle, auth/signature validation, method/path, response mode, duplicate delivery and timeout. Never assume a test webhook is permanently registered.
4. For CLI/API integration, first verify the operation in installed CLI help and the current public API reference. Do not invent `/api/v1/workflows/{id}/execute`, internal execution-result shapes, or undocumented database endpoints. Depending on installed capability, use supported CLI execution, import/export, public workflow/execution endpoints, source control, test webhook, or UI/manual execution.
5. When replaying a failed execution, distinguish retry with the currently saved workflow from retry with the original workflow. Assert which graph, previous input, credentials and side-effect idempotency are expected.

## Isolation and Fixtures

- Use a task-owned isolated instance pinned to the same n8n version and compatible database/queue/task-runner configuration. Never use an unpinned `latest` container as compatibility evidence.
- Use test-only credential records, encryption key, projects, variables, webhook base URL, database and external sandboxes. Never import/export production secrets or point tests at production credentials/endpoints.
- Workflow exports normally reference credential metadata, not usable secrets; map explicit test credentials after import and verify access boundaries.
- Mock external systems only where the asserted contract is local. Keep at least one sandbox/contract path for irreversible or signature-sensitive integrations and label anything not exercised.
- Make test events uniquely identifiable and cleanup task-owned data by exact ID. Do not broadly delete instance executions/workflows or shared containers.

## Failure and Replay Matrix

Cover malformed/auth-invalid trigger, duplicate event, partial downstream success, provider timeout after commit, retryable versus terminal failure, wait/resume, expression/item-linking error, node version/config drift, saved-versus-original replay, disabled/unpublished workflow, credential denial, process restart, and queue worker loss where relevant.

Assert durable external outcome and execution state through documented supported surfaces. Do not couple tests to undocumented internal JSON. A 2xx webhook response or successful import alone is not workflow completion evidence.

## Output

Report installed n8n/version evidence, chosen supported execution boundary, workflow/replay identity, fixture and credential isolation, side-effect/idempotency assertions, exact checks/results, cleanup, and untested hosted/production paths.

Official sources: `https://docs.n8n.io/hosting/cli-commands/`, `https://docs.n8n.io/api/`, `https://docs.n8n.io/workflows/executions/all-executions/`, `https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/`.
