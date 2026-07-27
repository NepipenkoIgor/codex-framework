# Turborepo capability notes

Use only when the repository already selects Turborepo or an approved migration requires it. Inspect the installed `turbo` package, current config schema, workspace/package scripts, lockfile, environment inputs, CI and local CLI help; use matching official documentation for exact keys and flags.

- Define task dependency edges, inputs, environment/config/toolchain inputs, outputs, persistence, interactivity, side effects and cacheability from actual scripts. Empty or guessed output patterns can produce false hits or needless misses.
- Keep secret values out of configuration, cache keys, logs and artifacts while ensuring every behavior-affecting non-secret input invalidates the task.
- Compute filtered/affected work from an explicit trusted base/head and compare it with a full graph for representative changes, including global config and lockfile edits.
- Treat remote cache as an untrusted artifact boundary: authenticate, isolate fork/branch/tenant writes, verify integrity where supported, bound retention, define outage behavior and prevent deployment credentials from reaching untrusted tasks.
- Persistent development tasks, nondeterministic tests and external-mutating commands are not ordinary reusable cache entries.
- Add generators only for proven repeated package contracts; validate names/paths, collisions, dry run, deterministic output and compatibility with package ownership.

Verify clean miss/hit equivalence, input and environment invalidation, full versus filtered task parity, fork cache denial/poison containment, cancellation, cache outage, generated package fixtures and rollback to the prior pipeline configuration.
