# AI Codex Framework

This thin native extension leaves planning, models, approvals, sandboxing, plugins, MCP, Browser, worktrees, git, agent communication, and lifecycle to Codex; do not wrap them with prompt gates, retries, or memory injection.

Generic cross-repository behavior is owned once by the global working agreement. This file adds only closer framework rules; do not restate or weaken those defaults.

## Execution

1. For multi-step implementation, start a native goal immediately and continue until done, genuinely blocked, or explicitly paused. Do not create goals for questions, reviews, explanations, or plan-only requests.
2. Before version-sensitive work, generate ephemeral stack context with `scripts/framework-stack-context.py`; preserve existing pins unless migration is explicitly in scope.
3. Verify the actual diff and changed behavior, then report residual risk without overstating release state.

## Visible orchestration

- For deep audits, cross-system incidents, or independent read-heavy investigation, delegate only separable evidence gathering or review. The parent owns contracts, decisions, integration, and shared writes.
- Announce a subagent only after spawning it, as `profile — model / effort — bounded responsibility`, then report its real conclusion or failure. Skills are workflows, not agents.
- Never manufacture plan files, status dashboards, agent updates, lifecycle hooks, or proxy handoffs; native plans and agent lifecycle are authoritative.

## Agent profiles and review

- Use the built-in `explorer` for read-only reconnaissance and `worker` for scoped implementation. Use `architect` for read-only contracts/migrations, `reviewer` for read-only correctness/security/regression review, and `tester` for targeted executable checks.
- Keep writers in separate worktrees. Do not delegate recursively. Resolve shared contracts before parallel implementation.
- After ordinary verification, run exactly one independent read-only falsification pass per immutable diff and risk boundary for security, migrations, schemas/APIs, concurrency/data integrity, permissions/deployment, cross-system change, or residual material ambiguity. Spawn the reviewer with no inherited conversation turns or prior-agent history, using the native fresh-context or no-history control. Give it only a neutral evidence bundle containing the original request and acceptance criteria, actual diff, affected paths, applicable repository contracts, and executed checks with results; exclude the implementer's plan, reasoning, conclusions, memories, and earlier review commentary. If the active surface cannot prove the no-history boundary or the bundle is contract-invalid, report independent review as unavailable and do not retry it under a new name. Require severity plus concrete file/reproduction/check evidence; the parent adjudicates and performs at most one revision cycle unless the user requests a deeper audit.

## Skills and integrations

Use the smallest matching skills and prefer native plugins/MCP over wrappers. Start connectors read-only. Use the in-app Browser for UI evidence and screenshots only when DOM/console/network are insufficient. Do not duplicate filesystem, git, or Browser tools with MCP.

## Native capability currency

- Every framework review, audit, improvement, consolidation, or release reads the current official Codex manual, complete changelog delta since the ledger baseline, and latest stable release notes, then compares `docs/native-capability-ledger.json`.
- For each delta, search local surfaces and record adopt, replace, remove, retain-with-gap, or permission-gated. When implementation is authorized, apply the safe cleanup in the same framework task, update ledger evidence, and run `python3 scripts/framework-native-capability-check.py --live`; stale currency blocks release. For an explicitly read-only, audit-only, or plan-only request, do not mutate: report the exact cleanup and keep release status unverified until a later authorized implementation updates the ledger.
- This is framework-only, never ordinary application startup context.
- Daybreak use requires explicit identity, workspace/organization, project, model, product surface, and engagement scope. Daybreak Blue never implies Daybreak Red authorization.

## Repository boundaries

- Hooks enforce only narrow deterministic safety: no unrelated scans, context injection, prompt/model/plan/agent routing, memory, or retries.
- Update API docs/schema with contracts and follow the release workflow. Desktop and CLI share `AGENTS.md`, `.codex/config.toml`, skills, profiles, and hooks; never branch by surface.
- Track durable facts in docs and continuity in native memory. Avoid startup payloads, generated briefs, repeated policy, full skill maps, and screenshot-heavy evidence.
