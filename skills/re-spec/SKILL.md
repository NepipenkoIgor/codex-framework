---
name: re-spec
description: Merge new issue comments into an existing Codex spec without wiping completed work
metadata:
  version: 2.0
  user-invocable: true
  argument-hint: "<issue-number>"
---

# /re-spec — Merge New Requirements Into Existing Spec

## What this does

Updates an existing spec with new issue comments or changed requirements while preserving completed rows.

## Orchestrator Instructions

When user invokes `/re-spec <N>`:

1. Read the latest issue body and comments.
2. Read `.codex/specs/{N}/spec.md`.
3. Diff the new issue content against the current spec rows.
4. Preserve existing completed rows.
5. Append new requirements as new pending rows.
6. Update changed pending rows when the issue clarified or changed them.
7. Update the spec sync date.

If the spec does not exist, fall back to `/spec <N>`.

## Rules

- Never reset completed work to pending.
- Never remove rows unless the issue explicitly invalidates them and that change is documented.
- Only add genuinely new requirements.

## Output Contract

Status: done | partial | blocked
Changed: [.codex/specs/{N}/spec.md]
Notes: [new rows count, updated rows count]
