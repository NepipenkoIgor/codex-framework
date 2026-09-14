# GraphQL runtime implementation

Load only for the installed server/client runtime. Confirm plugin hooks, validation rules, execution APIs, code generation, WebSocket protocol and framework integration from manifests, types and matching official documentation.

## Request and execution boundary

- Authenticate the transport, then authorize each object/resource and sensitive field using the current actor, tenant and ownership. Root resolver access, schema hiding or persisted-operation membership is not authorization.
- Bound body size, operation count, aliases, fragments, recursion/depth, list/page sizes, resolver fan-out, execution time and subscription resources. Derive query-cost weights and limits from schema/workload evidence; fixed global depth or complexity numbers are not portable.
- Canonical persisted operations bind hash to exact document and version/rollout policy. Handle stale clients deliberately, keep authorization independent, and invalidate caches when schema or policy changes.
- Format errors for the caller contract while preserving internal correlation. Do not expose stack traces, queries containing secrets, or another tenant's existence.

## Data access

- Detect N+1 from resolver/query telemetry. Batch only compatible requests and preserve result order/missing semantics.
- Scope loader caches to a safe request, actor, tenant and authorization context; clear or prime them after writes when the installed runtime semantics require it. A loader on every relationship is not a substitute for an efficient query plan.
- Choose cursor, keyset, offset or bounded list behavior from the schema contract and storage ordering. Enforce bounds server-side and test concurrent mutation.

## Subscriptions and generation

- Authenticate connection establishment and authorize each subscription plus every resource/event. Re-evaluate expiry and revocation for long-lived streams; define resume, backpressure, fan-out and cleanup.
- Generated server/client types are derived artifacts. Pin the generator with the project, review diffs, run drift checks, and never silently rewrite consumer contracts during an unrelated change.
- Federation gateways and subgraphs need composition, mixed-version, ownership, auth, partial-failure and query-plan evidence before rollout.

Verify the applicable object/field/wrong-tenant authorization, alias/fragment cost bypass, N+1, null/error propagation and caller-visible contracts. For features present in the target, also verify old persisted operations, loader isolation, pagination under mutation, subscription revocation/backpressure and generated-type drift. Schema-composition and mixed-subgraph checks apply only to a federated target; their absence does not require adding federation.
