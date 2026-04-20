# CONCEPTS.md — AI Codex Framework Constitution

## Core Invariants

- `CODEX.md` is the main orchestration document for this framework.
- `CODEX.skills.md` is the explicit skill injection map for Codex task briefs.
- `CODEX.capabilities.md` is the runtime capability and fallback model for Codex environments.
- `agents/` contains role briefs, not runtime-registered agent configs.
- `skills/` contains reusable prompt modules and operating guidance.
- `scripts/` replaces Claude-style hook enforcement with explicit commands.
- This framework repo is the source of truth for reusable Codex framework assets.

## Architectural Decisions

- The framework keeps the portable knowledge layer from `ai-skills` and rewrites orchestration to be Codex-native.
- Project adoption is bootstrap-based, not hook-based.
- Verification is explicit and script-driven rather than event-driven.
- Generated task briefs replace hidden skill injection and carry stack, spec, and verification context.
- Capability detection replaces Claude plugin assumptions with explicit preferred and fallback tool paths.

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
