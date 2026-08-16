# Personal Codex Working Agreement

Apply these defaults in every repository unless a closer project instruction overrides them.

## Working defaults

- Read local instructions before editing, preserve unrelated work, and verify changed behavior.
- Use native plans and goals for genuinely multi-step work; continue until done or genuinely blocked.
- Delegate only independent work, keep contracts and integration with the parent, and isolate parallel writers in worktrees.
- After ordinary verification of a high-risk change, use one independent read-only reviewer to try to falsify the result; accept only evidence-backed findings, rerun affected checks, and avoid recursive debate loops. Skip this for routine low-risk changes.
- Report only real agents, checks, files, risks, and blockers. Skills are workflows, not agents.
- When a repository has no closer branch convention, name new branches for human intent with `feat/`, `fix/`, `refactor/`, `docs/`, `test/`, `chore/`, `perf/`, `build/`, `ci/`, `revert/`, `release/`, or `hotfix/` plus a concise kebab-case outcome. Do not expose the implementation agent, model, vendor, or automation surface in a branch name; `codex/`, `agent/`, `gpt/`, `claude/`, and `ai/` are prohibited.
- Prefer native Codex capabilities over local orchestration, memory, browser, git, plugin, or MCP wrappers.
- Preserve closer repository-specific instructions and user intent.
- Clean up only task-owned processes and browser sessions; never use broad `pkill` or wildcard temporary-directory deletion.
- Update the authoritative API documentation or schema whenever an API contract changes.
- Verify official documentation before introducing version-sensitive framework or provider patterns.
- Before version-sensitive work, generate an ephemeral stack context with `${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context`: use `project <path>` to inspect manifests/lockfiles, or `latest <technologies>` to resolve stable frameworks and production LTS runtimes. Verify generated manifests and apply version-specific recipes only when the installed stack exposes the required capability. Preserve existing pins unless migration is explicitly in scope.
- Before non-trivial repository work, establish a compact project contract from the current checkout: repository shape, manifest/lockfile-owned stack, authoritative commands, environment map, and release or mutation boundaries. Reuse verified facts within the task and refresh drift-prone external state before acting.
- Before any environment-dependent command or external mutation, resolve the exact target environment, account or project, authority source, actor or credential class, mutation boundary, and verification path from repository and provider-visible evidence. A failed local readiness or status check proves only that the local path is unavailable; it does not authorize substitute infrastructure, a different environment, or a weaker verification path. If target authority remains ambiguous, stop before mutation or substitute creation and resolve it.

## Failure visibility and fallback policy

- Fail closed by default. Do not introduce or preserve an implicit behavioral fallback merely to keep a flow green. This includes placeholder, mock, sample, synthetic, fabricated, stale-cache, default-value, empty-success, substitute-service, provider or model downgrade, and swallowed-error paths.
- When the primary path fails, keep the outcome failed at the responsible boundary, preserve the original cause, and surface a typed or structured error with safe actionable diagnostics through the appropriate interface and observability path. Fix the root cause; never convert a failure into apparent success.
- A fallback or degraded mode is permitted only when explicitly required by the user or a project-specific contract before implementation. That contract must name the trigger, semantics, data provenance, user-visible degraded state, observability, and removal or recovery condition. Tests must cover the primary path, the explicitly authorized degraded path, and total failure. Without that evidence, fallback is prohibited.
- Treat an in-scope existing fallback as a defect unless the same explicit exception evidence exists. Remove it or make the failure visible instead of preserving compatibility with hidden degradation.

## Native task ergonomics and automation

- Use native Scheduled tasks/automations for requested recurring execution, monitoring, reminders, and later follow-up when available; never add polling daemons, retry loops, or lifecycle hooks for this purpose.
- Use native task names, pins, sections, handoff, and forks when long work benefits from navigation, a durable decision point, or an isolated alternative hypothesis. Create or fork a user-visible task only when the user requested that boundary; never create local status or handoff machinery.
- Prefer native GitHub integration or `codex review` for routine review. Keep the custom read-only reviewer for one bounded high-risk falsification pass.
- Offer Record & Replay only for a user-demonstrated repetitive interactive workflow. Recording, Computer Use, site/CDP access, plugin trust/install, Auto-review, and consequential connector permissions remain explicit native user gates.
- Automatically use matching installed and approved native capabilities. When installation, sign-in, trust, or permission is missing, explain the one-time gate and continue safe independent work.
- Treat native memories, imported agent history, and Computer History as optional recall sources, never as authority for required project rules or current external state. Keep durable requirements in repository instructions and revalidate environment/provider identity before mutation.

## Capability discovery and tool selection

- Before declaring a capability unavailable or asking for installation, connection, or sign-in, inventory the exact task-relevant capabilities already present: repository-native commands, PATH-available local CLIs, installed and callable plugins/connectors, and native tools. For a candidate CLI, use `command -v`, version or help output, and a safe non-mutating identity, authentication, or status check when supported. Never infer service unavailability from the plugin catalog alone.
- Automatically use an already installed and appropriately authenticated local CLI when it supports the exact required operation. Local CLIs and plugins are complementary; choose by exact task capability, API parity, automation or CI needs, current authorization, and environment authority. Do not replace or bypass a capable CLI merely because a plugin exists.
- An optional plugin marked available but not installed is not a blocker when an existing tool or CLI can complete the task. Request plugin installation only when the user explicitly requested that specific plugin, callable tools and relevant local CLIs have been exhausted, and the plugin supplies a required unique capability. Otherwise continue with the existing capability or report the exact unsupported operation without initiating an installation gate.
- Verify target account, project, environment, and mutation boundary before using either a CLI or plugin. If the CLI lacks the exact operation or valid authorization, surface that precise gap; do not assume parity, fabricate access, or silently switch tools.

## Interactive development

- For every task that changes or diagnoses a runnable web application, start or attach to its repository-native development server early, prove application/dependency readiness, and immediately open the affected localhost route in the visible native in-app Browser. Iterate with rendered DOM, console, network, runtime, interaction, responsive, and fresh-load evidence. Headless E2E is supplementary and never silently replaces visible Browser acceptance.
- Reuse the existing Browser binding. A stale, missing, or closed tab invalidates only that tab binding: inspect the current session, recover the exact task-owned tab when possible, or create a new task-owned tab in the same browser. Re-select only after an explicit browser disconnect; do not silently fall back to an invisible browser. Browser unavailability or required localhost/site approval remains an explicit unverified boundary.
- Track exact ownership for servers, terminal sessions, process IDs, ports, Browser tab objects/IDs, apps, simulators, and emulators. Close or stop only resources started or claimed by the task; keep pre-existing/user/other-agent resources untouched. Parallel UI writers use separate worktrees, ports, servers, and tabs/sessions.
- For every task that changes or diagnoses a runnable native mobile application, boot or attach to a visible repository-configured simulator, emulator, or device, launch the app early, interact during implementation, and reverify the affected device/lifecycle path. Repository/platform tools own launch and target selection; headless/unit/widget tests supplement rather than replace visible device evidence.
- Read-only explanation, planning, documentation-only work, and repositories without runnable UI are exempt. Never claim interactive acceptance when Browser, SDK, build, device, credentials, or permission boundaries prevented it.
