# AI Codex Framework

Codex-first framework for running a reusable engineering workflow with:

- Codex-native global instructions in `CODEX.md`
- reusable role briefs in `agents/`
- a large portable skill library in `skills/`
- script-based checks in `scripts/`

This is the Codex counterpart to the Claude framework in `ai-skills`. It keeps the portable knowledge layer and replaces Claude-only runtime hooks with explicit instructions and scripts.

## What Was Ported

- `agents/` copied from `ai-skills` as the initial role library
- `skills/` copied from `ai-skills` as the initial skill library

The portable content is preserved first. The Codex-specific behavior is defined by the files below.

## Codex-Native Files

- `CODEX.md`
  Codex orchestration rules, routing, execution policy, and output style.
- `CODEX.skills.md`
  Explicit skill injection rules used by generated task briefs.
- `CODEX.capabilities.md`
  Capability model for runtime tools such as GitHub access, diagnostics, browser automation, and platform integrations.
- `CONCEPTS.md`
  Framework invariants, architectural decisions, and migration notes.
- `scripts/setup.sh`
  Installs the framework into `~/.codex/skills/ai-codex-framework`.
- `scripts/detect-project-stack.sh`
  Reads local manifests and prints a stack summary.
- `scripts/framework-health.sh`
  Validates role files, skills, and key framework docs.
- `routing.yaml`
  Machine-readable routing and verification defaults.
- `scripts/codex-fw.sh`
  Unified framework entrypoint for health, preflight, routing, specs, PR checks, and safe commits.
- `scripts/task-brief.sh`
  Generates structured execution briefs with route, stack, skills, commands, spec status, and verification expectations.
- `scripts/capabilities.sh`
  Reports runtime capabilities, local fallbacks, and configured-vs-validated auth state for each class of tool.
- `scripts/github-status.sh`
  Checks whether GitHub CLI and auth are usable in the current environment.
- `scripts/github-issue-fetch.sh`
  Fetches issue context via `gh` for issue-driven work.
- `scripts/github-pr-context.sh`
  Fetches PR metadata and changed files via `gh`.
- `scripts/github-review-prep.sh`
  Combines capability status with PR context to prepare GitHub review work.
- `scripts/extract-spec.sh`
  Fetches a GitHub issue via `gh` and creates `.codex/specs/<issue>/spec.md`.
- `scripts/work.sh`
  Issue wrapper that extracts the spec, chooses role/model, and launches Codex for that issue.
- `scripts/preflight.sh`
  Checks branch, stack, project bootstrap, command registry, and worktree state before task work.
- `scripts/codex-fw.sh refresh-commands`
  Regenerates `.codex/project.env` for a target repo when you want to refresh the detected command surface manually.
- `scripts/post-change-check.sh`
  Runs project commands and suggested checks based on changed file types.
- `scripts/spec-status.sh`
  Reads `.codex/specs` and reports what is done, failing, pending, and next.
- `scripts/pr-ready.sh`
  Runs readiness checks before PR work.
- `scripts/pr-body.sh`
  Generates a Claude-style PR body with `## Summary` and `## Test Plan`, deriving verification dynamically from repo hooks first and detected commands second, with no attribution footer.
- `scripts/pr-create.sh`
  Opens a PR with `gh` using the generated PR body or a supplied body file.
- `scripts/safe-commit.sh`
  Enforces conventional commit format and blocks AI attribution.
- `scripts/browser-verify.sh`
  Prepares browser verification from the active spec and live local URL.
- `templates/task-brief.md`
  Task brief format for reusable delegation and issue-driven work.
- `templates/project/`
  Bootstrap files for adopting the framework in a working repository.
- `scripts/bootstrap-project.sh`
  Copies a starter `CODEX.md` into a target project.

## Framework Shape

The framework is intentionally split into layers:

1. Knowledge layer
   `skills/` and `agents/`
2. Orchestration layer
   `CODEX.md`, `CODEX.skills.md`, and `CODEX.capabilities.md`
3. Enforcement layer
   `scripts/`

Claude-specific concepts such as hook events, `enabledPlugins`, `teammateMode`, `statusLine`, and `claude plugin install` are not used here.

## Recommended Usage

