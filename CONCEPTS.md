# CONCEPTS.md — AI Codex Framework Constitution

## Core Invariants

- `CODEX.md` is the main orchestration document for this framework.
- `CODEX.concepts.md` is the hard-invariant constitution for orchestration behavior.
- `CODEX.skills.md` is the explicit skill injection map for Codex task briefs.
- `CODEX.capabilities.md` is the runtime capability model for Codex environments.
- `ORCHESTRATOR_REFERENCE.md` defines execution patterns, retry chains, and coordination semantics.
- `SKILLS_MAP.*.md` are the lazy-loaded domain routing maps for skill resolution.
- `agents/` contains role briefs, not runtime-registered agent configs.
- `skills/` contains reusable prompt modules and operating guidance.
- `scripts/` remains the source of truth for enforcement; Codex hooks are thin adapters over those scripts.
- `.codex/hooks.json`, `.codex/config.toml`, and `.codex/handoffs/` provide Codex-native lifecycle wiring and coordination state when projects adopt the framework.
- This framework repo is the source of truth for reusable Codex framework assets.

## Architectural Decisions

- The framework keeps the portable knowledge layer from `ai-skills` and rewrites orchestration to be Codex-native.
- Project adoption is bootstrap-based and hook-enhanced.
- Verification is script-driven and hook-triggered for Desktop lifecycle events.
- Commit-time enforcement is repo-local and Git-owned; Codex runtime hooks own Codex lifecycle events.
- Generated task briefs replace hidden skill injection and carry stack, spec, and verification context.
- Capability detection replaces Claude plugin assumptions with explicit runtime paths.

## Known Footguns

- Some copied skills still contain Claude-era tool names or MCP phrasing and should be normalized over time.
- Project-local `CODEX.md` files can drift from the framework repo if they are copied and then edited independently.
- Browser verification steps depend on whatever browser tooling is actually available in the execution environment.
- Route decisions are heuristic shell logic today; if they drift from `routing.yaml`, update both together.
- Capability availability is environment-specific; task briefs should surface it instead of assuming tool presence.

## Recent State Changes

### 2026-04-17

- Created the Codex-first framework scaffold with `CODEX.md`, normalized role briefs, and setup scripts.
- Added project bootstrap templates and a bootstrap helper script.
- Began normalizing high-traffic skills away from Claude-specific paths and commands.

### 2026-04-20

- Added `CODEX.skills.md` as the Codex-native skill injection map.
- Restored specialized builder roles for mobile, full-stack, and automation work.
- Added stack-specific and platform-specific skills missing from the first port.
- Added `scripts/task-brief.sh` and updated `codex-fw run/work` to launch from generated briefs instead of one-line prompts.
- Added a capability layer plus GitHub helper scripts so Codex can prefer structured tools, fall back to `gh`, and then to local git when needed.
- Added a visible session display layer with banner, plan, and status blocks so orchestration is explicit inside Codex sessions.

### 2026-05-25

- Added a hook-native control plane with `scripts/hooks.sh`, `scripts/context-pack.sh`, and event adapters for `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, and `Stop`.
- Removed manual Desktop bootstrap/finish from the public workflow; `SessionStart` and `Stop` are the required Desktop lifecycle path.
- Kept hook behavior script-backed so lifecycle automation improves reliability without becoming hidden orchestration logic.
