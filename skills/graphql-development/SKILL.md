---
name: graphql-development
description: Design or implement GraphQL schema and runtime behavior with compatibility, persisted operations, query-cost controls, object/field authorization, batching, pagination, subscriptions, code generation, and federation. Use when GraphQL execution semantics dominate; do not use for REST or ordinary backend work.
metadata:
  owner: codex-framework
  reviewed: "2026-09-14"
  version: 1.2
  argument-hint: "schema/runtime pins, consumers/operations, auth/tenant model, workload/cost and compatibility"
---

# GraphQL Development

1. Inspect instructions, manifests/lockfiles, schema, known operations/consumers, generated artifacts, runtime/plugins, persistence, auth, telemetry, contract checks, schema/runtime owners and required approval. Generate stack context and use only installed runtime capability.
2. Model consumer use cases, nullability/error and evolution/deprecation before fields. Preserve compatibility or define mixed-client migration.
3. Authenticate requests and authorize at object/resource and sensitive field boundaries using current actor/tenant ownership. Schema visibility, resolver presence and root-level auth are insufficient.
4. Bound request body, operation count, aliases/fragments/depth, list/page sizes, resolver fan-out, execution time and subscription resources using measured/query-cost policy. Introspection and persisted-only mode are threat/deployment decisions.
5. Persisted operations need canonical hash/document, allowlist/version rollout, explicit stale-client rejection, auth independent of allowlisting and cache invalidation. A degraded path requires an explicit project contract.
6. Detect N+1 with resolver/query telemetry; batch/cache only within safe request/tenant/auth scope. Pagination, DataLoader, Relay, totalCount and federation are optional.

Before mutation, resolve the exact schema/runtime/generated-artifact targets and a recovery path for schema, persisted-operation allowlist, generated clients and caches. Missing authority, an incompatible pinned capability, a breaking change without consumer migration, or an unowned rollback path blocks implementation.

Read [schema contract notes](references/schema-contracts.md) for evolution. Read [runtime implementation notes](references/runtime-implementation.md) only for implementation and adapt to installed APIs.

Verify affected schema/runtime contracts, object/field/wrong-tenant auth, alias/fragment cost bypass, list bounds, N+1/query plans and null/error behavior. Verify generated clients, old persisted operations, pagination under mutation, subscriptions and federation composition when those features are present. Any required failure blocks completion and invalidates affected evidence until rerun. Report installed capability, schema/runtime changes, auth/cost controls, rollback/recovery and residual client/deployment risk.
