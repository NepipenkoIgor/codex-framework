## Goal
Short, outcome-focused objective.

## Route
- Route badge:
- Role:
- Model:
- Reasoning:

## Stack
- Detected:
- Framework signals:

## Scope
Files, modules, or system slice owned by this task.

## Commands
- Package runner:
- Direct local binaries:
- Test:
- Lint:
- Build:
- Dev:

## Constraints
- Respect existing project patterns.
- Do not revert unrelated changes.
- Keep the implementation narrow.
- For JS/TS repos, prefer the detected package runner and local binary executor above for direct commands.
- For requirement-sensitive tasks, restate the requirement and mismatch before editing.

## Skills
- Primary:
- Supporting:

## Spec
- Path:
- Status:

## Requirement Check
- Required:
- Requirement:
- Current behavior:
- Mismatch:
- Fix intent:

## Verification
- Required checks:
- Optional checks:

## Closeout Style
- Use the canonical output contract below for final task reports.
- Keep section names and ordering exactly as shown.
- Use `not required`, `none`, or `not run` instead of omitting sections.
- Keep prose compact and concrete.
- Do not use the legacy label format `Status: ...`, `Requirement: ...`, or `Fix intent applied: ...`.

## Output Contract
✅ [route-badge] — done | partial | blocked

**Requirement**
[restated requirement or `not required`]

**Current Behavior**
[observed behavior or `not required`]

**Mismatch**
[why the previous/current behavior was wrong or `none`]

**Fix Intent**
[short statement of the correction]

**Changed**
- [file or behavior changed]

**Verification**
- [command/check run, or `not run` with reason]

**Notes**
- [blockers, residual risk, pre-existing unrelated changes, or `none`]
