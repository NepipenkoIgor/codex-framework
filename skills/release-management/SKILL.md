---
name: release-management
description: Implement repository release policy, versioning, changelogs, immutable artifacts, channels, publishing, provenance, hotfixes and rollback. Use when release-management repository changes are requested.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "artifact types/registries, consumers and compatibility policy, current tool, channels, monorepo and rollback"
---

Implement release management for $ARGUMENTS.

Read instructions, manifests/lockfiles, existing tags/releases/changelog, package graph, registries, artifact build, CI identities, support/channel policy and rollback constraints. Versioning expresses the product's compatibility contract: SemVer and Conventional Commits are options, not universal rules. Preserve established policy unless migration is requested.

Resolve installed release-tool/provider capabilities from local schema/CLI and matching official docs. For greenfield tooling use `scripts/framework-stack-context.py`. Pin release actions/tools/images according to supply-chain policy.

Build once from the approved commit in a locked environment and promote the same immutable artifact/digest across channels where possible. Record source commit, dependencies, build environment, SBOM/signature/provenance as required. Rebuilding “the same version” is not reproducibility proof.

Channels and tags must map atomically to immutable artifacts with explicit audience and promotion rules. Prevent double publish through concurrency, registry existence checks, idempotent workflow state and immutable version ownership. Never overwrite released versions; handle partial publication across multiple registries/packages by reconciliation and documented roll-forward/withdraw/deprecate policy.

Monorepo releases follow actual package dependency and consumer compatibility; independent or synchronized versions are product decisions. Changelogs and migration guidance describe caller-visible behavior and breaking changes rather than commit prefixes alone.

Rollback may mean channel/tag re-point, deploy prior artifact, yank/deprecate, compatibility release or data recovery; many registries and consumers make true rollback impossible. Verify prior artifact integrity and data/API/schema compatibility and avoid mutable `latest` as the only recovery path.

Report policy and channels, version decision, artifact/provenance model, publication concurrency/idempotency, partial-failure recovery, changelog/migration changes, actual checks and residual irreversible consumer/registry risk.
