---
name: devops-ci
description: Design and implement repository CI/CD, containers, build artifacts, credentials, caches, concurrency, deployment gates, and cancellation recovery. Use when CI/CD repository changes are requested.
metadata:
  owner: codex-framework
  reviewed: "2026-09-21"
  version: 2.2
  argument-hint: "CI provider, repository pins, events/trust model, build/deploy targets, artifacts, approvals and rollback"
---

Implement CI/CD for $ARGUMENTS.

Read instructions, manifests/lockfiles/runtime pins, existing workflows/actions/images, branch rules, artifact/deploy model, environments/secrets, runner trust, caches and authoritative commands. Preserve repository commands and supported runtime matrix. Resolve action/image/tool versions dynamically from installed policy and official sources; pin by immutable revision/digest where supply-chain policy requires it.

Derive required hosted checks from workflows and branch/merge-queue policy, and map each to its local equivalent. Contract, code, fixtures, environment declarations and tests change together. Reach local-ready before push, while honestly leaving PR-triggered or hosted-only checks pending. Immediately before merge, fetch the target and apply the project's declared rebase/merge/queue strategy; rerun every invalidated local gate. Bind local and hosted checks to one tested candidate SHA, then require provider-verified candidate-to-final-commit or artifact mapping, preserved content identity, and ancestry/readback; rebase, squash and merge queues may legitimately produce a different final SHA. Never treat auto-merge configuration or a successful request as check completion.

Model each trigger's trust: internal push, trusted PR, fork PR, scheduled/manual and reusable workflow. Untrusted code must not receive write tokens, OIDC cloud roles, environment/registry secrets, privileged runners, trusted cache write or artifact promotion. OIDC still requires exact subject/audience/repository/environment claims and least-privilege cloud policy.

Define job permissions explicitly. Artifacts and caches need provenance, integrity, retention, sensitive-data review and trust-domain isolation. A build from untrusted code cannot become a deployable trusted artifact merely because tests passed.

Concurrency and cancellation must respect mutation boundaries. Cancelling a build is different from cancelling publish, migration, apply or deploy. Serialize consequential operations, make them idempotent where possible, record ownership and reconcile actual external state after partial/cancelled mutation before retry or rollback.

Use repository-derived timeouts/matrices/caches rather than fixed recipes. Verify locked reproducible builds, generated outputs, artifact identity/SBOM/signature where required, approvals, deployment validation and rollback. Do not echo secrets or upload unsafe logs/profiles.

Report triggers/trust matrix, permissions and OIDC claims, pins/provenance, job/dependency/concurrency model, artifacts/caches/retention, partial-mutation recovery, changed files, checks and residual provider/runner risks.
