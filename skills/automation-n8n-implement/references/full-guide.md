# n8n node and provider capability notes

Use only for the selected integration. Verify node version, operation/field names, credentials, item behavior, pagination, retry options and provider semantics in the installed n8n UI/types/help plus current official n8n/provider docs.

## Triggers and responses

- Webhook: verify test versus production URL lifecycle, authentication/signature, raw-body needs, response mode/timing and duplicate delivery. A test URL may require an active listener; a production URL may require the workflow to be published/active according to the installed line.
- Schedule/poll: persist an overlap-safe cursor/window and source IDs; test DST/timezone, first-run backfill, quota and concurrent executions.
- Queue/manual/sub-workflow: define caller identity, input/output schema, execution ownership and wait/error propagation from installed capability.

## Item and batching semantics

Nodes can emit zero, one or many items. Preserve a stable `item_id`/business key before split, loop, merge or code. Test empty streams, mismatched merge inputs, pagination tokens, final partial page, reordered provider results and per-item errors. Batch success must not erase unknown/failed item state.

## HTTP/provider nodes

Use the provider-specific node only when its installed operation exposes the required fields and response evidence; otherwise use an authenticated HTTP Request node with the provider's current API contract. Do not guess node UI fields or provider response shapes.

Persist provider request/idempotency and returned resource/correlation IDs. Classify 4xx business/input/auth failures separately from throttling/transient failures. Honor current retry guidance and `Retry-After` where applicable. Reconcile timeout-after-success by provider lookup or durable business state.

## Credentials and execution data

Map credential records per environment/project after import. Export only credential references. Restrict editors/projects according to current n8n sharing semantics. Redact/minimize execution and pinned data; verify secrets do not appear in workflow JSON, node parameters, expressions, error messages, binary metadata or external logs.

## AI nodes

Pin the selected provider/model configuration through approved environment policy, bound context/output/cost, require structured validation and distinguish provider failure from unusable output. AI output never directly authorizes irreversible actions; insert deterministic policy and approved human/service authorization.

## Capability sources

- n8n node docs: `https://docs.n8n.io/integrations/builtin/`
- Webhook node: `https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/`
- Execution order and item behavior: `https://docs.n8n.io/flow-logic/execution-order/`
- Credentials: `https://docs.n8n.io/credentials/`
- Scaling/concurrency: `https://docs.n8n.io/hosting/scaling/`

Use matching provider documentation for external APIs and quotas. No recipe here pins node fields, provider limits or retry counts.
