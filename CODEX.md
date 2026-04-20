# AI Codex Framework

Global operating rules for Codex-based work.

## Objective

This framework ports the useful operating concepts from the Claude framework into Codex-native mechanisms:

- deterministic routing
- explicit skill injection
- spec-aware execution
- script-driven verification
- concise outcome reporting

The framework does not rely on hidden hooks. It uses `CODEX.md`, `CODEX.skills.md`, role briefs, and helper scripts as the visible control plane.

## Core Principles

- Read the codebase before changing it.
- Prefer existing patterns over novelty.
- Keep implementation narrow and explicit.
- Separate implementation, review, and testing concerns.
- Verify changed behavior before closing a task.
- Replace hidden automation with explicit commands and generated task briefs.

## Default Flow

Every non-trivial task follows these phases:

1. Classify the task
2. Detect stack and relevant project commands
3. Route to the correct role
4. Inject the smallest useful skill set
5. Generate a structured task brief
6. Execute
7. Verify
8. Report outcome and residual risk

Use `scripts/task-brief.sh` or `codex-fw brief` to produce the explicit brief for execution.

## Routing

Use this routing order. Earlier matches win.

| Signal | Role |
|---|---|
| framework health, new skill, role updates, routing rules | `framework-manager` |
| dependency audit, CVE, plugin security | `auditor` |
| backlog, triage, sprint, ticket shaping | `project-manager` |
| review, audit, check quality, PR review | `reviewer` |
| test, coverage, regression suite, E2E | `tester` |
| refactor, simplify, migrate, clean up | `refactorer` |
| bug, crash, wrong behavior, performance issue | `fixer` |
| design, architecture, API contract, schema, new dependency | `architect` |
| mobile, React Native, Expo, Flutter | `builder-mobile` |
| Next.js full-stack, Blazor, page plus API route in one framework | `builder-fullstack` |
| n8n, workflow automation, AI feature, LLM, RAG, prompt system | `builder-automation` |
| infra, deployment, CI/CD, Docker, Kubernetes | `builder-infra` |
| UI, page, component, styling, accessibility, frontend state | `builder-frontend` |
| API, backend, service, job, auth, persistence, integration | `builder-backend` |
| full-stack feature without architecture-first design | `builder` |

## Role Selection Rules

- Use `architect` first when the task introduces a new API, schema, dependency, or cross-system contract.
- Use `builder-fullstack` only when frontend and backend live inside the same framework boundary such as Next.js or Blazor.
- Use `builder-mobile` for mobile-native platform concerns, not generic frontend work.
- Use `builder-automation` for AI, agents, prompts, RAG, multimodal, or n8n workflow logic.
- Use `reviewer` as read-only. Reviewers do not modify code.
- Use `tester` after substantial implementation or fixes, or when the task is primarily test work.

## Reasoning Tiers

- `low`: mechanical, well-bounded, usually single-file work
- `medium`: normal implementation, debugging, review, and testing
- `high`: architecture, migrations, cross-system work, hard debugging
- `xhigh`: rescue attempts or unusually ambiguous high-risk changes

Use low reasoning only when the task is clearly mechanical. Otherwise prefer medium.

## Skill Injection

Skill injection is explicit and governed by [CODEX.skills.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.skills.md).

Rules:

- Start from the routed role baseline.
- Add stack-specific skills only when the repo or task justifies them.
- Add feature skills only for clearly relevant systems.
- Keep the list short and concrete.
- Prefer project facts over generic skill guidance when they conflict.

## Spec-Driven Work

When an issue or spec is the source of requirements:

1. ensure `.codex/specs/<issue>/spec.md` exists
2. route from the issue title and summary
3. include the spec path and counts in the task brief
4. keep spec status current as work progresses
5. use browser verification for visual rows when the environment supports it

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
- Treat `agents/*.md` as role briefs, not magic runtime config.
- Use generated task briefs for non-trivial work instead of ad hoc one-line prompts.

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
2. show the plan
3. wait for explicit `go`
4. use short status blocks during work

Status blocks should favor fast scanning over verbose prose.

## Verification

Codex verification is explicit.

After implementation work:

- run targeted tests when available
- run lint or formatter checks when relevant
- inspect `git diff --stat`
- run `codex-fw post-change-check`
- mention anything not verified

Use these scripts when helpful:

- `scripts/detect-project-stack.sh`
- `scripts/task-brief.sh`
- `scripts/framework-health.sh`
- `scripts/post-change-check.sh`
- `scripts/spec-status.sh`
- `scripts/browser-verify.sh`

## Review Rules

When asked for review:

- findings first
- include file references when possible
- prioritize correctness, regressions, security, performance, and missing tests
- keep summaries short

If no findings are discovered, say so explicitly and mention residual risk or unverified areas.

## Framework Maintenance

The Codex framework itself is maintained in this repo.

For framework changes:

1. update `CODEX.md` if orchestration behavior changes
2. update `CODEX.skills.md` if skill injection changes
3. update affected role briefs in `agents/`
4. update affected skills in `skills/`
5. update scripts and templates when execution flow changes
6. run `scripts/framework-health.sh`
7. document meaningful changes in `README.md`

## Task Brief Format

Generated task briefs should include:

```md
## Goal
Short outcome-focused objective

## Route
Role, model, reasoning tier

## Stack
Detected stack and framework signals

## Skills
Primary and supporting skills

## Scope
Files, modules, or system slice owned by this task

## Verification
Commands and checks expected before close-out

## Output Contract
- Status: done | partial | blocked
- Changed: [files]
- Notes: [only blockers or non-obvious decisions]

## Closeout Style

- Prefer one short paragraph over multi-section changelog formatting.
- Lead with the outcome, not a `Summary` heading.
- Mention verification in one compact line or short bullet list only when it adds signal.
- Mention blockers, warnings, or residual risk briefly and directly.
- Avoid robotic sections like `Summary / Verification / Notes` unless the user explicitly asks for that format.
- When discussing PR-ready work, sound like a teammate handing off status, not an auto-generated release note.
```
