---
name: monorepo-management
description: Configure and evolve existing or new monorepo workspaces, dependency graphs, task pipelines, caching, affected execution, package boundaries, and releases. Use when repository changes to monorepo tooling are requested.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "existing package manager/tool, workspace graph, task contracts, CI trust model, release and cache requirements"
---

Configure or manage the monorepo for $ARGUMENTS.

## Discover the repository contract

Resolve the exact repository/workspaces authorized for mutation and applicable instructions before editing. Read root and workspace manifests/lockfiles, package-manager config, runtime pins, task scripts, project graph, build outputs, generated files, CI/deploy/release configuration, owners and existing caches. Define rollback for workspace, lockfile, graph, CI and cache changes. Preserve the installed package manager and orchestration tool unless migration is explicitly requested.

There is no package-count threshold that mandates Nx, Turborepo, pnpm, generators, remote cache or a directory layout. Choose tooling from current languages, ownership, graph complexity, task semantics, release cadence, CI bottlenecks, platform support and migration cost. For existing projects, verify capabilities from installed CLI/config schemas and matching official docs. For greenfield, use `scripts/framework-stack-context.py` to resolve supported stable/LTS components dynamically; after scaffolding, verify compatibility and let the generated manifests and lockfiles become the ongoing project authority.

For version-sensitive changes, evaluate every compatibility dimension exposed by the repository as one set: runtime engine ranges, workspace/package peers, compiler and framework pins, test runner, native tooling and deployment runtime where applicable. A supported monorepo-tool version alone does not prove the workspace stack is compatible.

## Model correctness before optimization

- Define workspace membership, package identities/exports, dependency and ownership boundaries, cycles, generated-code ownership, and independent/fixed release behavior.
- For every task, define inputs, dependency edges, environment/config/toolchain inputs, outputs, side effects, persistence and cacheability. Persistent, interactive, nondeterministic, secret-bearing or external-mutating tasks are not ordinary cache entries.
- Derive affected execution from an explicit trusted base/head selected for the event. Pin or fetch the base commit safely; do not assume `main`, `HEAD~1`, merge-base availability or shallow history. Include downstream dependents and global configuration changes.
- Validate graph/task behavior before enabling selective deploy. “Affected passed” is not proof if the base or graph is wrong.

## Cache and CI trust

Remote cache artifacts are untrusted inputs across forks, branches and tenants unless authenticated and isolated. Prevent untrusted pull requests from writing trusted cache namespaces or receiving cache/deploy/registry secrets. Include toolchain, lockfile, environment and all behavior-affecting files in cache keys; exclude secrets from keys/logs/artifacts. Verify artifact integrity/provenance, retention, access, poisoning containment and fallback on cache outage.

Do not mandate generators; add one only when repeated scaffolding has a stable contract worth enforcing. Do not centralize configuration or dependencies merely for uniformity when packages have different runtime/support needs.

For migrations, stage workspace/package moves, import and graph changes, lockfile transition, CI/release cutover and rollback. Preserve Git history only when worth the operational risk; use reviewed explicit paths/remotes and avoid destructive broad commands.

## References and verification

Read only the relevant exact guide when needed:

- Nx configuration: [references/nx.md](references/nx.md)
- Turborepo configuration: [references/turborepo.md](references/turborepo.md)
- shared configuration: [references/shared-config.md](references/shared-config.md)
- boundary enforcement: [references/boundary-enforcement.md](references/boundary-enforcement.md)
- Changesets/releases: [references/changesets.md](references/changesets.md)
- GitHub Actions CI: [references/ci-github-actions.md](references/ci-github-actions.md)

Run graph validation, locked install, focused package tasks, affected-set comparison against known changes, cache miss/hit correctness, clean rebuild, and affected CI/deploy checks. Test cache denial/poisoning boundaries for untrusted PRs where remote cache is enabled.

Report installed stack evidence, chosen graph/task/cache/release contracts, files changed, migration/rollback, actual commands/results, measured CI impact, and residual remote-cache/deploy risks.
