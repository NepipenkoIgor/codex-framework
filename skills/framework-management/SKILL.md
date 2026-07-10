---
name: framework-management
description: Manage the AI Codex Framework by auditing, creating, and maintaining native agents, skills, hooks, scripts, and validation.
metadata:
  version: 1.0
  argument-hint: "task type (health-check/new-skill/validate/gap-analysis), scope (full/specific area)"
---

Manage the AI Codex Framework for $ARGUMENTS.

## Framework Architecture

The core file relationships in this repo are:

```text
AGENTS.md                <- native Codex operating contract
`.codex/agents/*.toml`   <- native subagent profiles
README.md                <- framework overview and usage
skills/*/SKILL.md        <- reusable skill definitions
scripts/*.sh             <- explicit framework checks and setup helpers
templates/*.md           <- reusable task scaffolds
```

The consistency chain is:

`AGENTS.md` delegation policy -> `.codex/agents/*.toml` behavior -> `skills/*/SKILL.md` quality -> executable checks and `README.md` usage documentation.

## Use This Skill For

- framework health checks
- native agent profile creation or normalization
- skill creation or cleanup
- delegation and verification updates
- structural consistency checks

## Workflow

1. Read the current framework files before changing them.
2. Check for duplicates before creating a new role or skill.
3. Keep `AGENTS.md`, `README.md`, and affected native agent or skill aligned.
4. Run `scripts/framework-health.sh` after meaningful framework edits.

## Create Or Register

### New skill

1. Check for overlap with existing skills.
2. Create `skills/<name>/SKILL.md` with frontmatter and practical instructions.
3. Reference it from the relevant native agent instructions only when the skill is a stable baseline.
4. Update `README.md` if the new skill affects public usage.

### New native agent profile

1. Check if an existing native profile already covers the need.
2. Create or update `.codex/agents/<name>.toml` with a narrow responsibility and sandbox mode.
3. Add delegation guidance to `AGENTS.md` when needed.
4. Update `README.md` if the framework surface changed.

## Health Check

Validate:

1. required top-level files exist
2. native agent profiles are valid and purpose-specific
3. skill files exist and have frontmatter
4. native runtime configuration is parsed by Codex
5. scripts needed by the framework are present
6. docs match the actual repository structure

## Verification

- Run `scripts/framework-eval.sh` for native-agent, hook, or skill changes.
- Run `scripts/framework-drift-check.sh` after policy, role, or source-of-truth changes.
- Run `scripts/framework-health.sh` before close-out.
- For corpus changes, run `scripts/framework-skill-corpus-audit.sh` and inspect the lowest-scoring skills.

## Constraints

- Only modify framework files in this repo.
- Do not introduce duplicates without a clear reason.
- Prefer direct, verifiable improvements over speculative redesign.
- Do not make docs-only claims that are not backed by scripts, native profiles, skills, or runtime checks.
- Do not weaken permission, git, or PR safeguards to make checks pass.

## Output Contract

- Changed:
- Checks:
- Remaining gaps:
- Follow-up:
