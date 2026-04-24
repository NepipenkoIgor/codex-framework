# Project Codex Instructions

This project uses the AI Codex Framework.

## Framework Source

Reference framework assets from:

`/Users/igornepipenko/work/ai-codex-framework`

Primary framework docs:

- `/Users/igornepipenko/work/ai-codex-framework/CODEX.md`
- `/Users/igornepipenko/work/ai-codex-framework/CODEX.concepts.md`
- `/Users/igornepipenko/work/ai-codex-framework/CODEX.skills.md`
- `/Users/igornepipenko/work/ai-codex-framework/CODEX.capabilities.md`
- `/Users/igornepipenko/work/ai-codex-framework/ORCHESTRATOR_REFERENCE.md`
- `/Users/igornepipenko/work/ai-codex-framework/agents`
- `/Users/igornepipenko/work/ai-codex-framework/skills`

## Project Rules

- Read existing code before editing.
- Follow local conventions over generic preferences.
- Keep changes narrow and verifiable.
- Use findings-first review style when reviewing.
- State anything not tested or not verified.

## Suggested Workflow

1. Detect the project stack with:
   `/Users/igornepipenko/work/ai-codex-framework/scripts/detect-project-stack.sh`
2. Check runtime capabilities with:
   `/Users/igornepipenko/work/ai-codex-framework/scripts/capabilities.sh`
3. Generate a task brief with:
   `/Users/igornepipenko/work/ai-codex-framework/scripts/task-brief.sh --task "<task>"`
4. Choose a role brief from the framework `agents/` directory.
5. Apply the skills indicated by the task brief and `CODEX.skills.md`.
6. Use the capability fallback path shown in the brief for GitHub, diagnostics, browser, and platform tooling.
7. Verify changes with targeted tests and local checks.
8. Keep project commands in `.codex/project.env` so the framework scripts can run the right checks.
9. For JS/TS projects, prefer `PACKAGE_RUNNER` and `PACKAGE_EXEC` from `.codex/project.env` for direct commands.

## Optional Project Additions

- Add project-specific conventions below.
- Add preferred test commands.
- Add build or dev server notes.
