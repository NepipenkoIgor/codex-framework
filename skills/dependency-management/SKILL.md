---
name: dependency-management
description: Implement safe dependency pins, updates, and automation using repository-native package managers, compatibility gates, staged pull requests, and rollback. Use when dependency policy or updates are requested; use dependency-audit for read-only findings.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  argument-hint: "package managers/workspaces, target dependencies, support policy, CI/release gates, automation provider"
---

Manage dependencies for $ARGUMENTS.

## Discover before changing

Read instructions, manifests/lockfiles/workspaces, engines/runtime files, package-manager config, peer and native constraints, build/deploy artifacts, CI, release cadence, current update automation, package/workflow owners, required reviewers and rollback ownership. Preserve the existing package manager and lockfile. For an existing project, installed manifests and locks are authority; verify commands and compatibility from local CLI/types and matching official docs.

Resolve stable releases, supported production LTS runtimes, advisories and provider schemas at execution time from official distribution channels. For greenfield work, use `scripts/framework-stack-context.py`. Never hardcode a remembered Node/framework/action version or stale example.

## Safe update policy

- Pin according to artifact type and repository reproducibility policy. Exact pins are not universally correct for every library, peer, workspace or application; the resolved lockfile and integrity/provenance remain part of the contract.
- Update the smallest compatible set. Check engines, peers, compiler, framework, native/platform, test runner, deployment runtime, database/schema and generated artifacts together.
- Separate routine, major, runtime, native, security and migration-heavy updates. Do not hide breaking migrations in broad groups.
- Produce reviewable update branches/PRs with manifest and lock diff, release/advisory links, compatibility notes, migrations, focused/affected checks, rollout and rollback. Avoid lockfile-only churn unrelated to the target.
- Automation may open PRs and apply policy, but blanket automerge is unsafe. Auto-merge only explicitly classified low-risk changes with required CI, provenance, approval, cooldown/freshness and rollback controls. Security urgency does not justify bypassing compatibility evidence.
- Pin third-party CI actions by the repository's supply-chain policy (for example immutable revisions where required) and record update provenance; do not recommend stale action majors from memory.

Rate-limit automation, cap concurrent PRs, prevent duplicate groups, respect maintenance windows, and define abandonment/rollback behavior. Protect secrets and prevent untrusted fork PRs from receiving write tokens, registry credentials or mutable-cache authority.

Before enabling mutation or automerge, assign ownership for updater configuration, package/runtime migrations, security exceptions, CI/workflow changes, rollback and stale-PR cleanup. Missing authority, incompatible capability, failed required validation or an unowned rollback path blocks rollout.

## Verification and output

Run install/restore in the repository-authoritative locked mode, focused tests for affected APIs, then type/lint/build/test and relevant integration/native/deployment checks. Verify lockfile integrity, generated changes, duplicate/resolution graph, package contents/lifecycle scripts where risk warrants, and rollback to the prior lock/artifact. A green updater PR is not proof of production compatibility.

Report current and target resolved versions with timestamped official evidence, changed manifests/locks, compatibility/migration decision, automation gates, checks/results, rollout/rollback and residual provider/runtime risk.

Read [the selected provider/package-manager guide](references/full-guide.md) only when its exact configuration syntax is needed; preserve repository-specific policy over examples.
