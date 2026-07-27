---
name: infrastructure-as-code
description: Implement Terraform, OpenTofu, Pulumi, CDK, or repository-native infrastructure code with brownfield adoption, state safety, policy, CI plans, and controlled apply. Use when IaC repository changes are requested.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "exact accounts/projects/regions, existing resources and state, installed tool/provider, desired resources, mutation approval"
---

Implement infrastructure as code for $ARGUMENTS.

## Resolve reality before mutation

Read instructions, manifests/lockfiles, IaC modules/stacks, provider and CLI pins, backend/state configuration, CI, policies and deployment ownership. Resolve exact account/project/subscription, region, workspace/stack, credentials and current state serial/version. Refresh or inspect against the target with the repository's supported workflow immediately before interpreting a plan; a saved stale plan or guessed target is unsafe.

For brownfield resources, inventory ownership and drift before authoring. Import or adopt one exact resource at a time using the installed tool's supported mechanism, reconcile configuration to observed state, and review the post-import plan. Never create a duplicate to “bring it under IaC.” Do not claim all infrastructure is managed unless inventory proves it.

Preserve repository tool/provider pins and verify capabilities from installed CLI/schema/provider docs. For greenfield, use `scripts/framework-stack-context.py`; once the selection is accepted and generated, its committed manifest/configuration and resolved provider/tool lockfiles become the continuing authority for subsequent work until a separately authorized upgrade. S3 backend locking options have evolved; use the capability supported by the pinned Terraform/OpenTofu/backend and current official documentation rather than prescribing a remembered DynamoDB pattern.

## Safe design and apply

- Derive resource types, database engines/versions, instance sizes, retention, backup, encryption, deletion protection and lifecycle policy from requirements, provider capability, data criticality and cost—not fixed examples.
- Split state by ownership/blast radius and dependency lifecycle, not a universal directory template. Protect state as sensitive data with least privilege, encryption, locking/versioning and recovery tests.
- Treat secrets as references or encrypted sensitive values while recognizing that many IaC tools still persist values in state. Minimize and restrict state exposure.
- Review create/update/replace/delete, dependencies, data migration, downtime, quotas and cost. Unknowns and refresh failures are stop conditions for consequential apply.
- No blanket `DESTROY`, `-auto-approve`, apply-on-main or cleanup `destroy`. Destructive actions require exact target resolution, explicit scope, backup/restore, approval and rollback/recovery.
- CI plan/apply roles must be separate and least privilege. Untrusted PRs receive no write credentials/state mutation and cannot publish a trusted plan artifact.

Apply only when the user authorized external mutation and the repository workflow's approvals are satisfied. Ensure the approved plan is fresh and bound to the same commit, variables, provider locks, state and target used for apply; handle cancellation/partial apply by refreshing and reconciling before retry.

## Verification and output

Run format/validate/policy/static checks, inspect a fresh plan, and where authorized verify provider-visible resource identity, health, security, drift and rollback/recovery. Test modules in isolated owned targets with exact cleanup. Report target and ownership evidence, tool/provider/state versions, imports, plan summary, approvals, actual external changes, checks, remaining unmanaged/drifted resources and recovery steps.
