# Nx capability notes

Use only for a repository that already selects Nx or an explicitly approved migration. Inspect the installed Nx packages, `nx.json`, project configuration, package-manager workspace, plugins, CI integration and local CLI help; verify schema and commands against the matching official documentation.

- Model each target's real dependencies, inputs, environment/config inputs, outputs, persistence, side effects and cacheability before editing target defaults or named inputs.
- Derive affected execution from the event's trusted base/head and prove it against known graph changes. Do not hardcode a branch name or assume shallow history contains the base.
- Treat remote cache and distributed execution as supply-chain boundaries. Define authentication, branch/fork/tenant isolation, write authority, artifact integrity, retention, outage fallback and secret exclusion before enabling them.
- Use module-boundary tags/constraints only when they reflect real ownership and allowed dependency directions. Validate existing imports and migration path before making the rule required.
- Add a workspace generator only for a repeated stable contract. Test generated output, idempotency, collisions, path/identifier validation, dry-run behavior and compatibility with repository formatting and package boundaries.
- Discover graph, affected, cache-debug and migration commands from the installed CLI instead of copying remembered flags or service pricing/capacity claims.

Verify full versus affected task parity, clean local cache miss/hit equivalence, configuration-input invalidation, graph cycles/boundaries, generator fixtures, CI base selection and rollback to the prior Nx configuration. When remote cache is enabled, verify untrusted fork/tenant cache denial and poisoning containment; when it is authenticated, also verify an authenticated remote hit.
