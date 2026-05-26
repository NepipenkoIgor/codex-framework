# AI Codex Framework

Global operating rules for Codex-based work.

## Objective

This framework ports the useful operating concepts from the Claude framework into Codex-native mechanisms:

- deterministic routing
- explicit skill injection
- spec-aware execution
- script-driven verification
- hook-enhanced lifecycle automation
- concise outcome reporting

The framework uses hook-enhanced, script-backed orchestration. Codex runtime hooks may start context loading, route prompts, guard risky tools, track changes, and record stop-state, but the source of truth remains visible in `CODEX.md`, `CODEX.concepts.md`, `CODEX.versions.md`, `CODEX.permissions.md`, `ORCHESTRATOR_REFERENCE.md`, `SKILLS_MAP.*.md`, role briefs, and helper scripts.

## Core Principles

- Read the codebase before changing it.
- Prefer existing patterns over novelty.
- Prefer current stable platform targets from [CODEX.versions.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.versions.md), and call out version drift before deepening old-version patterns.
- Keep implementation narrow and explicit.
- Separate implementation, review, and testing concerns.
- Verify changed behavior before closing a task.
- Keep lifecycle automation visible: hooks call scripts, and hook wiring is required for Desktop lifecycle behavior.

## Default Flow

Every non-trivial task follows these phases:

1. Classify the task
2. Detect stack and relevant project commands
3. Detect cached repo features and relevant domains
4. Route to the correct role
5. Inject the smallest useful skill set lazily through domain maps
6. Generate a structured task brief
7. Execute
8. Verify
9. Report outcome and residual risk

Use `scripts/task-brief.sh` or `codex-fw brief` to produce the explicit brief for execution.

## Memory Bootstrap

CLI-started framework sessions load memory through `session-start.sh`, `task-brief.sh`, or `work.sh`.
Desktop app sessions receive memory through the `SessionStart` hook.

For any Desktop app task in a repo using this framework:

1. require the auto-loaded `SessionStart` hook context
2. treat the returned block as startup context
3. use `project.md`, `preferences.md`, `decisions.local.md`, and relevant `episodes.jsonl` entries as hints, not as proof
4. verify important facts against the repository before making changes
5. after a non-trivial task, let the `Stop` hook record a compact episode unless `CODEX_MEMORY_AUTO_RECORD=0`
6. include memory status in the closeout as `loaded`, `recorded`, or `skipped with reason`

Do not inject the full `.codex-memory` directory into the prompt; use the compact context command.
CLI task and issue sessions auto-record episodes by default. Set `CODEX_MEMORY_AUTO_RECORD=0` to disable this.
Use `codex-fw hooks doctor`, `codex-fw memory doctor`, or `scripts/memory-contract-check.sh` when lifecycle or memory behavior looks suspicious.

## Hook Runtime

Project bootstrap writes Codex runtime hooks into `.codex/config.toml` as inline TOML blocks and keeps `.codex/hooks.json` as a generated adapter artifact for inspection and compatibility.

Hook responsibilities:

- `SessionStart`: emit the shared context pack with repo intelligence, capabilities, and memory
- `UserPromptSubmit`: emit compact routing guidance for owner, tier, model, and skills
- `PreToolUse`: warn or block policy-bypassing shell patterns such as `git commit --no-verify`, destructive git resets, and dangerous shell pipelines
- `PostToolUse`: track changed files for later verification
- `Stop`: run required guard/quality checks and record a memory episode when changes exist

Use `codex-fw hooks doctor` to inspect local hook wiring and `codex-fw hooks smoke` to test the scripts directly.
Hook guards block by default. Set `CODEX_HOOK_ENFORCE=warn` only for temporary diagnostics.

## Routing

Use this routing order. Earlier matches win.

| Signal | Role |
|---|---|
| framework health/status, new skill, role updates, routing rules, orchestration audits | `framework-manager` |
| dependency audit, CVE, plugin security | `auditor` |
| backlog, triage, sprint, ticket shaping | `project-manager` |
| review, audit, check quality, PR review | `reviewer` |
| test, coverage, regression suite, E2E | `tester` |
| refactor, simplify, migrate, clean up | `refactorer` |
| bug, crash, wrong behavior, performance issue | `fixer` |
| design, architecture, API contract, schema, new dependency | `architect` |
| mobile, React Native, Expo, Flutter | `builder-mobile` |
| Next.js full-stack, Blazor, page plus API route in one framework | `builder-fullstack` |
| n8n, webhook-chain automation, workflow-node logic | `builder-n8n` |
| AI feature, LLM, RAG, prompt system, agents, multimodal | `builder-ai` |
| mixed automation work across workflows and AI systems | `builder-automation` |
| infra, deployment, CI/CD, Docker, Kubernetes | `builder-infra` |
| UI, page, component, styling, accessibility, frontend state | `builder-frontend` |
| API, backend, service, job, auth, persistence, integration | `builder-backend` |
| full-stack feature without architecture-first design | `builder` |

