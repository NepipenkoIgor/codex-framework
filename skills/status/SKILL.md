---
name: status
description: Show current work status — active spec rows, what is done, what is failing, and what should happen next
metadata:
  version: 2.0
  user-invocable: true
  argument-hint: "[issue-number]"
---

# /status — Current Work Status

## What this does

Answers "where are we and what's left?" by reading the current spec and summarizing progress.

## Orchestrator Instructions

When user invokes `/status [arg]`:

1. Find the active spec:
   - If arg is given, use `.codex/specs/{arg}/spec.md`.
   - If no arg is given, scan `.codex/specs/*/spec.md` and pick the most recently active spec, or list candidates if several are still open.
   - If none are found, report that there is no active spec.

2. Read `spec.md` and summarize:
   - done rows
   - failing rows
   - unverified rows
   - next recommended action

3. Suggest the next step:
   - failing rows -> suggest a fix step
   - only visual unverified rows -> suggest `/verify`
   - all rows passing -> indicate the work is ready for the next delivery step

## Quality Bar

- Report facts from specs, diffs, CI, or local checks; avoid guessing.
- Separate done, failed, pending, blocked, and unverified work.
- Prefer one clear next action over a long menu.
- Mention stale or missing specs explicitly.
- Keep output short enough to act on immediately.

## Rules

- Stay read-only.
- Do not mark work done unless the spec or verification evidence says so.
- Do not hide failed or unverified visual rows.
- Do not run broad expensive checks unless the user asked for verification rather than status.
- Do not mutate `.codex/specs`, memory, branch state, or project files from this skill.
- Treat missing or stale specs as a finding, not as permission to infer success.

## Verification

- Confirm the spec path used.
- If git changes exist, mention that status may include uncommitted work.
- If no spec exists, report the fallback evidence used, or say that status is unavailable.

## Output Contract

Use concise status fields:

- Status: done | partial | blocked
- Changed: none
- Spec: path or none
- Done: count/summary
- Failed: count/summary
- Pending: count/summary
- Next: single recommended action
- Notes: staleness, missing evidence, or none

## Safety Notes

- Status output is evidence, not authority. If evidence conflicts with the code, say which source is newer.
- If GitHub, CI, or browser capability is unavailable, report the missing capability and use local evidence only.
