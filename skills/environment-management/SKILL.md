---
name: environment-management
description: Implement environment configuration, secrets, previews, promotion, parity, isolation, and owned cleanup across local and hosted environments. Use when environment-management repository or explicitly authorized external changes are requested.
metadata:
  owner: codex-framework
  reviewed: "2026-09-09"
  version: 2.2
  argument-hint: "exact environments/accounts, config and secret systems, preview ownership, promotion/cleanup requirements"
---

Implement environment management for $ARGUMENTS.

## Establish environment ownership

Read instructions, manifests/lockfiles, environment/config schemas, secret references, deployment/IaC, preview lifecycle, CI identities and data policy. Resolve each exact account/project/cluster/namespace/database/domain and owner. Separate local file changes from external mutations; require explicit authorization for creating, rotating, promoting or deleting hosted resources/secrets.

Preserve installed tools and verify capabilities from local CLI/schema or matching official docs. Do not mandate Docker Compose, Vault, a cloud service, ports, database/runtime versions, environment tiers or directory layouts. For greenfield dependencies use `scripts/framework-stack-context.py`.

## Configuration, secrets and previews

- Keep one typed configuration contract with environment-specific values and validation; do not commit secrets or silently default security-critical values.
- Scope identity, secrets, data, quotas and external endpoints per environment. Production-derived data requires approved minimization/transformation/retention.
- Secret rotation must follow the actual provider/consumer capability. Dual-version acceptance is safe only while both credentials are valid and intended; never fall back to a revoked or compromised credential. Coordinate issuance, consumer rollout, verification, revocation and recovery with concurrency and audit evidence.
- Preview resources need an unforgeable run/PR owner, exact inventory and bounded cost/lifetime derived from policy. Cleanup deletes only recorded owned resources and handles forks, renamed/closed PRs, partial provisioning and retry. Never delete by broad name prefix alone.
- Promotion uses immutable artifact identity and explicit configuration/schema compatibility. Staging parity and soak duration are risk-based evidence, not universal requirements or fixed time.

Design rollback across code, config, secret, database/data, queue/event and external dependency state. Cancellation or partial provisioning triggers reconciliation from provider-visible state before retry or cleanup.

## Verification and output

Validate schemas and secret references without exposing values. Add executable compatibility cases that bind an immutable artifact identity to the exact configuration/schema version, accept a supported pairing, and reject an incompatible or stale pairing. These compatibility tests remain required even when promotion itself is out of scope. Prove secret non-exposure with repository, generated-config, build-artifact, log/diagnostic, and retained-output scanning/redaction checks that use safe test markers rather than authentic secrets. Also test isolation, revoked-secret behavior, rotation partial failure, preview collision/cleanup, permission denial, restore and rollback. Where external actions are authorized, read back exact resource state. Report targets/ownership, configuration and secret provenance, changes, approvals, cleanup inventory, checks/results and residual provider/data risks.
