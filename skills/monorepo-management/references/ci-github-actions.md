# Monorepo CI on GitHub Actions

Treat the repository's workflows, runner policy, package manager, task graph and GitHub's current schemas as authority. Resolve action revisions and runner labels at implementation time; do not copy remembered action majors or mutable runner examples.

## Job design

- Establish a trusted base/head pair for affected-project calculation. Pull requests from forks, merge queues, rebases and shallow clones need explicit handling; a missing base must fall back to a safe broader check rather than silently skipping work.
- Restore dependencies in the repository-authoritative locked mode. Cache only content-addressed, non-secret artifacts with keys derived from OS/runtime/package-manager/lockfile and relevant configuration.
- Separate required correctness gates from optional telemetry. Ensure skipped/empty matrices produce the branch-protection conclusion intended by policy.
- Derive matrix width and task concurrency from actual runner capacity, memory, service dependencies and CI throughput. Avoid fixed core counts or global concurrency constants.
- Upload only necessary artifacts with bounded retention and no secrets, tokens or unnecessary user data.

## Security and reproducibility

- Pin third-party actions according to the repository supply-chain policy, using immutable revisions when required, and record update provenance.
- Give each job the minimum token permissions. Untrusted code must not run with write tokens, deployment credentials, registry secrets or mutable-cache authority.
- Protect release/deploy jobs with environments, approvals and exact artifact provenance. Build once and promote the verified artifact where the platform supports it.

Verify changed/unchanged packages, dependency graph changes, fork PRs, merge queue, empty affected set, cache poisoning boundary, cancellation, flaky retry policy, required-check aggregation and rollback to the prior workflow revision.
