# Skill corpus governance

The framework keeps a small universal core and installs domain knowledge only through explicit packs or project-scoped selection. Native Codex capabilities and installed trusted plugins remain authoritative for planning, goals, agent lifecycle, git, GitHub, browser control, memory, and integrations.

## Lifecycle

Every local skill must have a unique routing boundary, `metadata.version`, `metadata.owner`, and a quoted `metadata.reviewed` date. The main file contains the decision workflow and critical invariants; optional provider, framework, and version detail belongs in relative `references/` files.

Review a skill when its primary platform releases a compatibility-changing version, an incident contradicts its guidance, routing evaluation shows ambiguity, its main file approaches 400 lines, or its review date exceeds the team's chosen maintenance interval.

For version-sensitive skills, follow [the dynamic version context policy](version-currency.md). New projects resolve stable/LTS versions from distribution sources at execution time; existing projects derive context from manifests and lockfiles and preserve their pins until an explicit migration. Skills express capability gates, not a checked "current version" snapshot.

## Placement

- `skills/core.txt`: at most 25 universal skills.
- `skills/packs/*.txt`: opt-in domain sets; every non-core local skill belongs to at least one pack.
- trusted community skills: pinned in `skills/community-pilot.tsv`, materialized only for an explicit pilot.
- policy that must apply to every task: `AGENTS.md`, native rules, or deterministic hooks, never an automatically assumed skill.

The core and pack manifests are the only maintained catalog taxonomy. Legacy `SKILLS_MAP.*.md` files were removed because they duplicated the manifests and drifted independently.

## Native capability exclusion

Do not create local skills for native plans/goals/status, commit/push/PR wrappers, GitHub comment plumbing, browser process reset, model selection, or agent lifecycle. Prefer current official plugins for external product capabilities.

## Consolidation decisions

| Retired skill(s) | Replacement |
|---|---|
| `framework-orchestration-audit` | audit mode in `framework-management` |
| `react-native-patterns` | `mobile-implement-reactnative` |
| five `fullstack-blazor-*` mode skills | `blazor-development` |
| `spec`, `re-spec`, `status`, `verify` | native plans, goals, task state, and Browser |
| `commit`, `ci-status`, `pr-review`, `pr-fix-comments` | native git/GitHub capabilities and plugins |
| `playwright-reset` | native Browser lifecycle and task-owned cleanup |
| `process-hygiene` | `AGENTS.md`, rules, hooks, and repository instructions |
| `ui-kit-bootstrap` | bootstrap mode in `design-system-implement` |
| three `fullstack-nextjs-*` mode skills | `nextjs-development` with mode-specific references |
| `graphql-design`, `graphql-implement` | `graphql-development` |
| `saas-billing-portal`, `upgrade-downgrade-flows` | `subscription-lifecycle` |

Generic mobile/backend/test skills are now concise baselines; platform skills are self-contained and no longer create hidden `Pair with...` chains. Transactional email no longer claims push-notification ownership.

## Gates

`scripts/framework-skill-governance.sh` checks routing metadata, ownership, review dates, maximum main-file size, version pins, unsafe cleanup recipes, hidden skill chains, native-wrapper resurrection, core/pack coverage, missing or unreachable references, invalid profile metadata, and high normalized-line overlap.

`scripts/framework-skill-quality.py check` requires a digestable contract for every skill, including two positive and two near-neighbor negative routing cases, domain and safety scenarios, version cases where applicable, all ten dimensions, and reference-selection fixtures. `scripts/framework-skill-routing-live-eval.sh` runs three fresh trials against the complete installable catalog and batches one skill's independent cases into each trial to keep the gate bounded. Every model call has a hard five-minute timeout and fails closed; there is no retry-to-green loop. `semantic-live` uses a solver that cannot see the assertions and a separate strict judge. Routing evidence is keyed to the shared catalog descriptions/registrations plus only the routing cases covered by that artifact; semantic evidence is keyed independently to each skill, its contract, fixtures, references, evaluator, and scoped routing digest. `certify` therefore rejects stale evidence without invalidating unrelated routing or semantic artifacts after a one-skill case, body or scenario repair.

The retired keyword score is no longer a release signal. Its compatibility command delegates to the conjunctive quality gate, so no average can hide one failing skill.

## Community adoption

Community popularity is discovery evidence, not a trust decision. A candidate must be pinned to an immutable commit, have acceptable license/provenance, pass static safety review, and outperform the local baseline on representative tasks before it can replace a maintained local skill. See [community skill pilots](community-skills.md).
