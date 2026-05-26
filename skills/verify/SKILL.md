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

## Workflow

Use the current repo, spec, and capability model as the source of truth. Verify only rows that actually require browser or visual evidence, and keep non-visual requirements on their existing test path.

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

## Constraints

- Do not auto-pass a visual row from code inspection alone.
- Do not ask the user to authenticate until the verifier has confirmed an auth wall.
- Do not start multiple dev servers if one matching local URL is already available.
- Do not update unrelated spec rows.

## Verification Evidence

- Capture the local URL, viewport, route, row ids, and observed result.
- If automation is unavailable, report the missing capability and leave rows unverified.
- When a row fails, include the smallest visual mismatch and the next likely fix area.

## Output Contract

- Status: done | partial | blocked
- Changed: `.codex/specs/{N}/spec.md` or none
- Verified: row ids and result
- Blocked: missing browser/dev/auth capability or none
- Notes: failures, residual risk, or none
