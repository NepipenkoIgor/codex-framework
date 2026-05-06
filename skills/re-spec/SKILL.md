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
- Preserve verification history for completed rows.
- Keep source links or comment references when new requirements come from review feedback.
- If requirements conflict, mark the row blocked and report the conflict instead of guessing.

## Quality Bar

- Requirement fidelity matters more than speed.
- Changes should be traceable to issue text, comments, or explicit user direction.
- Completed rows remain stable unless the source requirement explicitly changed.
- New rows should be small, testable, and phrased as observable outcomes.
- Visual requirements should retain visual verification markers.

## Verification

- Compare old and new spec rows before writing.
- Confirm completed row counts before and after.
- Confirm no completed rows became pending without explicit justification.
- Run `scripts/spec-status.sh` after the update when available.

## Output Contract

Status: done | partial | blocked
Changed: [.codex/specs/{N}/spec.md]
New rows: [count]
Updated rows: [count]
Preserved completed rows: [count]
Verification: [spec-status or manual diff]
Notes: [conflicts or assumptions]
