---
name: contract-testing
description: Implement executable compatibility tests at REST, RPC, event, schema, SDK, provider-state, or other service boundaries. Use when cross-component contract coverage is requested; do not default every boundary to Pact.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "consumer/provider boundaries, protocol, ownership/deployment cadence, schema/versioning, broker/CI environment"
---

Implement contract tests for $ARGUMENTS.

## Select the real boundary

Read instructions, manifests/lockfiles, API/event schemas, clients and servers, generated SDKs, broker/registry config, authentication, existing tests, deployment topology and ownership. Identify consumer expectations, provider guarantees, compatibility window, source of truth and who may publish/promote a contract.

Before selecting or mutating tooling, classify boundary risk, validate installed capability, choose the smallest faithful check, and stop on material missing authority/evidence or failed compatibility validation. Resolve exact task-owned targets, permissions and rollback/recovery before creating provider state or publishing artifacts.

Choose the smallest mechanism that proves the boundary:

- schema/OpenAPI/protobuf/GraphQL compatibility for syntax and evolution;
- generated-client compile/runtime checks for SDK boundaries;
- consumer-driven contracts when independent consumers own observable examples and provider verification adds value;
- event schema plus semantic/integration tests for asynchronous delivery, ordering, keys and side effects;
- ordinary integration tests for co-deployed components where a broker adds no useful separation.

Pact is not mandatory. Preserve the installed runner/tooling and verify the selected command/API against local schemas, generated types, CLI help or matching official docs. Check the pinned contract tool together with its engine/runtime, peer dependencies, compiler/framework and installed test runner as one compatibility unit. For greenfield tools, resolve stable/LTS releases from configured official sources at execution time, verify cross-stack compatibility, generate the project manifest and lockfile, and make those generated files authoritative.

## Contract invariants

- Match only behavior the consumer relies on; avoid overfitting timestamps, random IDs, ordering or irrelevant provider fields.
- Provider states must be deterministic, authorized, idempotent and isolated per verification worker/run. Create exact owned records transactionally and clean only those records; do not share mutable global fixtures.
- Include authentication/authorization, tenant scope, errors, pagination, retries/idempotency, null/optional/default semantics, enum expansion/unknown-enum handling, encoding/content type, limits and backward-compatible unknown fields where applicable.
- For events, cover envelope and payload schema, topic/key/partition semantics, compatibility mode, required/default fields, duplicate/redelivery, ordering assumptions, poison/dead-letter behavior, producer and consumer versions, and side-effect idempotency. Schema-valid does not prove semantic compatibility.
- Publish immutable contracts with consumer/provider/version/provenance and prevent untrusted PRs from publishing trusted or deployable results.

Breaking-change policy must reflect deployed consumers and compatibility window. A removed optional field, enum expansion, changed default or stricter validation can be semantic breakage even when a schema diff passes.

## Verification and output

Run consumer tests, provider verification against isolated states, schema/evolution checks and affected integration tests. Exercise concurrent workers, stale consumers, missing/extra fields, errors, auth denial, event duplicates/order, registry/broker outage and rollback where relevant. Do not call production services or mutate shared environments.

Report chosen boundary and rejected alternatives, source of truth, version/provenance, provider-state isolation, compatibility findings, commands/results, publication/deployment gates, and residual unverified consumers or environments.
