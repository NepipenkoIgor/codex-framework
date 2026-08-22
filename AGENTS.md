# AI Codex Framework

This repository is a thin native Codex extension layer. Codex owns planning, models, approvals, sandboxing, plugins, MCP, Browser, worktrees, git integrations, agent communication, and subagent lifecycle; do not recreate them with wrappers, prompt gates, retries, or memory injection.

Generic cross-repository behavior—planning, project/environment authority, fail-closed errors, capability discovery, task automation, and interactive development—is owned once by the global working agreement installed by this framework. This file adds only closer framework-repository rules and must not restate or weaken those defaults.

## Execution

1. For multi-step implementation with a clear outcome, start a native goal immediately and continue until done, genuinely blocked, or explicitly paused; do not create goals for questions, reviews, explanations, or plan-only requests.
2. Before version-sensitive work, generate ephemeral stack context with `scripts/framework-stack-context.py`; preserve existing pins unless migration is explicitly in scope.
3. Verify the actual diff and changed behavior, then report residual risk without overstating release state.

## Visible orchestration

- For deep audits, cross-system incidents, or independent read-heavy investigation, delegate only separable evidence gathering or review. The parent owns contracts, decisions, integration, and shared writes.
- Announce a subagent only after spawning it, as `profile — model / effort — bounded responsibility`, then report its real conclusion or failure. Skills are workflows, not agents.
- Never manufacture plan files, status dashboards, agent updates, lifecycle hooks, or proxy handoffs; native plans and agent lifecycle are authoritative.

## Agent profiles and review

- Use the built-in `explorer` for read-only reconnaissance and `worker` for scoped implementation. Use `architect` for read-only contracts/migrations, `reviewer` for read-only correctness/security/regression review, and `tester` for targeted executable checks.
- Keep writers in separate worktrees. Do not delegate recursively. Resolve shared contracts before parallel implementation.
- After ordinary verification, run exactly one independent read-only falsification pass for security, migrations, schemas/APIs, concurrency/data integrity, permissions/deployment, cross-system change, or residual material ambiguity. Spawn the reviewer with no inherited conversation turns or prior-agent history, using the native fresh-context or no-history control. Give it only a neutral evidence bundle containing the original request and acceptance criteria, actual diff, affected paths, applicable repository contracts, and executed checks with results; exclude the implementer's plan, reasoning, conclusions, memories, and earlier review commentary. If the active surface cannot prove the no-history boundary, report independent review as unavailable rather than silently using inherited context. Require severity plus concrete file/reproduction/check evidence; the parent adjudicates and performs at most one revision cycle unless the user requests a deeper audit.

## Skills and integrations

Use the smallest matching skill set. Prefer installed native plugins and MCP servers over project wrappers. Start connectors read-only and enable writes only when required. Use the in-app Browser for observable UI verification; retain screenshots only when DOM, console, and network evidence are insufficient. Do not add filesystem, git, or browser MCP servers that duplicate native tools.

## Native capability currency

- Every framework review, audit, improvement, consolidation, or release begins by reading the current official Codex manual, complete changelog delta since the ledger baseline, and latest stable release notes, then comparing them with `docs/native-capability-ledger.json`.
- For each relevant delta, record one evidence-backed decision: adopt, replace a local implementation, remove an obsolete override, retain with a concrete native gap, or keep permission-gated. Search wrappers, hooks, profiles, prompts, scripts, plugins, and MCP servers before deciding.
- Apply the safe cleanup in the same framework task. Update ledger time/version/source/decision/evidence fields and run `python3 scripts/framework-native-capability-check.py --live`; release fails on stale or unverifiable currency.
- This mechanism is framework-only and must not enter ordinary application startup context.
- Daybreak use requires explicit identity, workspace/organization, project, model, product surface, and engagement scope. Daybreak Blue never implies Daybreak Red authorization.

## Repository boundaries

- Hooks may enforce narrow deterministic safety policy. They must not scan unrelated worktree state, inject context, route prompts, select models, generate plans, manage agents, persist memory, or retry.
- Update authoritative API documentation/schema with contract changes. Follow repository release workflow and use GitHub integration or `codex review` where supported.
- Desktop and CLI share `AGENTS.md`, `.codex/config.toml`, skills, profiles, and hooks. Never branch behavior by surface.
- Keep durable facts in tracked documentation and conversation continuity in native task memory. Avoid startup payloads, generated briefs, repeated role/policy prompts, full skill-map injection, and screenshot-heavy evidence.
