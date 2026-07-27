---
name: visual-regression
description: Implement deterministic visual regression coverage and review gates using the repository's installed browser/component tooling. Use for requested screenshot-baseline changes; do not use for functional E2E alone.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
---

# Visual Regression

1. Inspect pinned Node/package manager, test runner/browser versions, CI actions, fonts/render environment, component stories, baseline ownership and privacy policy. Before material test/baseline/CI mutation, define a reversible diff and baseline restoration procedure, exact owner/approval and failure trigger. Derive commands/actions/pins from repository manifests/lockfiles and current official capability; do not hardcode remembered Node/action versions. For an explicitly authorized greenfield setup only, resolve the Node, package-manager, runner and browser-automation stack together from current official sources, generate manifest/lockfile, and make those artifacts authority.
2. Select user/component states, browsers and viewports from supported product/device evidence and risk—not universal breakpoint lists.
3. Make readiness application-specific: await named DOM/data/font/image/hydration conditions and settle owned animation/clock/network fixtures. Derive any readiness timeout or retry attempt/elapsed bound from observed application settlement, runner behavior and CI deadline; after exhaustion fail with evidence instead of retrying indefinitely. `networkidle` is not a universal readiness signal for apps with polling/streams/analytics.
4. Use deterministic seeded/mock data. Do not mask the subject under test or broad dynamic regions; fix determinism or scope assertions. Any justified mask is narrow, documented and cannot hide the behavior being reviewed.
5. Derive pixel/color/diff thresholds from controlled baseline variance and defect sensitivity. Record environment. Never copy a universal ratio.
6. Treat screenshots, traces and artifacts as potentially sensitive: synthetic accounts/data, redaction outside the subject, access-controlled artifacts, policy retention, no tokens/PII in names or output.
7. CI must fail or require explicit accountable approval on unexpected diffs. Do not use exit-zero-on-change as the review gate. Baseline updates require human-visible diff, reason and code review.
8. Verify intentional defect detection, readiness failure, responsive/theme/state coverage, fonts, artifacts, retry/flakiness evidence and task-owned browser cleanup.

Report coverage matrix, readiness contracts, environment/pins, variance-derived thresholds, masking rationale, privacy controls, review gate, executed evidence, and residual or unverified browser/font/CI/artifact risk.
