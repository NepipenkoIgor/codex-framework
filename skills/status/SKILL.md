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

## Output Contract

Status: done
Changed: none
Notes: [spec summary inline]
