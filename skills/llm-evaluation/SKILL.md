---
name: llm-evaluation
description: Design and implement representative LLM evaluation, paired comparisons, calibrated judges, slice and safety analysis, regression gates, and drift monitoring. Use when evaluation is the primary requested outcome; use prompt-engineering to author prompts and rag-pipeline to implement retrieval.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "decision, system versions, population/slices, harms, labels/judges, latency and cost constraints"
---

Design or implement the LLM evaluation requested in $ARGUMENTS.

## Define the decision

Read repository instructions, manifests/lockfiles, serving path, prompt/model/provider/retrieval versions, datasets, telemetry, tests, CI, and privacy policy. Report every artifact as inspected only when it was actually supplied or opened; existence, a planned check, or adjacent runtime configuration is not inspection evidence. Mark unavailable serving, CI, telemetry or policy evidence as a gap. State what decision the evaluation supports, the unit of analysis, target population, important harms, practical effect worth detecting, and who may approve deployment.

Before mutating a dataset, CI rule or promotion gate, resolve the exact targets, owning team, write authority, reversible diff/disable path and rollback evidence; otherwise remain read-only and hand off the blocked mutation.

Preserve installed versions in existing projects and verify tool/provider syntax against matching official documentation or local schemas. For greenfield work, resolve supported stable/LTS dependencies at execution time with `scripts/framework-stack-context.py`; never hardcode a remembered current model, framework, or evaluator.

## Dataset and slices

Use approved production samples where possible, domain-expert labels, known failures, and human-reviewed synthetic cases. Version examples, labels, rubrics, transformations, and provenance. Prevent train/test contamination and judge access to variant identity, expected winner, or irrelevant metadata.

Represent the actual population and predeclare safety/business slices such as tenant, locale/language, input length, rare class, ambiguity, abstention, PII, adversarial injection, accessibility, source freshness, provider failure, and high-impact actions. Keep a locked holdout for promotion decisions. Aggregate scores must not hide slice harm or worst-case failures.

## Comparison design

- Compare variants on the same examples when possible and analyze them as paired observations.
- Account for repeated requests, users, conversations, documents, tenants, and other correlated clusters; do not treat correlated rows as independent evidence.
- Select sample size from expected variance, minimum practical effect, power, design effect, harm, and decision cost. There is no universal minimum.
- Report effect sizes and uncertainty. Choose paired tests, clustered/bootstrap intervals, randomization tests, or hierarchical models according to the data-generating process.
- Predeclare primary metrics and handle multiple metrics, slices, variants, and interim looks with an appropriate multiplicity/stopping policy. `p < .05` alone never justifies auto-promotion.
- Evaluate quality together with format validity, authorization/action safety, refusal/abstention, reliability, latency distributions, and cost.

## LLM judges

Write task-specific rubrics with observable criteria and calibrate judges against blinded human labels. Test agreement, systematic errors, language/domain gaps, and slice bias. Avoid judge leakage from reference answers or variant identifiers when they are not part of the rubric.

Use position swaps for pairwise evaluation and repeat a representative subset to measure order and stochastic effects. A same-model or same-family judge can introduce correlated bias; disclose and test it rather than treating a different model name as sufficient independence. Keep raw scores, reasons suitable for audit, rubric/version identifiers, and failures.

Temperature zero is not deterministic on hosted systems. Record provider, model snapshot when available, prompt/schema, retrieval/index, evaluator, parameters, timestamp, and environment; use repeated runs or seeds only as supported controls, not guarantees.

## Promotion, CI, and drift

Derive regression gates from baseline variance, practical harm, slice requirements, and operational budgets. Separate deterministic contract tests from stochastic quality estimates. Do not fail or promote from one universal percentage threshold.

Before promotion, inspect data quality, primary effects and intervals, guardrails, slice regressions, multiplicity, judge calibration, latency/cost, and operational rollback. Require the configured human or policy approval where impact warrants it.

After deployment, monitor caller-visible outcomes and drift by model/provider, prompt/schema, retrieval/index, corpus, tenant/locale, and time. Add newly verified failures to a reviewed regression set without contaminating the locked holdout. Define alert, investigation, rollback, and re-baselining rules.

## Verification and output

Verify dataset loaders, label provenance, split isolation, paired alignment, cluster identifiers, metric implementations, judge order swaps/repeats, redaction/retention, CI failure behavior, and reproducible reports. Add an executable post-deployment drift exercise that injects or replays a versioned regression, proves monitoring detects it, alerts the accountable owner, preserves investigation evidence and triggers the configured rollback/disable path. Re-run affected checks after fixes.

Report the decision, population and slices, versions/provenance, sampling and statistical design, judge calibration and leakage controls, aggregate and slice results with uncertainty, latency/cost/safety findings, actual checks, promotion/rollback recommendation, and residual risks. Clearly distinguish measured evidence from planned evaluation.
