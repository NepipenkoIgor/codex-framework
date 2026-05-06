# Project Bootstrap Template

Copy these assets into a working repository to adopt the Codex framework quickly.

Suggested bootstrap:

1. Copy `CODEX.md` to the project root.
2. Let the framework auto-create `.codex/project.env` from detected repo commands.
3. Generate task briefs with `codex-fw brief "<task>"` or `scripts/task-brief.sh --task "<task>"`.
4. Adjust `.codex/project.env` only if the detected commands need overrides, then set `PROJECT_COMMANDS_MODE="manual"` to stop auto-refresh.
5. To force a manual refresh of detected commands later, run `codex-fw refresh-commands`.
6. For JS/TS projects, use `PACKAGE_RUNNER` and `PACKAGE_EXEC` from `.codex/project.env` for direct commands.
7. For .NET projects, use the detected `dotnet` commands from `.codex/project.env`.
8. For Flutter projects, use the detected `flutter` commands from `.codex/project.env`.
9. Add project-specific rules below the framework section.
10. Keep the main framework repo as the source of truth for reusable roles and skills.

Optional local additions:

- test command cheatsheet
- architecture notes
- team conventions
- deployment caveats
