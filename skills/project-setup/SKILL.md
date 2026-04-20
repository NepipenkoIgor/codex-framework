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
4. Bootstrap project-local `CODEX.md` instructions when requested.
5. Report results with links and changed files.

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
2. Review the generated project `CODEX.md`.
3. Add project-specific rules, test commands, and architecture notes.

## Constraints

- Never create external resources without explicit approval.
- Never overwrite an existing project `CODEX.md` without confirmation.
- Keep traceability back to the source requirements or estimate.
