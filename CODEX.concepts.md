# CODEX.concepts.md — Codex Framework Constitution

Read this before changing routing, planner behavior, skill resolution, or multi-agent workflow.

## Core Invariants

### 1. Skills stay lazy

The planner may identify skill names, domains, stack signals, and feature signals.
It must not read skill bodies during classification or plan display.
Skill content belongs only in execution prompts or explicit manual reads.

### 2. Orchestrator policy lives in source-of-truth files

These files are the control plane:

- `CODEX.md`
- `CODEX.skills.md`
- `CODEX.concepts.md`
- `ORCHESTRATOR_REFERENCE.md`
- `SKILLS_MAP.*.md`

Shell scripts consume these concepts. They should not silently redefine them.

### 3. Domain-scoped maps are the routing source of truth for skills

Task-to-skill resolution should prefer the smallest relevant `SKILLS_MAP.<domain>.md`.
Use `SKILLS_MAP.core.md` for cross-cutting concerns.
Do not load every map when only one or two domains are relevant.

### 4. Agent type changes what work is done, not what knowledge is available

Fixers, reviewers, and testers working in a frontend domain need the same frontend brain as builders.
Skill resolution should be domain-first, then stack, then feature, then task extras.

### 5. Planner and brief generation may cache repo signals

Stack and feature detection may be cached under `.codex/cache/`.
Cached facts are reusable across a session, but the framework must be able to refresh them deterministically.

### 6. Retry and fallback policy must be deterministic

When the framework chooses a model tier, it must also have a deterministic fallback chain.
Fallback behavior belongs in `ORCHESTRATOR_REFERENCE.md`, not scattered shell heuristics.

### 7. Structured output is mandatory for delegated work

Delegated work should always use the canonical route-badge closeout:

- `✅ route-badge — done | partial | blocked`
- `Requirement`
- `Current Behavior`
- `Mismatch`
- `Fix Intent`
- `Changed`
- `Verification`
- `Notes`

The framework should bias toward compact, parseable outputs over prose and must not reintroduce the legacy `Status: ...` label format for normal closeout.

### 8. Named agents are registry-backed

`agents/*.md` are role briefs. `agents/registry.tsv` turns those briefs into framework-level named agents by mapping each role to a Codex runtime spawn type, work mode, ownership requirement, and parallel-safety flag.

Native Codex runtime types remain `worker`, `explorer`, and `default`. Framework names such as `builder-backend`, `reviewer`, and `tester` must be passed through the registry and prompt builder before delegation.

### 9. Contract-first coordination is required for parallel ownership

If a task spans shared contracts such as API schema, DB changes, or shared types, the planner should create the contract before parallel work begins.

### 10. Requirement-sensitive work must judge before it edits

If a task is driven by issue comments, acceptance criteria, correction requests, review feedback, or wording like `should`, `must`, `expected`, or `wrong`, the first execution step is:

- restate the requirement
- describe current behavior
- identify the mismatch
- define the smallest correct fix

Implementation starts only after that mismatch report exists.

### 11. The framework repo is the source of truth

Do not patch installed shell wrappers or copied project files and stop there.
Changes must land in this repo first, then flow through bootstrap or setup.

## Four-Tier Injection Model

1. Domain baseline
2. Stack refinement
3. Feature refinement
4. Task extras

Mechanical low-tier work may skip broad injection.

## Domain Set

The framework uses these domains:

- `core`
- `frontend`
- `backend`
- `mobile`
- `infra`
- `specialized`
- `testing`

Cross-system work may use more than one domain map, but only the relevant set.

## Cached Signal Model

Cache files under `.codex/cache/`:

- `stack.txt`
- `features.txt`
- `domains.txt`

The cache is an optimization, not the authority. The authoritative logic still lives in the detector scripts and maps.

## Known Failure Modes To Avoid

- embedding skill files during planning
- adding route logic only in shell regexes and not updating docs/maps
- loading every domain map for every task
- letting retry policy live only in a developer’s head
- treating reviewers as lacking domain skills
- jumping into implementation before proving requirement understanding
