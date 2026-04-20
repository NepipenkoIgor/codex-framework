---
name: framework-management
description: Manage the AI Codex Framework by auditing, creating, and maintaining role briefs, skills, scripts, and routing guidance.
metadata:
  version: 1.0
  argument-hint: "task type (health-check/new-skill/validate/gap-analysis), scope (full/specific area)"
---

Manage the AI Codex Framework for $ARGUMENTS.

## Framework Architecture

The core file relationships in this repo are:

```text
CODEX.md                 <- global orchestration and routing
README.md                <- framework overview and usage
agents/*.md              <- role briefs for Codex delegation
skills/*/SKILL.md        <- reusable skill definitions
scripts/*.sh             <- explicit framework checks and setup helpers
templates/*.md           <- reusable task scaffolds
```

The consistency chain is:

`CODEX.md` routing guidance -> `agents/*.md` role briefs -> `skills/*/SKILL.md` existence and quality -> `README.md` usage documentation.

## Use This Skill For

- framework health checks
- role brief creation or normalization
- skill creation or cleanup
- routing updates
- structural consistency checks

## Workflow

1. Read the current framework files before changing them.
2. Check for duplicates before creating a new role or skill.
3. Keep `CODEX.md`, `README.md`, and the affected role or skill aligned.
4. Run `scripts/framework-health.sh` after meaningful framework edits.

## Create Or Register

### New skill

1. Check for overlap with existing skills.
2. Create `skills/<name>/SKILL.md` with frontmatter and practical instructions.
3. Reference it from the relevant role brief and `CODEX.md` when needed.
4. Update `README.md` if the new skill affects public usage.

### New role brief

1. Check if an existing role already covers the need.
2. Create or update `agents/<name>.md`.
3. Add its routing guidance to `CODEX.md` when needed.
4. Update `README.md` if the framework surface changed.

## Health Check

Validate:

1. required top-level files exist
2. role briefs are readable and purpose-specific
3. skill files exist and have frontmatter
4. scripts needed by the framework are present
5. docs match the actual repository structure

## Constraints

- Only modify framework files in this repo.
- Do not introduce duplicates without a clear reason.
- Prefer direct, verifiable improvements over speculative redesign.
