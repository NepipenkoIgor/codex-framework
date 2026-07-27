# GraphQL schema contracts

Use the observed consumer operations and installed schema tooling as authority. Schema-first and code-first are implementation choices; both require a reviewable schema artifact and compatibility evidence.

## Model the consumer contract

- Model product concepts and stable identifiers rather than exposing persistence records mechanically. Define nullability from failure/absence semantics; neither nullable-everywhere nor non-null-by-default is universal.
- Use separate input shapes when write semantics differ from output. Validate business input at the authoritative service boundary even when scalars or generated types also validate syntax.
- Choose field arguments, filters and pagination from access patterns and mutation behavior. Cursor connections help ordered changing collections; bounded offset or simple lists may be correct for small/stable data. Never return an unbounded collection.
- Define expected domain failure as data, typed result or GraphQL error according to consumer needs and installed conventions. Preserve machine-readable classification without leaking internal details.

## Evolve safely

- Diff against registered schema and known persisted/generated consumer operations. Additive-looking changes can still break exhaustive enum handling, validation, cost or authorization assumptions.
- Deprecate with reason and migration evidence; remove only after proving affected clients/operations have moved. Adding required arguments, narrowing nullability, changing semantics or reusing a name requires an explicit compatibility plan.
- Preserve stable pagination cursor meaning across rollout or version it. Test inserts, deletes and sort-key ties between pages.
- Federation/composition is justified by real ownership and independent delivery boundaries. Define entity keys, field ownership, authorization, partial failure and composition checks; do not federate a single-team schema by default.

Verify old/new clients and persisted operations, schema diff, enum/union unknown handling, null/error propagation, page mutation behavior, authorization visibility and generated artifact drift.
