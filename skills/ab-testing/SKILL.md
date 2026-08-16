---
name: ab-testing
description: Design and implement controlled online experiments, including assignment, exposure logging, estimands, guardrails, analysis, and decision rules. Use when a product change must be evaluated causally; do not use for software test automation, analytics instrumentation alone, or feature-flag rollout without an experiment.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.1
  argument-hint: "hypothesis, unit of randomization, population, estimand, metric, decision risk"
---

# Controlled Experiments

Design the experiment in `$ARGUMENTS` from the decision and data-generating process, not from remembered significance, duration, split, or holdout defaults.

## Boundary

This skill owns causal product experiments and their execution contract. Automated UI/API tests belong to testing skills. Event implementation without random assignment belongs to analytics implementation. A staged feature release belongs to feature flags unless it includes a predeclared causal comparison.

## Workflow

1. Inspect repository instructions, manifests and lockfiles, generated types, current flag/assignment code, identity model, analytics schema, consent and privacy controls, metric definitions, existing experiment platform, and adjacent tests. Explicitly report only findings actually supplied or observed before selecting assignment, persistence, hashing, exposure, or analysis mechanisms. A requested discovery category is not evidence that a matching file, schema or control exists; when exact findings are unavailable, label the gap and make the mechanism conditional. Do not introduce a vendor when the repository already has a supported path.
2. Write the decision, hypothesis, eligible population, unit of randomization, treatment variants, primary estimand, analysis population, primary metric, guardrails, practical effect threshold, and stop/rollback authority before enrollment. If enrollment is ramped, version the stages, entry gates, hold criteria, harm thresholds, approval owner, and rollback action as explicit experiment/product policy rather than platform defaults.
3. Choose fixed-horizon, group-sequential, always-valid sequential, cluster-randomized, switchback, or adaptive allocation from the interference, seasonality, latency, traffic, and decision-loss model. Record the analysis method before looking at outcomes.
4. Calculate sample and duration from baseline uncertainty, effect worth detecting, variance, allocation, power/error policy, clustering, metric maturation, and representative operating cycles. Numbers are outputs of this calculation, not corpus defaults.
5. Implement mutually exclusive, deterministic assignment at the declared unit. Persist experiment/version/variant and assignment time. Identity transitions must not silently rebucket a subject or join another subject's history.
6. Log exposure only at the defined opportunity-to-be-treated boundary. Make exposure idempotent and joinable to outcomes without leaking sensitive identifiers. Define late, duplicate, bot, employee, retry, and cross-device handling.
7. Before reading treatment effects, validate allocation, eligibility, exposure integrity, pre-period balance, missingness, metric pipelines, and sample-ratio mismatch. A failed integrity check blocks a ship decision until explained and repaired.
8. Estimate the predeclared effect with uncertainty and practical relevance. Correct or explicitly control multiplicity for tested variants, metrics, looks, and segments. Treat exploratory slices as hypotheses for later confirmation.
9. Apply predeclared guardrail and decision rules. A small p-value alone never means “ship”; a non-significant result alone never proves equivalence. Consider confidence interval, decision threshold, guardrails, external validity, and unresolved integrity risks.
10. Verify assignment determinism and distribution, exposure deduplication, cross-tenant isolation, event joins, late-arriving outcomes, metric recomputation, method implementation, rollback, and experiment cleanup. Compare independent query or library results for material decisions.

## Safety and integrity counterexamples

- Do not broaden targeting or change the metric after seeing results merely to reach significance; redesign and restart or label the analysis exploratory.
- Preserve a dated deviation history for targeting, metrics, guardrails, segments, looks and stopping decisions; review it with allocation/data-pipeline integrity and method-valid uncertainty before any rollout decision.
- Do not assign by session when the treatment persists by account, or by account when members can interfere, without modeling the mismatch.
- Do not merge anonymous and authenticated histories unless the identity rule prevents two people or devices from contaminating one assignment.
- Do not use standard fixed-horizon p-values with repeated optional stopping. Use the predeclared sequential correction or wait for the fixed horizon.
- Do not claim a vendor's default method, threshold, bucketing, or exposure behavior without checking the configured product/version and official documentation.
- Treat manifests, resolved lockfiles, generated types, runtime configuration, and persisted assignment format as the authority for an existing repository. Verify vendor capabilities in official documentation matching the installed version; record the exact source and capability decision beside the relevant configuration or implementation. Never embed a remembered "current" SDK version in this reusable workflow, and treat SDK or methodology upgrades as separate migrations.
- Do not expose a harmful treatment solely to satisfy sample size. Risk limits, ramp gates, and shutdown authority follow the product's impact policy.

## Output

Report the decision and estimand, population and randomization unit, method and assumptions, calculated sample/duration with inputs, assignment/exposure contract, integrity and guardrail checks, analysis and multiplicity rule, implementation/tests, decision evidence, and residual validity or privacy risks. For every version-sensitive vendor/API/method decision, require the exact verified source, installed/configured version and capability conclusion to be stored beside the relevant repository configuration or implementation; a chat-only note or remembered-current version is insufficient. Separate executed evidence from proposed verification.

## Provenance

- Experiment trustworthiness and sample-ratio mismatch: https://exp-platform.com/Documents/2019_KDDFabijanGupchupFuptaOmhoverVermeerDmitriev.pdf
- General controlled-experiment design reference: https://exp-platform.com/Documents/2023-03-11EncyclopeiaMLDSABTestingFinal.pdf
