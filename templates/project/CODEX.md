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
- In Desktop app sessions, load compact local memory before broad repo exploration:
  `/Users/igornepipenko/work/ai-codex-framework/scripts/memory-state.sh context "<current task>"`
- After non-trivial Desktop app tasks, record a compact local episode with:
  `/Users/igornepipenko/work/ai-codex-framework/scripts/memory-state.sh add-episode --task "<task>" --summary "<outcome>" --files "<csv>" --verification "<csv>" --tags "<csv>"`

## Suggested Workflow

1. Detect the project stack with:
   `/Users/igornepipenko/work/ai-codex-framework/scripts/detect-project-stack.sh`
2. Check runtime capabilities with:
   `/Users/igornepipenko/work/ai-codex-framework/scripts/capabilities.sh`
3. Load compact local memory with:
   `/Users/igornepipenko/work/ai-codex-framework/scripts/memory-state.sh context "<task>"`
4. Generate a task brief with:
   `/Users/igornepipenko/work/ai-codex-framework/scripts/task-brief.sh --task "<task>"`
5. Choose a role brief from the framework `agents/` directory.
6. Apply the skills indicated by the task brief and `CODEX.skills.md`.
7. Use the capability fallback path shown in the brief for GitHub, diagnostics, browser, and platform tooling.
8. Verify changes with targeted tests and local checks.
9. Keep project commands in `.codex/project.env` so the framework scripts can run the right checks.
10. For JS/TS projects, prefer `PACKAGE_RUNNER` and `PACKAGE_EXEC` from `.codex/project.env` for direct commands.
11. For .NET projects, use the detected `dotnet` commands from `.codex/project.env`.
12. For Flutter projects, use the detected `flutter` commands from `.codex/project.env`.
13. Use product-facing PR branch prefixes: `feature/`, `fix/`, `chore/`, `docs/`, or `test/`; never use tool-revealing prefixes such as `codex/`.
14. Create PRs through `codex-fw pr-create` so the branch is rebased, pushed, and opened with explicit base/head metadata.

## Optional Project Additions

- Add project-specific conventions below.
- Add preferred test commands.
- Add build or dev server notes.
