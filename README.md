# AI Codex Framework

A thin, native Codex extension layer for reusable engineering skills, project instructions, focused subagent profiles, native rules, and deterministic safety hooks.

## Native ownership

Codex owns planning, models, skill selection, approvals, sandboxing, worktrees, plugins, MCP, browser control, native agent messaging, and agent orchestration. This repository does not ship shell routers, prompt gates, context injection, model fallback chains, issue/PR wrappers, synthetic agent workflows, or local conversation-memory engines.

## Install

```bash
bash scripts/setup.sh
```

Start a new Codex session after installation. Codex discovers the installed skills and agents directly. A portable hooks plugin lives under `plugins/ai-codex-framework`; the default setup continues to install only the curated skill set.

To add the framework to a project without overwriting its existing instructions:

```bash
bash scripts/bootstrap-project.sh /path/to/project
```

This creates `AGENTS.md`, project-scoped profiles in `.codex/agents/`, native safety rules, and the thin hook config.

`setup.sh` also installs the framework's global working agreement at `~/.codex/AGENTS.md` when that file is empty or already managed by this framework. It applies visible planning and truthful agent/model status across repositories; an existing non-empty personal global file is preserved. Restart or start a new Codex task after installation.

## Native agent profiles

| Profile | Mode | Use |
|---|---|---|
| `explorer` | built in, read-only | evidence gathering and codebase mapping |
| `worker` | built in | narrow implementation ownership |
| `architect` | custom, high reasoning, read-only | shared contracts, migrations, and tradeoffs |
| `reviewer` | custom, high reasoning, read-only | correctness, security, and regression review |
| `tester` | custom, high reasoning | executable verification |

Keep parallel work read-heavy by default. Give each parallel writer a separate worktree and an explicit ownership boundary. The parent owns contracts and integration. Custom profiles inherit the current native model catalog, avoiding stale model pins after Codex releases.

## Observable native workflow

For a task with multiple files, a shared contract, or non-trivial risk, Codex must create a native plan before substantive tool work and keep it visible through short progress updates. Those updates state the outcome, next steps, and which real sub-agents are active.

For deep audits, cross-system incidents, and independent read-heavy investigations, the parent delegates only separable work that improves the time to a sound decision. It announces an agent only after native delegation has actually started as `profile — model / effort — bounded responsibility`, and reports the result when it returns. It identifies a material skill as a skill, not as an agent: skills have no model. Profiles are available capabilities, not automatically running agents. This restores accountability without reintroducing shell-created plans, fake status feeds, or lifecycle hooks.

High-risk changes get one native falsification-review pass after implementation and normal checks. A read-only `reviewer` tries to disprove the result using the request, diff, affected paths, and verification evidence. The parent accepts only substantiated findings, makes any warranted revision, and reruns affected checks. Routine low-risk work skips the pass, and the contract forbids recursive debate loops, keeping the quality gain bounded in latency and token cost.

## Skills and integrations

Skills are a maintained local library, not a blanket prompt payload. `scripts/setup.sh` installs the unchanged curated core from `skills/core.txt`; domain packs remain in the source library and should be added project-scoped only when needed. Prefer native Browser, GitHub, Figma, and product integrations over wrappers. Use Browser DOM, console, and network evidence before screenshots. Add MCP servers only for external context that Codex does not already provide.

## Native runtime features

Use Codex memories for cross-thread recall and multi-agent V2 for current subagent routing. Keep Auto-review enabled at the user layer. Fast mode remains an explicit per-task choice because it trades additional credits for latency.

Project safety uses native `.codex/rules/` for destructive command prefixes and a small hook for compound shell patterns that rules cannot express. Hook paths resolve from the repository or plugin root, so the configuration is portable.

## Desktop / CLI parity

Both surfaces consume the same project instructions, config, profiles, skills, and deterministic hooks. The framework contains no surface-specific branch and injects no SessionStart context, which keeps startup tokens stable. Run `bash scripts/surface-parity-check.sh` after changing the runtime surface.

## Framework checks

```bash
bash scripts/framework-eval.sh
bash scripts/framework-drift-check.sh
bash scripts/surface-parity-check.sh
bash scripts/framework-health.sh
# Optional model-backed routing regression check:
bash scripts/framework-live-eval.sh
```

The deterministic checks validate native configuration, profile boundaries, plugin packaging, surface parity, wrapper removal, hook safety, and the skill corpus. The optional live eval samples actual model routing decisions and consumes Codex usage.
