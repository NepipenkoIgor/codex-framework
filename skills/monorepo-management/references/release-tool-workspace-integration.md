# Monorepo integration for package release tooling

Use this reference only to integrate the repository-selected release tool with the workspace graph and task pipeline. `release-management` owns semantic-version policy, changelog content, prerelease policy, publishing, channels, recovery, and release automation. This skill consumes those decisions rather than creating them.

Verify the installed release tool and configuration schema plus command/action syntax from local help/types and current official documentation; do not copy remembered action majors, runtime versions, or runner labels.

## Workspace integration boundary

- Read the approved independent, fixed/locked-step, grouped-versioning, change-record, prerelease, and recovery policies from repository release configuration or the `release-management` decision. If unresolved, stop and route that decision instead of inventing it here.
- Map release-tool tasks to the actual workspace graph, package boundaries, affected execution, task inputs/outputs, cacheability, CI trust boundary, and generated-file ownership.
- Treat version, manifest, lockfile, and changelog output as non-cacheable release artifacts unless the installed tool and repository policy prove a safe deterministic boundary.
- Prevent untrusted pull requests from receiving publishing credentials or writing trusted release or cache state.

## Integration workflow

1. Validate the package graph, changed-package projection, public API/schema diff, generated artifacts, and the already approved release policy.
2. Prove that the installed tool selects the intended packages and updates only expected workspace artifacts in a reviewable dry run or fixture; do not publish.
3. Wire repository-authoritative package and consumer checks into the task graph, preserving release-management ownership of artifact production, provenance, signing, publishing, and recovery.

Verify no-change, one-package, and coupled-package selection; graph/affected propagation; generated-file drift; old/new consumer compatibility; CI trust isolation; and handoff of the exact selected package set and checks to release management. Publishing, prerelease promotion, partial-publish recovery, registry ambiguity, and channel rollback are release-management acceptance evidence, not monorepo-owned actions.
