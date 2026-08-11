---
name: framework-management
description: Audit and maintain this native Codex framework, including skills, profiles, hooks, setup, documentation, routing, and corpus governance. Use when changing or evaluating the framework itself; do not use for ordinary application implementation or repository setup.
metadata:
  version: 2.1
  argument-hint: "mode (audit/create/update/consolidate/validate), scope, acceptance criteria"
  owner: framework-maintainers
  reviewed: "2026-08-06"
---

# Framework Management

Keep Codex native capabilities authoritative. The framework may add reusable domain knowledge, focused profiles, deterministic safety policy, and validation, but must not recreate planning, goals, model routing, agent lifecycle, browser control, GitHub workflows, or memory.

## Architecture

```text
AGENTS.md                 operating contract
.codex/agents/*.toml      narrow native profiles
skills/*/SKILL.md         task-selected procedural knowledge
skills/core.txt           small universal default set
skills/packs/*.txt        opt-in domain sets
scripts/framework-*.sh    deterministic validation
README.md                 public behavior and installation
```

## Workflow

1. Read the relevant contract, files, maps, and checks before editing.
2. Classify the request: audit, create, update, consolidate, deprecate, or validate.
3. Check native capability ownership and semantic overlap before creating anything.
4. Keep the parent responsible for contracts, shared writes, integration, and final reporting.
5. Before a material mutation, resolve exact task-owned targets, write authority/permissions and ownership, then define a reversible diff or effect-appropriate recovery/rollback; preserve approval boundaries.
6. Update affected skills, core/packs, maps, checks, and README together.
7. Verify the actual diff and run the checks listed below.

## Skill Governance

A maintained skill must have:

- a unique task and routing boundary;
- a description explaining what it does, when to use it, and important exclusions;
- a self-contained core workflow, with optional detail in relative `references/` paths;
- repository-context discovery before prescribing tools or architecture;
- domain-specific constraints, verification, and output expectations;
- an owner and review date in metadata for locally maintained skills;
- no dependency on nonexistent profiles or hidden multi-skill chains.

A generated scaffold is inventory, not certification. Promote it to reviewed only after natural routing cases, domain and safety counterexamples, version/capability policy, provenance, and every scored dimension have evidence. Structural schema success alone cannot justify certification.

Prefer one universal baseline plus at most one platform specialization. Do not create a separate skill for every combination of framework and mode. Retire a skill when native Codex or an installed trusted plugin owns the capability.

## Audit Mode

Score each dimension from 1 to 10 and cite concrete files or executable evidence:

1. Native ownership: no wrappers around native planning, goals, git, GitHub, browser, plugins, or agent lifecycle.
2. Routing: descriptions are precise, mutually distinguishable, and tested with positive and negative prompts.
3. Skill design: small core workflow, progressive disclosure, repo-first decisions, no textbook dumps.
4. Coordination: bounded delegation, explicit ownership, parent-held contracts, isolated parallel writers.
5. Verification: structural, semantic, safety, reference, profile, staleness, and routing checks.
6. Runtime safety: exact targets, task-owned cleanup, approvals preserved, no broad destructive recipes.
7. Maintainability: owner, review date, upstream provenance, deprecation and replacement paths.

Report strengths, evidence-backed gaps, priorities, checks, and residual risk. A high structural score is not evidence of semantic quality.

Also falsify native ownership and execution safety: reject shell or prompt wrappers that reimplement native planning, goals, model selection, browser/GitHub integration, memory, or agent lifecycle; reject parallel writers without isolated worktrees; and verify dynamic resolver sources against current official channels rather than a remembered release. Record whether each configured channel is stable/LTS or preview and never treat a preview channel as stable. Existing projects preserve their manifest/lockfile pins and use matching documentation; live stable/LTS resolution is for greenfield selection or an explicitly authorized migration.

## Create or Consolidate

Before adding a skill:

1. Search names, descriptions, headings, and community/vendor sources.
2. Decide whether the need belongs in AGENTS, an existing skill/reference, an opt-in pack, a plugin, or a new skill.
3. Define positive and negative routing cases.
4. Prefer a concise `SKILL.md`; move provider/version recipes to `references/`.
5. Register it only in the narrowest appropriate core or pack.

For consolidation, preserve unique invariants, remove repeated boilerplate, update references and maps, and record replacements in the governance documentation.

## Verification

Run after meaningful corpus changes:

For install/update collision handling, execute a task-owned fixture that attempts to collide with an existing user skill and prove the existing file remains byte-identical and the operation performs no write.

```bash
bash scripts/framework-skill-governance.sh
bash scripts/framework-version-drift-check.sh
bash scripts/framework-skill-corpus-audit.sh
bash scripts/framework-eval.sh
bash scripts/framework-drift-check.sh
bash scripts/surface-parity-check.sh
bash scripts/framework-health.sh
bash scripts/framework-doctor.sh
bash scripts/framework-skill-loader-live-eval.sh
bash scripts/framework-release.sh
```

Use `scripts/framework-live-eval.sh` when routing, profiles, or agent ownership changes and live Codex usage is acceptable.
Use `scripts/framework-skill-routing-live-eval.sh` after skill descriptions, core/packs, consolidation, or retirement mappings change.
Use `${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context project <path>` before applying version-sensitive guidance to an existing project (or the repository script while developing this framework). Use `scripts/framework-version-drift-check.sh --live` after resolver or release-source changes; it exercises live channels without persisting a snapshot.

## Output Contract

- Changed: files and decisions
- Consolidated or retired: old skill to replacement mapping
- Checks: exact commands and results
- Remaining gaps: evidence and risk
- Follow-up: only work that is genuinely optional or externally blocked
