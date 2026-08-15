---
name: project-setup
description: Set up requested local repository workflow files, templates, project instructions, and explicitly authorized remote repository settings. Use when project/repository setup changes are requested; not for creating external resources by implication.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  argument-hint: "existing/new local repository, requested files/settings, hosting owner/repo, team workflow, authorized remote actions"
---

Set up the project for $ARGUMENTS.

## Resolve scope and authority

Read instructions, repository state/remotes, manifests/lockfiles, existing templates/project instructions, CI, branch/release conventions and team requirements. Report only artifacts actually supplied or observed; mark unavailable remotes, conventions, templates, ownership, CI, security guidance or Codex configuration as discovery gaps rather than claiming they were inspected. Distinguish local file changes from remote mutations such as creating a repository/project, labels, milestones, rulesets, secrets, environments or permissions.

The request to “set up a project” authorizes only the clearly requested scope. Do not create a remote repository or other external resources, change permissions/rulesets, invite users, publish, or push without explicit authorization and exact organization/repository targets. Before an authorized consequential remote mutation, preview it and define a read-back plus recoverable revert/compensating procedure for that setting; if the provider cannot roll it back, state the irreversible boundary and obtain explicit acceptance. Report unavailable permissions as blockers.

Use native GitHub integration for GitHub state when available and requested; do not build scripts/wrappers that reproduce native repository, issue, PR, thread or agent orchestration. For local framework adoption, use the repository's existing bootstrap assets only when requested, inspect their output, and never overwrite `AGENTS.md`, profiles, hooks or templates without resolving existing content.

## Minimal useful setup

Create only workflow artifacts that encode real team behavior: focused project instructions, verified commands, issue/PR templates, ownership, release/branch guidance and security/reporting paths. Preserve existing conventions and avoid ceremonial labels, milestones, boards, hooks or agent profiles. Never commit secrets, tokens, user-specific absolute paths or environment values.

For version-sensitive starter configuration, use `scripts/framework-stack-context.py` to resolve supported stable frameworks and production LTS runtimes dynamically from official distribution channels. Validate every resolved framework/runtime version against its exact official release, support, or distribution source and record those sources before generation; do not accept remembered majors or an unspecified resolver source as evidence. After generation and dependency resolution, the new manifest and lockfile become authority. Existing project pins remain authority and upgrades are separate migrations.

## Verification and output

Inspect every local diff, validate template/config schemas and links, run repository health/setup checks, and read back any explicitly changed remote setting through the native integration. Report local files, remote resources/settings actually changed with links, skipped unapproved actions, checks/results, permissions and next steps. Local files are not proof that remote protections or workflows exist.
