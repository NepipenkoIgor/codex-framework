# Skill quality standard

`10/10` is a release gate, not an average or a keyword score. A maintained skill passes only when every applicable assertion, case, and dimension below has direct evidence. `critical` and `major` classify review priority; both block certification when failed. A critical failure in native ownership, routing, safety, version compatibility, or verification remains the highest-priority defect and cannot be offset by other strengths.

## Ten dimensions

| Dimension | Pass evidence | Critical failure |
|---|---|---|
| 1. Native ownership | Unique domain responsibility; no wrapper around Codex planning, goals, git, GitHub, browser, plugins, memory, or agent lifecycle | Reimplements a native capability |
| 2. Routing | Precise positive boundary, explicit exclusion, positive and near-neighbor negative cases | Common prompt routes ambiguously or to a retired skill |
| 3. Repository context | Inspects local instructions, manifests, conventions, affected code, and authoritative diagnostics before prescribing a solution | Forces a greenfield pattern over an existing repository |
| 4. Decision workflow | Ordered decisions, branches, stop conditions, and escalation points tied to the domain | Textbook list without an executable decision path |
| 5. Domain correctness | Current stable invariants, official provenance for volatile facts, and representative semantic counterexamples | Contradictory or unsupported domain guidance |
| 6. Runtime safety | Exact targets, task-owned cleanup, bounded retries/timeouts, permissions and rollback preserved | Broad deletion/process kill, credential exposure, or destructive implicit action |
| 7. Version compatibility | Existing pins preserved; new stacks resolve stable/LTS dynamically; recipes are capability-gated | Remembered current major or unconditional new API on an older pinned project |
| 8. Verification | Focused executable checks, failure interpretation, and affected-path coverage | “Run tests” without naming authoritative evidence or acceptance criteria |
| 9. Output contract | Required findings/changes/checks/risks are explicit and distinguish facts from hypotheses | Completion can be claimed without evidence |
| 10. Maintainability | Owner, review date, concise core, reachable references, replacement/provenance records, no material overlap | Orphaned detail, hidden skill chain, or duplicated ownership |

## Required evidence

Every local skill must have:

1. deterministic structural/governance evidence;
2. at least two positive routing cases and two near-neighbor negative cases;
3. at least one domain semantic case with expected invariants;
4. a safety counterexample when the skill can mutate infrastructure, data, permissions, money, identity, processes, or external systems;
5. a version counterexample when it names a language, framework, SDK, provider API, or CLI with release-dependent behavior;
6. a successful live routing run after routing metadata changes;
7. one independent falsification pass for high-risk corpus or evaluator changes.

Across the complete corpus, fixture-backed scenarios must use at least eight authoritative domain profiles and no one profile may exceed 35% of fixture-backed cases. A fixture states only observed hypothetical evidence relevant to its domain; it must not impose one web/build/test checklist on infrastructure, product, external-provider, read-only, mobile, AI/data, or framework work.

Evidence lives under `evals/`; it is not embedded in skill prompts. A gate must validate actual coverage and expected outcomes, not merely the presence of words such as “workflow”, “test”, or “output”.

`scripts/framework-skill-contract-scaffold.py` creates contracts with `contract_status: scaffold`, no assumed repository fixture, and no certification authority. Domain-specific human review must select only an applicable fixture, replace circular assertions, and set `reviewed` before `certify` will accept model-backed evidence. Fixtures must resolve under `evals/fixtures`. Model evaluators run from a neutral home and working directory with repository/user config and rules ignored; skill, task, fixture, catalog, and criteria are passed explicitly. Before the independent judge sees an answer, the solver performs exactly one bounded, assertion-blind self-falsification/revision against the supplied skill and task fixture. Hidden contract assertions are never supplied to that revision, and a judged failure is never retried to green. `framework-skill-quality.py routing-live`, `semantic-live`, `full-live`, and `certify` produce and validate this evidence.

Corpus-wide routing batches at most 32 cases only when their complete catalog and topology are identical; this amortizes repeated catalog context while retaining exact per-case IDs, three fresh independent trials, strict coverage, and recomputed majority status. `full-live` runs semantic skills with bounded concurrency (default four) and writes one immutable run manifest containing the model, effort, CLI, routing artifact hash, and all 155 semantic source/evaluator digests before model work begins. Every child verifies its assigned digest before and after model calls, and the parent verifies the complete snapshot again before certification; source drift aborts the run instead of producing mixed-revision evidence. Every model call also writes a receipt bound to the exact prompt, output bytes, output schema, model, effort, and CLI. Certification re-parses the raw JSON, requires exact case/assertion coverage, recomputes verdicts and dimension summaries, and rejects missing, duplicated, mutated, external, or unmanifested evidence. A fresh run rejects pre-existing semantic artifacts. `--resume` requires the same run manifest and accepts only artifacts whose current semantic/routing digests, evaluator identity, skill/contract hashes, receipt set, raw evidence, and rebuilt result all validate; stale, failed, forged, incomplete, or mixed-revision evidence stops the run.

## Scoring and release policy

- Each dimension is `pass` or `fail` with an evidence reference and reason. Version-agnostic and read-only skills still pass those dimensions by proving that they introduce no version-dependent or mutating behavior.
- A skill is `10/10` only when all ten dimensions and all required cases pass.
- Corpus release requires every installed skill to be `10/10`; averages cannot hide a failing skill.
- Community candidates run against the same cases. Popularity is discovery evidence only.
- Version-only release changes do not trigger rewrites. A semantic breaking change updates the affected capability rule and its counterexample once.

## Migration order

1. Establish schema, coverage inventory, deterministic validator, and model-backed semantic runner.
2. Repair all existing critical findings and the lowest-quality cohort.
3. Review core and each opt-in pack independently.
4. Benchmark overlapping community candidates on identical cases.
5. Run the complete deterministic, live routing, semantic, safety, version, and falsification suite.
