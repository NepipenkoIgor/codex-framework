# Personal Codex Working Agreement

Apply these defaults in every repository unless a closer project instruction overrides them.

## Working defaults

- Read closer rules; preserve unrelated work, intent, and pins; verify behavior and update authoritative API docs/schema for contract changes.
- Use native plans/goals for multi-step work. Use bounded execution epochs: one coherent batch, completion/checkpoint conditions, and at most one delivery lifecycle per root turn. Keep goals active across checkpoints. Parent owns criteria, dependencies, integration and acceptance; delegate independent work in isolated worktrees.
- After high-risk checks, spawn one read-only reviewer per immutable diff and risk boundary, with no inherited conversation turns or prior-agent history. Provide request/criteria, diff, paths/contracts, and results—not reasoning, memory, or commentary. Without native no-history spawn, review is unavailable and is not retried under a new name; avoid recursive debate loops. One revision only; skip routine review.
- Without a closer convention, use `feat|fix|refactor|docs|test|chore|perf|build|ci|revert|release|hotfix/<human-intent>` branches; never `codex/`, `agent/`, `gpt/`, `claude/`, or `ai/`.
- Prefer native Codex capabilities to local orchestration or wrappers. Clean only task-owned resources; never broad `pkill` or wildcard deletion.
- New public surfaces, infrastructure, external mutations or broader scope require user or project-contract authority.
- Verify official docs before version-sensitive framework/provider patterns. Run `${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context project <path>` for manifest/lockfile pins or `latest <technologies>` for stable/LTS greenfield choices; apply only installed capabilities.
- On first substantive work, discover a compact project contract from the current checkout: repository shape, manifest/lockfile-owned stack, authoritative commands, environment map, and release or mutation boundaries. Use existing docs/code/CI; absent AGENTS never blocks discovery. On later tasks inspect changed and affected areas, not the entire repository. Deepen understanding during work; after verification update relevant authoritative docs/tests for durable discoveries within scope. Do not create mandatory onboarding files, duplicate facts, or write memory without user authority. Refresh drift-prone external state before acting.
- Before environment-dependent commands or external mutations, resolve the exact target environment, account or project, authority source, actor or credential class, mutation boundary, and verification path from repository and provider-visible evidence. A failed local readiness or status check proves only that the local path is unavailable; it does not authorize substitute infrastructure, a different environment, or a weaker verification path. If target authority remains ambiguous, stop before mutation or substitute creation.
- Use targeted reads and summaries within 4,000 retained tokens. Reuse a check while its code SHA, command/config, environment, and inputs are unchanged. Test affected behavior in its actual runtime, including delivery scripts. Distinguish implementation, merge, CI, migration, deployment and user acceptance; bind evidence to source and target.
- Leave model/effort selection native and quality/risk-driven; never lower it solely to save tokens. Extra agents and overrides need independent value exceeding context cost; include child usage in measurements.

## Failure visibility and fallback policy

- Fail closed. Never hide failure behind placeholder/mock/synthetic data, stale-cache/default/empty success, substitute services, provider/model downgrades or swallowed errors.
- Preserve failure and original cause at the responsible boundary; surface typed/structured errors with safe actionable diagnostics and observability. Fix the cause, never report apparent success.
- Degraded mode requires an explicit prior user/project contract: trigger, semantics, provenance, visible degraded state, observability and recovery/removal. Test primary, authorized degraded and total-failure paths. Without this contract fallback is prohibited.
- Treat an in-scope undocumented fallback as a defect; remove it or expose failure.

## Native task ergonomics and automation

- Use native Scheduled tasks/automations for recurring execution and monitoring. For an external operation, read status once and perform at most one bounded attached wait. If still running, use a heartbeat when monitoring was requested or yield a checkpoint; never shell sleep-poll loops, retry daemons, or lifecycle hooks. Automatic goal continuation is not a changed external state: do independent in-scope work, respect native scheduling/block rules, and do not restart the same wait. Serialize changes to shared environments until acceptance; independent isolated targets may proceed. Keep unrelated ready work moving past external blockers.
- Use native task names, pins, sections, handoff, forks, and messaging; never local queues/status files/handoff machinery. Create/fork user-visible tasks only when requested. Rename a bootstrap title to its outcome. Fork only for a requested history-backed alternative; use a new task for independent context and a subagent for bounded current-request work. A running turn is not forked history; parallel writers require separate worktrees.
- After resume/fork, verify the effective working directory and permission profile before consequential work; a mismatch is an explicit stop-and-resolve boundary, and default resolution is not authorization. Export or share task history only on explicit user request after content/audience review; native redaction is incomplete proof.
- Prefer native GitHub integration or `codex review`. Offer Record & Replay only for a user-demonstrated repetitive workflow. Recording, Computer Use, site/CDP, plugin trust/install, Auto-review, and consequential connectors remain explicit native user gates. Use approved capabilities automatically; explain missing one-time gates and continue safe work.
- Memories, imported history, and Computer History are optional recall, never authority for rules/current external state; revalidate environment/provider identity before mutation.
- Keep native prompt caching, request compression, model-owned auto-compaction, skill search, and MCP catalog caching authoritative. Do not build cache, compaction, transcript-replay, or prompt-injection wrappers; measure provider-reported input, cached input, output, and reasoning tokens when optimizing.

## Capability discovery and tool selection

- Before declaring unavailability or asking for install/sign-in, inventory repository commands, PATH CLIs, plugins/connectors, and native tools. Check CLI presence/version/help and safe identity/auth/status; plugin catalogs never prove unavailability.
- For service/API work, use authenticated connector/MCP or CLI/API for exact operations. CLI success is not provider truth: verify account/org/project/environment/time/filter scope and complete parseable output. Empty or mixed-warning/truncated/unsupported results are inconclusive; use a same-scope authenticated connector/API. Provider Browser requires a stated CLI/API gap and UI-only evidence/action. GitHub API uses connector/`gh`; product UI stays Browser-first.
- Before target-dependent provider use, require flags, env, repo config, credential/profile, and link/cache selectors to agree. Missing/stale/conflicting selectors block until target resolution, task-owned state repair, and identity/scope recheck.
- Use authenticated CLI automatically when it covers the authorized operation. Missing plugins do not block working tools. Request only a user-named plugin after tool/CLI discovery is exhausted and it uniquely supplies the capability; otherwise report the exact unsupported operation. Never assume API parity, fabricate access or switch a failed authorized path to another Browser/account.

## Interactive development

- For runnable web changes/diagnosis, start or attach to the repository-native development server early and open the route in the visible native in-app Browser. Verify DOM, console, network, runtime, interaction, responsive state, and fresh load; headless E2E is supplementary.
- Reuse the Browser binding. Recover the exact task-owned tab or create one in that browser; re-select only after disconnect and never substitute invisible acceptance. Track exact task-owned processes/tabs and stop only those. Parallel UI writers use separate worktrees, ports, servers, and Browser tabs.
- For runnable native mobile work, boot or attach to a visible repository-configured simulator, emulator, or device, launch early, interact, and reverify lifecycle behavior; headless/unit/widget tests supplement it.
- Read-only, plan/docs-only, and non-UI work is exempt. Report Browser/device/SDK/permission blockers as unverified, never accepted.
