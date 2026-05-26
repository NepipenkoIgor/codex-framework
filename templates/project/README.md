# Project Bootstrap Template

Copy these assets into a working repository to adopt the Codex framework quickly.

Suggested bootstrap:

1. Copy `CODEX.md` to the project root.
2. Let the framework auto-create `.codex/project.env` from detected repo commands.
3. Let the framework auto-create `.codex/config.toml` inline hook blocks and the `.codex/hooks.json` adapter artifact.
4. Check required hook wiring with `codex-fw hooks doctor`.
5. Check named-agent wiring with `codex-fw agent validate`.
6. Generate task briefs with `codex-fw brief "<task>"` or `scripts/task-brief.sh --task "<task>"`.
   In user-facing status, say "loading skill `<name>`" for skills and "spawning sub-agent `<name>`" only for real delegation.
7. Adjust `.codex/project.env` only if the detected commands need overrides, then set `PROJECT_COMMANDS_MODE="manual"` to stop auto-refresh.
8. To force a manual refresh of detected commands later, run `codex-fw refresh-commands`.
9. For JS/TS projects, use `PACKAGE_RUNNER` and `PACKAGE_EXEC` from `.codex/project.env` for direct commands.
10. For .NET projects, use the detected `dotnet` commands from `.codex/project.env`.
11. For Flutter projects, use the detected `flutter` commands from `.codex/project.env`.
12. Add project-specific rules below the framework section.
13. Keep the main framework repo as the source of truth for reusable roles and skills.

Optional local additions:

- test command cheatsheet
- architecture notes
- team conventions
- deployment caveats