## Role Selection Rules

- Use `architect` first when the task introduces a new API, schema, dependency, or cross-system contract.
- Use `builder-fullstack` only when frontend and backend live inside the same framework boundary such as Next.js or Blazor.
- Use `builder-mobile` for mobile-native platform concerns, not generic frontend work.
- Use `builder-ai` for AI, agents, prompts, RAG, or multimodal product logic.
- Use `builder-n8n` for n8n workflow topology, retries, payload shaping, and webhook chains.
- Use `builder-automation` for mixed automation work that spans both workflow orchestration and AI-product behavior.
- Use `reviewer` as read-only. Reviewers do not modify code.
- Use `tester` after substantial implementation or fixes, or when the task is primarily test work.
- Domain roles are senior-engineer baselines. A mobile or backend task should assume framework/runtime choice, security, delivery, documentation, and performance concerns unless the task is explicitly narrow.

## Reasoning Tiers

- `low`: mechanical, well-bounded, usually single-file work, PR/commit mechanics
- `medium`: normal implementation, debugging, review, and testing
- `high`: architecture, migrations, cross-system work, hard debugging
- `xhigh`: rescue attempts, framework redesign/status audits, or unusually ambiguous high-risk changes

Use low reasoning only when the task is clearly mechanical. Otherwise prefer medium.
In this framework, `medium` intentionally uses the stronger default model so normal work stays on `gpt-5.5`; only clearly mechanical work drops to the low-tier model. Override models with `CODEX_LOW_MODEL`, `CODEX_MEDIUM_MODEL`, `CODEX_HIGH_MODEL`, and `CODEX_XHIGH_MODEL`.

## Skill Injection

Skill injection is explicit and governed by [CODEX.skills.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.skills.md).
The execution model and invariants are governed by [CODEX.concepts.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.concepts.md) and [ORCHESTRATOR_REFERENCE.md](/Users/igornepipenko/work/ai-codex-framework/ORCHESTRATOR_REFERENCE.md).
Modern framework target versions are governed by [CODEX.versions.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.versions.md).

Rules:

- Start from the routed role baseline.
- Add stack-specific skills only when the repo or task justifies them.
- Add feature skills only for clearly relevant systems.
- Keep the list short and concrete.
- Prefer project facts over generic skill guidance when they conflict.
- For fast-moving stacks, compare the detected project version to `CODEX.versions.md`; if it is below target, mention upgrade pressure and avoid introducing new deprecated patterns.

## Spec-Driven Work

When an issue or spec is the source of requirements:

1. ensure `.codex/specs/<issue>/spec.md` exists
2. treat the issue body plus discussion comments as the current requirement source
3. route from the issue title and summary
4. include the spec path and counts in the task brief
5. keep spec status current as work progresses
6. use browser verification for visual rows when the environment supports it

Issue work is delta-first. Before editing, compare every active requirement and comment clarification against the current project state. Mark requirements that are already satisfied, identify only the missing or incorrect behavior, and implement that gap. Do not rebuild, duplicate, or refactor working project behavior just because it appears in the ticket. If ticket discussion conflicts, follow the newest explicit maintainer/user clarification, and ask only when the conflict cannot be resolved from the thread.

Use:

- `codex-fw work <issue>`
- `codex-fw spec-status`
- `codex-fw browser-verify`

## Execution Rules

- Prefer doing the immediate blocking task locally.
- Use sub-agents only for bounded, parallelizable work.
- Do not delegate the next blocking step just to wait on it.
- When delegating, give ownership of files or responsibility.
- Do not ask multiple agents to edit the same files at the same time.
- Treat `agents/*.md` as role briefs and `agents/registry.tsv` as the named-agent runtime mapping.
- Use generated task briefs for non-trivial work instead of ad hoc one-line prompts.

