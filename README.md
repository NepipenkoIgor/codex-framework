# AI Codex Framework

A thin, native Codex extension layer for reusable engineering skills, project instructions, custom subagent profiles, deterministic safety hooks, and durable local memory.

## Native ownership

Codex owns planning, models, skill selection, approvals, sandboxing, worktrees, plugins, MCP, browser control, and agent orchestration. This repository does not ship shell routers, prompt gates, model fallback chains, issue/PR wrappers, or synthetic agent workflows.

## Install

```bash
bash scripts/setup.sh
```

Start a new Codex session after installation. Codex discovers the installed skills and native agents directly.

To add the framework to a project without overwriting its existing instructions:

```bash
bash scripts/bootstrap-project.sh /path/to/project
```

This creates `AGENTS.md`, project-scoped profiles in `.codex/agents/`, and the thin hook config.

## Native agent profiles

| Profile | Mode | Use |
|---|---|---|
| `explorer` | read-only, medium | evidence gathering and codebase mapping |
| `architect` | read-only, high | shared contracts, migrations, and tradeoffs |
| `builder` | workspace write, medium | narrow implementation ownership |
| `reviewer` | read-only, high | correctness, security, and regression review |
| `tester` | workspace write, high | executable verification |

Keep parallel work read-heavy by default. Give each parallel writer a separate worktree and an explicit ownership boundary. The parent agent owns contracts and integration.

## Skills and integrations

Skills are a maintained local library, not a blanket prompt payload. `scripts/setup.sh` installs a curated 40-skill core from `skills/core.txt`; domain packs remain in the source library and should be added project-scoped only when needed. Prefer native Browser, GitHub, Figma, and product integrations over wrappers. Add MCP servers only for external context that Codex does not already provide.

## Framework checks

```bash
bash scripts/framework-eval.sh
bash scripts/framework-drift-check.sh
bash scripts/framework-health.sh
```

The checks validate real native configuration, wrapper removal, hook safety behavior, and the skill corpus.