1. Keep this repo as the source of truth for Codex framework assets.
2. Run `scripts/setup.sh` to install reusable skills into `~/.codex/skills/ai-codex-framework` and the shell wrapper into `~/.zshrc`.
3. The setup script also reports required, recommended, and optional local dependencies with install hints instead of silently assuming they exist.
4. Restart your shell or run `source ~/.zshrc` before expecting plain `codex` to use the framework wrapper.
5. In a working repo, start Codex through the framework with `codex` or `codex-fw session`.
6. Valid wrapper entrypoints are `codex`, `codex --task "your task"`, `codex -w <issue>`, and `codex --raw`.
7. `codex -row` and `codex --row` are invalid and will be passed to the raw Codex CLI, which rejects them.
8. For a task-first session, run `codex --task "your task"` or `codex-fw go "your task"`.
9. The generated `.codex/project.env` is auto-managed by default and refreshes when detected commands change. Set `PROJECT_COMMANDS_MODE="manual"` only if you want to pin custom overrides.
10. If you want to force a refresh manually, run `codex-fw refresh-commands` in the project root.
11. Use `scripts/codex-fw.sh post-change-check` after substantial changes.
12. Generate a PR body with `codex-fw pr-body` or open the PR directly with `codex-fw pr-create`.
13. Use the role briefs in `agents/` as delegation templates when spawning sub-agents.
14. For issue-driven work, use `codex-fw work <issue>` or `codex -w <issue>` after setup. Inside a git repo, this flow creates or reuses a sibling worktree first.

## Session Model

After `scripts/setup.sh` and a shell reload, plain `codex` becomes the framework-aware launcher in a project:

- `codex`
  bootstraps the project if needed, runs preflight and capability detection, writes a session context artifact, and opens Codex with that context
- `codex --task "fix login bug"`
  does the same, plus generates a task brief and opens Codex against that brief
- `codex -w 424`
  creates or opens a sibling worktree for issue `424`, extracts the issue spec there, and opens an issue-driven Codex session
- `codex --raw`
  bypasses the wrapper and opens plain Codex without framework startup

Invalid examples:

- `codex -row`
  invalid; use `codex -w <issue>` for issue-driven work
- `codex --row`
  invalid; there is no `--row` wrapper flag

This is the main replacement for the Claude-style “framework inside every session” behavior.

## Project Command Registry

`.codex/project.env` stores the detected command surface for the current repo:

- `PACKAGE_RUNNER` for script execution such as `bun run`, `pnpm`, `yarn`, or `npm run`
- `PACKAGE_EXEC` for direct local binaries such as `bunx`, `pnpm exec`, `yarn`, or `npx`
- `TEST_CMD`, `LINT_CMD`, `BUILD_CMD`, `DEV_CMD` for framework checks

By default this file is auto-managed and refreshed by bootstrap when detection changes. If a project needs pinned custom commands, set `PROJECT_COMMANDS_MODE="manual"` in that file.

## Session Display

Framework-driven sessions now use a visible display layer instead of hidden runtime hooks:

- startup banner with stack and capability state
- plan block with role icon, model, tier, and skills
- explicit `go` gate before executing planned task work
- short status blocks during work showing active owner, model, tier, and skills

This keeps orchestration readable inside Codex without depending on Codex-internal UI chrome.

## Current State

The framework now has:

- Codex-native orchestration in `CODEX.md`
- explicit skill injection in `CODEX.skills.md`
- explicit runtime capability handling in `CODEX.capabilities.md`
- normalized role briefs across `agents/`
- specialized role briefs for mobile, automation, and unified full-stack frameworks
- a normalized skill library in `skills/`
- machine-readable routing defaults in `routing.yaml`
- a project bootstrap flow with `.codex/project.env`
- an operational script layer for preflight, banners, plans, task briefs, verification, specs, PR readiness, and safe commits

Generated run artifacts such as task briefs are stored under project-local `.codex/` when writable, and fall back to `/tmp/ai-codex-framework/...` when the environment blocks writes there.

## Runtime Workflow

Typical real-task flow:

1. `codex` or `scripts/codex-fw.sh session`
2. optionally `codex --task "<task>"` or `scripts/codex-fw.sh go "<task>"`
3. work from the generated session context and task brief
4. `scripts/codex-fw.sh post-change-check`
5. `scripts/codex-fw.sh spec-status` or `scripts/codex-fw.sh browser-verify` when spec-driven
6. `scripts/codex-fw.sh pr-ready`
7. `scripts/codex-fw.sh pr-body` or `scripts/codex-fw.sh pr-create`
8. `scripts/codex-fw.sh safe-commit "type(scope): message"`

Issue workflow:

1. `codex-fw work 424`
2. or `codex -w 424` after running the global setup script
3. when inside a git repo, the issue flow uses a sibling worktree such as `../<repo>-424`