## Orchestration Language

Use precise terms when explaining framework orchestration to a user:

- A `skill` is reusable instruction context from `skills/*/SKILL.md`. Say "connect/load/use skill `<name>`"; do not call a skill an agent.
- A `named agent` is the current framework role or a registry-backed delegation profile from `agents/registry.tsv`. Say "working as named agent `<name>`" for the active role.
- A `sub-agent` is only real after explicit delegation/spawn. Say "spawning/launching sub-agent `<name>`" only when a separate worker is actually delegated.
- If no separate worker is spawned, say so plainly when there is possible ambiguity: "No sub-agent is being spawned; I am loading skill `<name>` in the current session."

## Named Agents

Named agents are framework-level profiles, not new Codex native `agent_type` values.
The registry maps each framework role to a Codex runtime type:

- `worker`: implementation, fixes, refactors, tests, and framework edits
- `explorer`: read-only review, audit, discovery, and estimation
- `default`: coordination, planning, or mixed work that should not imply a worker

Use:

- `codex-fw agent list`
- `codex-fw agent get <agent>`
- `codex-fw agent prompt <agent> --task "<task>" --skills "<csv>" --ownership "<files or responsibility>"`
- `codex-fw agent validate`

Task briefs and plans must name the active agent, runtime spawn type, work mode, ownership expectation, and skill set. When actually spawning, use the registry runtime type as `spawn_agent.agent_type` and the generated prompt as the sub-agent task.

## Session Display

Framework-driven Codex sessions should make orchestration visible.

Use a display style that shows:

- active role with icon
- model name
- reasoning tier
- primary and supporting skills
- sequential or parallel execution intent

For non-trivial task sessions:

1. show a startup banner
2. print the generated plan file verbatim, preserving emoji, bullets, spacing, and wording
3. wait for explicit `go` when the route is high-risk, contract-bearing, strategic, or explicitly gated
4. use short status blocks during work

Status blocks should favor fast scanning over verbose prose.
Use compact route badges in the form `role-model-tier`, for example `fix-5.5-h`, and avoid repeating the same model/tier details on a second line.

## Runtime Profile

The framework wrapper is allowed to choose a default Codex runtime profile for local workstations.

Current default after `scripts/setup.sh`:

- approval mode: `never`
- sandbox mode: `danger-full-access`

This is the framework's Codex-native replacement for the broader Claude permission preset. Use `codex --raw` or explicit Codex flags when you want stricter behavior for a session.
By default, `high`, `xhigh`, strategic, production, spec-driven, requirement-check, and contract-bearing work pauses after the plan for explicit `go`; low-risk mechanical work auto-starts after the plan.
Set `CODEX_WAIT_FOR_GO=1` to force a pause after every task plan. Set `CODEX_WAIT_FOR_GO=0` to force auto-start after the plan.
Set `CODEX_AUTO_SUBMIT=0` when you want to keep the branch local after a finished issue session.
Task sessions create sibling worktrees from the repository default branch. Set `CODEX_TASK_WORKTREE=0` when you want a task session to stay in the current checkout instead.
PR branches must use product-facing prefixes such as `feature/`, `fix/`, `chore/`, `docs/`, or `test/`. Do not use tool-revealing prefixes such as `codex/` when creating or renaming branches. If a Codex runtime creates `codex/<slug>` before framework startup, rename it to the inferred product-facing branch from the `SessionStart` hook or before publishing.
PR creation must run the framework PR flow: resolve the real GitHub default/base branch, rebase before push, reject shared or tool-revealing head branches, push only the current branch, and create PRs with explicit `--base` and `--head`.
Issue sessions are fresh-by-SHA by default: `codex -w <issue>` fetches the default branch and creates a new sibling worktree named with the default-branch SHA. Use `codex -w <issue> --resume` to reopen the latest existing worktree without fetching, `codex -w <issue> --cleanup` to remove issue worktrees, and `codex --worktrees` to list them.

## Verification

Codex verification is explicit.

After implementation work:

- run targeted tests when available
- run lint or formatter checks when relevant
- inspect `git diff --stat`
- run `codex-fw post-change-check`
- mention anything not verified

Commit flow rules:

- never use `git commit --no-verify`
- if a commit would fail hooks, fix the underlying issue first
- use normal `git commit` semantics; project/user hooks run if they are configured
- do not install, overwrite, or manage project Git hooks from the framework

