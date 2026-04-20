---
name: verify
description: Resume or trigger browser verification for the current spec. Checks for visual rows first and skips browser work if nothing visual remains.
metadata:
  version: 2.0
  user-invocable: true
  argument-hint: "[issue-number]"
---

# /verify — Browser Verification

## What this does

Triggers or resumes browser verification for the current spec's visual rows.

## Orchestrator Instructions

When user invokes `/verify [arg]`:

1. Find the spec:
   - If arg is given, use `.codex/specs/{arg}/spec.md`.
   - If no arg is given, check the current branch name for an issue number, then scan `.codex/specs/*/spec.md` for unverified visual rows.
   - If multiple specs qualify, list them and ask which one to use.

2. Check for visual rows first:
   - Read `spec.md`.
   - If `Visual: no` or there are no unverified visual rows, stop and report that no browser verification is needed.

3. Check browser tooling availability:
   - If browser automation is unavailable, report that clearly and stop.

4. Check localhost on common dev ports:
   - If an app is already running, use it.
   - If not, attempt a local auto-start from project scripts and report failure if startup does not succeed.

5. Check for auth walls:
   - After navigation, inspect the current page immediately.
   - If a login or magic-link wall blocks the target flow, stop and tell the user to authenticate before rerunning `/verify`.

6. Verify only the visual rows:
   - Compare the live page against the visual rows in the spec.
   - Update `spec.md` with pass/fail results.

7. Report updated status:
   - If failures are found, suggest the next fix step.

## Output Contract

Status: done | partial | blocked
Changed: [.codex/specs/{N}/spec.md]
Notes: [rows verified, any failures found]
