## Goal
Short, outcome-focused objective.

## Route
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
- Prefer a short prose handoff over `Summary / Verification / Notes` headings.
- Start with what changed and why in one compact paragraph.
- Keep verification compact and concrete.
- Mention blockers or residual risk only if they matter.
- Sound like a teammate, not a generated changelog.

## Output Contract
- Status: done | partial | blocked
- Requirement: [restated requirement or `not required`]
- Current behavior: [observed behavior or `not required`]
- Mismatch: [why prior/current behavior was wrong or `none`]
- Fix intent: [correction applied or `none`]
- Changed: [file paths]
- Notes: [blockers or non-obvious decisions only]