Use these scripts when helpful:

- `scripts/detect-project-stack.sh`
- `scripts/task-brief.sh`
- `scripts/framework-health.sh`
- `scripts/framework-eval.sh`
- `scripts/framework-maturity.sh`
- `scripts/framework-drift-check.sh`
- `scripts/framework-benchmark.sh`
- `scripts/framework-skill-quality.sh`
- `scripts/framework-skill-corpus-audit.sh`
- `scripts/hooks.sh`
- `scripts/context-pack.sh`
- `scripts/post-change-check.sh`
- `scripts/guard-scan.sh`
- `scripts/doctor.sh`
- `scripts/spec-status.sh`
- `scripts/browser-verify.sh`

## Review Rules

When asked for review:

- findings first
- include file references when possible
- prioritize correctness, regressions, security, performance, and missing tests
- keep summaries short

If no findings are discovered, say so explicitly and mention residual risk or unverified areas.

## Requirement Fidelity

For issue-comment-driven, spec-driven, correction, or acceptance-criteria tasks:

- do not jump straight into edits
- restate the relevant requirement first
- compare current behavior to that requirement
- explain the mismatch in plain terms
- only then implement the smallest correction
- leave already-satisfied requirements untouched except for necessary integration

If the user is effectively asking "is this right?" or "what is wrong here?", the first answer must be the judgment, not the patch.

## Repo-Native Quality

For implementation work, especially UI work:

- identify the actual stack first
- infer local repo conventions from nearby files
- prefer existing helpers, shared components, and styling patterns
- prefer existing validation, testing, logging, and boundary patterns in non-UI code too
- do not introduce inline styles in Tailwind-first repos unless there is a real runtime-only need and the file is marked with `codex-allow-inline-style`

Generic “valid” code is not enough. Code should look native to the repo.

## Framework Maintenance

The Codex framework itself is maintained in this repo.

For framework changes:

1. update `CODEX.md` if orchestration behavior changes
2. update `CODEX.skills.md` if skill injection changes
3. update affected role briefs in `agents/`
4. update affected skills in `skills/`
5. update scripts and templates when execution flow changes
6. run `scripts/framework-eval.sh` when routing, role, or skill behavior changes
7. run `scripts/framework-maturity.sh` when orchestration quality changes
8. run `scripts/framework-drift-check.sh` when routing policy changes
9. run `scripts/framework-benchmark.sh` when benchmark cases change
10. run `scripts/framework-skill-quality.sh` when skills or role bundles change
11. run `scripts/framework-skill-corpus-audit.sh` when auditing skill corpus maturity
12. run `scripts/framework-health.sh`
13. run `scripts/doctor.sh` for production-readiness checks
14. document meaningful changes in `README.md`

## Task Brief Format

Generated task briefs should include:

```md
## Goal
Short outcome-focused objective

## Route
Compact route badge, role, model, reasoning tier

## Stack
Detected stack and framework signals

## Skills
Primary and supporting skills

## Scope
Files, modules, or system slice owned by this task

## Verification
Commands and checks expected before close-out

## Output Contract
- Use the canonical closeout format below for final task reports.
- Keep section names and ordering exactly as shown.
- Use `not required`, `none`, or `not run` instead of omitting sections.
- Use bullets under `Changed`, `Verification`, and `Notes` when there is more than one item.
- Keep prose concise; this is a handoff, not a changelog.
- Do not use the old label format `Status: ...`, `Requirement: ...`, `Fix intent applied: ...`.

```md
✅ route-badge — done | partial | blocked

**Requirement**
[restated requirement or `not required`]

**Current Behavior**
[observed behavior or `not required`]

**Mismatch**
[why the previous/current behavior was wrong or `none`]

**Fix Intent**
[short statement of the correction]

**Changed**
- [file or behavior changed]

**Verification**
- [command/check run, or `not run` with reason]

**Memory**
- loaded from [canonical | override | skipped]; recorded | skipped with reason

**Notes**
- [blockers, residual risk, pre-existing unrelated changes, or `none`]
```

## Closeout Style

- Use the canonical output contract for task closeout.
- Keep `Fix Intent` as the intent in one sentence; put the actual file/behavior list under `Changed`.
- Do not invent extra headings such as `Summary`.
- When discussing PR-ready work, sound like a teammate handing off status, not an auto-generated release note.
```
