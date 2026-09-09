---
name: framework-management
description: Audit and maintain this native Codex framework, including skills, profiles, hooks, setup, documentation, routing, and corpus governance. Use when changing or evaluating the framework itself; do not use for ordinary application implementation or repository setup.
metadata:
  version: 2.2
  argument-hint: "mode (audit/create/update/consolidate/validate), scope, acceptance criteria"
  owner: framework-maintainers
  reviewed: "2026-09-09"
---

# Framework Management

Keep Codex native capabilities authoritative. The framework may add reusable domain knowledge, focused profiles, deterministic safety policy, and validation; it must not recreate planning, goals, model routing, agent lifecycle, Browser/GitHub integration, plugins, MCP, or memory.

## Architecture

```text
AGENTS.md                 closer repository contract
.codex/agents/*.toml      narrow native profiles
skills/*/SKILL.md         task-selected procedures
skills/core.txt           minimal universal catalog
skills/packs/*.txt        opt-in domain catalogs
scripts/framework-*       deterministic validation
README.md                 behavior and installation
```

## Workflow

1. Read the relevant contract, files, maps, and checks before editing; classify the request as audit, create, update, consolidate, deprecate, or validate.
2. Read the current official Codex manual, the complete changelog delta since `docs/native-capability-ledger.json`, and the latest stable release notes. Run the live native-capability check; memory or the installed CLI alone is insufficient.
3. For every relevant native delta, search instructions, profiles, hooks, scripts, skills, plugins, and MCP configuration for overlap. Record adopt, replace, remove, retain with a concrete native gap, or permission-gated.
4. When implementation is authorized, apply safe evidence-backed replacement/removal in the same task. For an explicitly read-only, audit-only, or plan-only request, make no changes: deliver the evidence-backed cleanup plan and leave certification pending. Do not rebuild a native feature behind another wrapper.
5. Before mutation, resolve exact task-owned targets, authority/permissions, ownership, and a reversible effect; preserve approval boundaries and unrelated work.
6. Update affected skills, core/packs, maps, checks, README, and the native-capability ledger together. Verify the actual diff and changed behavior.

The parent owns contracts, shared writes, integration, and final reporting. For token-sensitive work, preserve native caching/compaction and use `scripts/framework-token-budget-check.py`; do not infer savings without provider or native prompt-input evidence.

## Skill governance

A maintained skill needs:

- a unique task and routing boundary with positive and negative cases;
- a concise self-contained core workflow and routed relative references;
- repository discovery before tools or architecture;
- domain constraints, verification, output expectations, owner, and review date;
- no nonexistent profiles, hidden skill chains, or native workflow wrappers.

A scaffold is inventory, not certification. Promote it only after routing, domain/safety counterexamples, version policy, provenance, and every scored dimension have evidence. Prefer one universal baseline plus at most one platform specialization; retire skills natively owned by Codex or an installed trusted plugin.

## Audit and verification

For an audit, consolidation, material corpus/config change, or release, read [references/audit-and-verification.md](references/audit-and-verification.md) before acting. It contains the scoring contract, falsification cases, affected check routing, and exact repository verification suite. Routine localized updates need only their affected checks.

## Create or consolidate

Before adding a skill:

1. Search names, descriptions, headings, and community/vendor sources.
2. Decide whether the need belongs in AGENTS, an existing skill/reference, an opt-in pack, a plugin, or a new skill.
3. Define positive and negative routing cases.
4. Keep `SKILL.md` concise; route provider/version recipes to `references/`.
5. Register only in the narrowest appropriate core or pack.

For consolidation, preserve unique invariants, remove repeated boilerplate, update maps/references, and record replacements in governance documentation.

## Output contract

- Changed: files and decisions
- Consolidated/retired: old-to-new mapping
- Checks: exact commands and results
- Remaining gaps: evidence and risk
- Follow-up: only optional or externally blocked work
