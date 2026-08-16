---
name: performance-budgets
description: Define and enforce evidence-derived frontend performance budgets by route, journey, device/network class, artifact and field distribution. Use when preventing measurable performance regression; use performance to diagnose an observed bottleneck.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  argument-hint: "routes/journeys, user device/network/geography slices, current lab/field baselines, CI/RUM stack and business impact"
---

Implement performance budgets for $ARGUMENTS.

Read instructions, manifests/lockfiles/runtime pins, build outputs, route/chunk graph, existing lab/RUM setup, CI trust/artifacts and privacy policy. Establish comparable baselines for each important route/journey and representative device/network/geography/release slices. Use field distributions and tails plus controlled repeated lab evidence; one aggregate average or Lighthouse run is insufficient.

Derive artifact, resource, LCP/INP/CLS and interaction budgets from healthy observed behavior, business harm, variance and supported user population. Budgets can differ by route/device and should ratchet deliberately. Define exception owner, evidence, expiry and rollback. Do not copy universal thresholds merely because a tool supports them.

RUM dimensions must be bounded and privacy-safe; do not collect raw URLs/query strings, user IDs or high-cardinality device fingerprints. Sampling and missing data must remain visible. Store raw profiles/reports/screenshots only as protected artifacts with explicit retention; do not publish them publicly by default.

Preserve repository Node/runtime and action/tool pins. Resolve current actions, browsers and Web Vitals/tool APIs from installed context and official sources; do not hardcode stale Node/action majors. Protect secrets and trusted artifact/cache writes from untrusted PRs.

Verify a known regression fails, like-for-like baselines pass, variance/flakes are handled without arbitrary retries, field slices/tails are queryable, exceptions expire, and CI artifact access/retention is safe. Before enabling the gate, exercise its rollback/disable path and prove the prior trusted CI behavior is restored without accepting a known regression or leaving stale privileged artifacts. Report budgets and derivation, environment/slices, tool/version provenance, enforcement, results and coverage gaps.

Read [references/full-guide.md](references/full-guide.md) when the task explicitly requests its specialized topic or when a concrete selected tool/provider creates an unresolved syntax or configuration question. A routine performance-budget, CI-policy, baseline, or main-workflow task that explicitly says no provider/framework/optional detail is needed must not load or select the broad guide; report `none` for that main-only case.
