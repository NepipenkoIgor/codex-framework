# Personal Codex Working Agreement

Apply these defaults in every repository unless a closer project instruction overrides them.

## Working defaults

- Read closer instructions first; preserve unrelated work, user intent, and existing pins; verify changed behavior and update authoritative API docs/schema with contract changes.
- Use native plans/goals for multi-step work. Delegate only independent work, keep contracts/integration with the parent, and isolate parallel writers in worktrees. Report only real agents, checks, files, risks, and blockers; skills are not agents.
- After high-risk checks, spawn one read-only reviewer with no inherited conversation turns or prior-agent history. Provide request/criteria, diff, paths/contracts, and results—not reasoning, memory, or commentary. Without native no-history spawn, review is unavailable. One revision only; avoid recursive debate loops. Skip routine review.
- Without a closer convention, branch as `feat|fix|refactor|docs|test|chore|perf|build|ci|revert|release|hotfix/<human-intent>`. Never use `codex/`, `agent/`, `gpt/`, `claude/`, or `ai/`.
- Prefer native Codex capabilities over local orchestration, memory, Browser, git, plugin, or MCP wrappers. Clean up only task-owned resources; never broad `pkill` or wildcard temporary deletion.
- New public routes/surfaces, infrastructure, external mutations, or materially broader deliverables require explicit user or project-contract authority; otherwise propose them without implementing.
- Verify official docs before version-sensitive framework/provider patterns. Run `${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context project <path>` for manifest/lockfile pins or `latest <technologies>` for stable/LTS greenfield choices; apply only installed capabilities.
- Before non-trivial repository work, establish a compact project contract from the current checkout: repository shape, manifest/lockfile-owned stack, authoritative commands, environment map, and release or mutation boundaries. Reuse verified facts within the task and refresh drift-prone external state before acting.
- Before any environment-dependent command or external mutation, resolve the exact target environment, account or project, authority source, actor or credential class, mutation boundary, and verification path from repository and provider-visible evidence. A failed local readiness or status check proves only that the local path is unavailable; it does not authorize substitute infrastructure, a different environment, or a weaker verification path. If target authority remains ambiguous, stop before mutation or substitute creation and resolve it.
- Minimize model input without hiding evidence: use targeted `rg`, line ranges, summaries, and bounded fields; do not dump whole manuals, logs, catalogs, JSON, or broad search output. Keep tool results within the 4,000-token retention limit and expand only after a narrower query fails. Reuse evidence instead of repeating reads/checks.
- Leave ordinary model and reasoning-effort selection native and quality/risk-driven. Never lower them solely to save tokens; reserve explicit high/max/ultra overrides and extra agents for work whose complexity or risk justifies them, and delegate only when independent value exceeds added context cost.

## Failure visibility and fallback policy

- Fail closed by default. Do not introduce or preserve an implicit behavioral fallback merely to keep a flow green. This includes placeholder, mock, sample, synthetic, fabricated, stale-cache, default-value, empty-success, substitute-service, provider or model downgrade, and swallowed-error paths.
- When the primary path fails, keep the outcome failed at the responsible boundary, preserve the original cause, and surface a typed or structured error with safe actionable diagnostics through the appropriate interface and observability path. Fix the root cause; never convert a failure into apparent success.
- A fallback or degraded mode is permitted only when explicitly required by the user or a project-specific contract before implementation. That contract must name the trigger, semantics, data provenance, user-visible degraded state, observability, and removal or recovery condition. Tests must cover the primary path, the explicitly authorized degraded path, and total failure. Without that evidence, fallback is prohibited.
- Treat an in-scope existing fallback as a defect unless the same explicit exception evidence exists. Remove it or make the failure visible instead of preserving compatibility with hidden degradation.

## Native task ergonomics and automation

- Use native Scheduled tasks/automations for recurring execution, monitoring, reminders, and follow-up; never repository polling/retry daemons or lifecycle hooks.
- Use native task names, pins, sections, handoff, and forks. Choose a fork only when the new task needs the source task's completed history; choose a new task when it should start without that history, and a subagent when it remains a bounded part of the current request. Create/fork user-visible tasks only when requested. A running turn is not forked history, and parallel writers require separate worktrees. Use native task messaging and task management instead of local queues, status files, or handoff machinery.
- After resume/fork, verify the effective working directory and permission profile before consequential work; a mismatch is an explicit stop-and-resolve boundary, and default resolution is not authorization. Export or share task history only on explicit user request after content/audience review; native redaction is incomplete proof.
- Prefer native GitHub integration or `codex review`. Offer Record & Replay only for a user-demonstrated repetitive workflow. Recording, Computer Use, site/CDP, plugin trust/install, Auto-review, and consequential connectors remain explicit native user gates. Use approved capabilities automatically; explain missing one-time gates and continue safe work.
- Memories, imported history, and Computer History are optional recall, never authority for rules/current external state; revalidate environment/provider identity before mutation.
- Keep native prompt caching, request compression, model-owned auto-compaction, skill search, and MCP catalog caching authoritative. Do not build cache, compaction, transcript-replay, or prompt-injection wrappers; measure provider-reported input, cached input, output, and reasoning tokens when optimizing.

## Capability discovery and tool selection

- Before declaring a capability unavailable or asking for installation/sign-in, inventory repository commands, PATH CLIs, callable plugins/connectors, and native tools. Check a CLI with `command -v`, version/help, and safe identity/auth/status where supported; the plugin catalog alone never proves service availability.
- For service/API work, use an authenticated connector/MCP or CLI/API covering the exact operation. Browser is last resort except for irreducibly visual/UI-only evidence. GitHub issues, comments, projects, PRs, Actions, logs, and attachments use the GitHub connector or `gh`; GitHub Browser is only for visual/UI-only work. Product localhost/deployed UI acceptance remains visible Browser-first.
- Use a capable authenticated CLI automatically. Choose among CLI/plugin by exact coverage, API parity, automation needs, authorization, and environment; never bypass a capable CLI merely because a plugin exists or silently switch from a failed authorized path to Browser/account.
- A missing optional plugin is not a blocker when a tool/CLI can do the work. Request installation only when the user named that plugin, existing callable tools/CLIs are exhausted, and it uniquely supplies a required capability; otherwise continue or report the exact unsupported operation.
- Verify target account, project, environment, and mutation boundary before CLI/plugin use. Surface missing coverage/authorization; never assume parity or fabricate access.

## Interactive development

- For runnable web changes/diagnosis, start or attach to the repository-native development server early and open the route in the visible native in-app Browser. Verify DOM, console, network, runtime, interaction, responsive state, and fresh load; headless E2E is supplementary.
- Reuse the Browser binding. Recover the exact task-owned tab or create one in that browser; re-select only after disconnect and never substitute invisible acceptance. Track exact task-owned processes/tabs and stop only those. Parallel UI writers use separate worktrees, ports, servers, and Browser tabs.
- For runnable native mobile work, boot or attach to a visible repository-configured simulator, emulator, or device, launch early, interact, and reverify lifecycle behavior; headless/unit/widget tests supplement it.
- Read-only, plan/docs-only, and non-UI work is exempt. Report Browser/device/SDK/permission blockers as unverified, never accepted.
