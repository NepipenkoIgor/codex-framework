# Skill corpus audit — 2026-07-27

## Verdict boundary

`10/10` means the release gate in [skill-quality-standard.md](skill-quality-standard.md) passes for every installed skill. It does not mean that a prompt file can guarantee perfect future agent behavior. Agent quality still depends on the task evidence, repository state, model behavior, tool authority, external systems and verification that was actually performed.

Do not call this corpus `10/10` from metadata or an average. The release verdict requires all deterministic checks, live routing, per-skill semantic evidence, one bounded falsification review and a clean final diff. Keep the PR in draft if any of that evidence is missing or failing.

## Problems addressed

1. Routing descriptions were short but ambiguous, and several generic/platform/full-stack skills duplicated ownership.
2. Long skill bodies mixed durable decisions with volatile framework/provider recipes and unsafe copy-paste defaults.
3. Native Codex planning, status, git, GitHub, browser and agent lifecycle had local wrapper skills.
4. A keyword score rewarded length and the presence of words such as “test” or “output” without proving semantic quality.
5. Version guidance could preserve a remembered major instead of inspecting an existing repository or resolving a new stack when the task runs.
6. Duplicate maps, hidden skill chains, orphaned references and broad cleanup guidance increased drift and context cost.

## Current structure

| Measure | Before | Current |
|---|---:|---:|
| Maintained skills | 167 | 155 |
| Main `SKILL.md` lines | 35,344 | 6,082 |
| Mean main-file lines | 211.6 | 39.2 |
| Reviewed quality contracts | 0 | 155 |
| Scaffold contracts | n/a | 0 |
| Routed reference files | not enforced | 46 files / 69 cases |
| Dynamic release resolvers | 0 | 24 |

The universal core contains only `framework-management`; domain knowledge is opt-in through one owning pack per skill. This avoids sending all domain instructions to every task. Live routing nevertheless evaluates the complete installable catalog, so installing multiple packs cannot hide a cross-pack collision.

## Consolidated and removed

Twenty-five skills were retired. Native wrappers for spec/re-spec, status, verification, commit/PR/CI plumbing, browser reset and process hygiene were deleted. Repeated platform-mode families were consolidated into `blazor-development`, `nextjs-development`, `graphql-development` and `subscription-lifecycle`. `react-native-patterns`, `ui-kit-bootstrap` and the separate framework-orchestration audit were merged into sharper maintained owners.

The exact old-to-new mapping is maintained in [skills-governance.md](skills-governance.md). Governance rejects both resurrection of retired directories and backticked routing references to retired skills.

## Missing capabilities added

The audit added genuinely distinct boundaries for account verification, backup/disaster recovery, cloud architecture, data-pipeline engineering, frontend visual direction, in-app notifications, MLOps, mobile architecture and threat modeling. Consolidated replacements preserve the unique Blazor, Next.js, GraphQL and subscription-lifecycle invariants without recreating separate design/implement/debug/test families.

`frontend-design-direction` fills an expert-review-identified art-direction gap while leaving repository implementation to frontend/design-system skills. The review is not a reproducible benchmark and cannot claim visual improvement from prose alone; preserved same-condition responses, screenshot comparison and agreed human or rubric evidence remain required.

## Version currency

Existing projects are repository-first: manifests, lockfiles, runtime files, installed/generated types, CLI/configuration schemas and matching official documentation determine capability. Ordinary work preserves those pins; an upgrade is a separate migration.

Greenfield work resolves stable framework releases and production LTS runtimes at execution time through `framework-stack-context.py`. The registry stores resolver types, release tracks, official documentation and non-numeric action templates—not a checked “latest version” snapshot. The generated manifest and lockfile become authoritative immediately after scaffolding.

This prevents both “bootstrap Next.js 15 after 16 exists” and the opposite error: silently forcing a current major into a supported pinned project. It does not eliminate semantic breaking changes; those update one affected capability rule and counterexample rather than every skill.

## Community replacements

Popularity is discovery evidence, not an adoption gate. Eight candidates are pinned to immutable commits in `community-pilot.tsv`. The current conservative decisions are provisional expert review, not reproducible benchmark results:

- hold unlicensed Vercel candidates until provenance is usable;
- reject the floating web-design wrapper;
- retain the local Supabase and PostgreSQL workflows while mining only revalidated traps;
- reject generic systematic-debugging because it overlaps sharper frontend/backend/mobile diagnosis;
- adapt the narrow frontend-design gap locally rather than installing Anthropic's broader workflow;
- retain the stronger local SEO audit boundary.

