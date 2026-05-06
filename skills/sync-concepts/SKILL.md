---
name: sync-concepts
description: Sync CONCEPTS.md with the actual framework state after a framework edit session
metadata:
  version: 2.0
  user-invocable: true
  argument-hint: ""
---

# /sync-concepts — Update CONCEPTS.md After Framework Changes

## What this does

Updates `CONCEPTS.md` to reflect meaningful framework changes made during the current session.

## Orchestrator Instructions

When user invokes `/sync-concepts`:

1. Run `git diff --stat HEAD` to identify changed framework files.
2. Read the diffs for `CODEX.md`, `README.md`, `agents/`, `skills/`, `scripts/`, `templates/`, and `CONCEPTS.md` when changed.
3. Read the current `CONCEPTS.md`.
4. Update:
   - core invariants if framework behavior changed
   - architectural decisions if a new framework direction was adopted
   - known footguns if a new recurring risk was discovered
   - recent state changes with concise dated notes

If no meaningful framework files changed, report that there is nothing to sync.

## Quality Bar

- Sync only durable framework concepts, not every implementation detail.
- Prefer concise, source-linked notes over broad restatements.
- Preserve existing invariants unless the code changed enough to invalidate them.
- Keep terminology aligned with `CODEX.md`, `CODEX.concepts.md`, and `ORCHESTRATOR_REFERENCE.md`.
- Mention risk or follow-up when concepts and implementation are not fully aligned.

## Rules

- Keep entries concise and factual.
- Do not add noise for trivial formatting-only changes.
- Refine invariants instead of deleting them casually.
- Do not overwrite user-authored notes without a clear reason.
- Do not present an implementation experiment as a settled concept.

## Verification

- Compare updated `CONCEPTS.md` against changed framework files.
- Confirm no stale contradictory concept remains.
- Run `scripts/framework-health.sh` when the sync reflects behavior changes.
- Use `git diff -- CONCEPTS.md` to make sure only meaningful text changed.

## Output Contract

Status: done | partial | blocked
Changed: [CONCEPTS.md]
Verification: [diff and checks]
Notes: [high-level sync summary]
