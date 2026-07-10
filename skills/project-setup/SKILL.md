---
name: project-setup
description: Set up a repository and project workflow with labels, milestones, branch rules, templates, and Codex project instructions
metadata:
  version: 2.0
  argument-hint: "organization, repository name, tech stack, team members, delivery phases"
---

Set up the project for $ARGUMENTS.

## Tool Preference

- Prefer structured GitHub tools when available.
- Use `gh` CLI for operations not covered by structured tools.
- For local framework adoption, use the Codex framework bootstrap files and scripts.

## Workflow

1. Gather project requirements.
2. Present the full setup plan before executing.
3. On approval, create or configure the repository and workflow assets.
4. Bootstrap project-local `AGENTS.md` instructions when requested.
5. Report results with links and changed files.
6. Verify required local files, remote settings, and documented next steps.

## Setup Scope

- repository creation
- label system
- milestones
- branch protection guidance
- issue and PR templates
- optional project board setup
- Codex project instruction bootstrap

## Codex Framework Bootstrap

If the user wants the repository prepared for this framework:

1. Run `scripts/bootstrap-project.sh <target-dir>` from the framework repo.
2. Review the generated project `AGENTS.md` and `.codex/agents/` profiles.
3. Add project-specific rules, test commands, and architecture notes.

## Constraints

- Never create external resources without explicit approval.
- Never overwrite an existing project `AGENTS.md` without confirmation.
- Keep traceability back to the source requirements or estimate.
- Prefer repo-native templates and scripts over one-off setup.
- Do not hardcode organization secrets, tokens, or environment-specific values in committed files.
- Keep branch, label, issue, and PR conventions consistent with the team workflow.

## Quality Bar

- Setup should make the next contributor faster, not add ceremonial process.
- Use minimal templates that encode real expectations.
- Keep project instructions specific to the repo stack, commands, architecture, and quality gates.
- Document local and remote setup separately.
- Leave a clear verification path.

## Verification

- Check generated files exist and do not overwrite unrelated content.
- Confirm the native agent profiles and hooks match the requested workflow.
- Run `scripts/framework-health.sh` after framework-local changes.

## Output Contract

Status: done | partial | blocked
Created/changed: [files, repo settings, templates]
Approvals: [external actions approved or skipped]
Verification: [doctor/checks/manual confirmation]
Next: [follow-up setup step]
Notes: [risks or missing permissions]