No community skill replaces a maintained local skill without preserved identical representative-task responses and run metadata, license/provenance, routing/safety pass and a reproducible improvement. The current evidence therefore supports non-adoption only. See [community-skills.md](community-skills.md).

## Overengineering removed

- Seven hand-maintained skill maps were replaced by authoritative core/pack manifests.
- Twenty-five wrapper or duplicate skills were removed.
- Large textbook bodies were reduced to decision workflows; optional detail moved to routed references.
- The keyword average was replaced by a conjunctive ten-dimension contract.
- Routing cases for one skill are batched into three independent majority trials instead of one model call per case.
- Every model call has a five-minute timeout and fails closed; the evaluator never retries a failed case to manufacture green output.
- Routing and semantic digests are scoped per skill around a shared catalog digest, so repairing one case, body or scenario does not invalidate unrelated passing evidence.
- `framework-health.sh` no longer repeats quality checks already owned by `framework-eval.sh`.

## Historical audit score and release evidence

The framework-management audit scores seven dimensions from 1–10. A score is `10` only when the applicable release gate has direct evidence; a pending dimension cannot be rounded up. All seven dimensions now meet the release rubric after one independent falsification review, the resulting revision, strict recertification and the full final gate suite. This is a release assessment, not a mathematical guarantee that future model behavior, external registries or project evidence cannot drift.

| Dimension | Final score | Evidence |
|---|---:|---|
| Native ownership | 10 | Wrapper-removal gates, retirement map, native-first AGENTS contract |
| Routing | 10 | 631/631 live routing cases across the complete catalog; 8/8 live native owner/delegation cases |
| Skill design | 10 | Main corpus reduced to 6,082 lines; 46 routed references; 155 reviewed conjunctive contracts |
| Coordination | 10 | Parent-owned contracts, bounded delegation and isolated-writer policy |
| Verification | 10 | 1,237 routing/semantic/reference cases, 155/155 current artifacts certified, framework eval 33/33 and health 0 failures |
| Runtime safety | 10 | Domain counterexamples, setup collision and destructive-pattern gates pass; reviewer findings were revised and affected checks rerun |
| Maintainability | 10 | Owners/review dates, exact pack ownership, provenance, retirement paths and scoped digests |

The independent reviewer falsified the original semantic green result: candidate omissions could be cured by skill prose, evaluator implementation was absent from evidence digests, stack discovery could escape the repository or prefer an installed prerelease over the lockfile, preview/prerelease tracks were insufficiently rejected, community claims exceeded preserved benchmark evidence, and setup could overwrite an existing empty guidance file. The revision made candidate-output coverage mandatory, bound evaluator source into routing/semantic digests, enforced repository boundaries plus lockfile authority and stable/LTS-only resolution, downgraded community conclusions to reproducible evidence, and preserved every existing setup target. The strict semantic corpus was then regenerated rather than reusing the invalid evidence.

Historical release evidence captured on 2026-07-27 (the temporary raw artifact paths below are not a current reproducible certification):

- `python3 scripts/framework-skill-quality.py certify --artifact-dir /tmp/codex-framework-quality-finalrun.nw2rYh` — 155/155 current strict artifacts certified with zero critical findings.
- The preserved routing artifacts cover 631/631 cases; `bash scripts/framework-live-eval.sh` covers 8/8 native owner/delegation cases.
- `bash scripts/framework-version-drift-check.sh --live` resolves all 24 configured stable/LTS channels at execution time; on this run Next.js resolved to 16.2.12.
- Governance reports 155 skills, one universal core skill, zero failures and zero warnings. Corpus, framework eval (33/33), drift, surface parity and framework health all pass.
- A task-owned setup fixture proved an existing user skill and global guidance remain byte-identical while the namespaced core and selected pack install.
- All 155 YAML frontmatter blocks parse; shell syntax and Python compilation pass; `git diff --check` is clean; gitleaks reports no leaks.

## Maintenance plan

1. Run deterministic governance, version, corpus, framework, drift, parity and health gates on every corpus change.
2. Run live routing after descriptions, registration or routing cases change.
3. Re-run semantic evaluation only for stale per-skill digests; never retry a failed answer merely to obtain green output.
4. Run the live version resolver when a release source changes and inspect an actual project before version-sensitive work.
5. Review a skill after a compatibility-changing release, an incident, a routing failure, a new unsafe counterexample, material overlap or the team's chosen staleness interval.
6. Benchmark community candidates at immutable commits; update or adopt only from reproducible evidence.
7. Use exactly one independent falsification review for a high-risk corpus/evaluator change, then revise and rerun affected checks once.
