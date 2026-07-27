---
name: technical-debt
description: Identify, evidence, prioritize, and plan technical debt by business impact, delivery friction, operational risk, uncertainty, and paydown cost. Use when a debt assessment or paydown plan is requested; not for automatic refactoring.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "scope, roadmap/business goals, incidents/churn/delivery evidence, risk tolerance, capacity and decision horizon"
---

Assess technical debt for $ARGUMENTS without changing product code unless implementation is explicitly requested separately.

## Build evidence, not a smell inventory

Read instructions, architecture/code/tests/docs/infrastructure, issue and incident history, delivery/churn data, support policy and roadmap. A large file, nesting depth, complexity score, TODO, dependency age, test coverage percentage or sprint allocation is a signal—not universal proof or priority.

For each candidate, identify the affected capability and owner, observable friction/failure, frequency and trend, blast radius, business/customer/operational/security impact, current workaround, evidence provenance and confidence. Separate incurred debt from intentional tradeoffs, missing features, defects and speculative modernization.

## Prioritize with uncertainty

Estimate cost of carrying and paying down debt using the best available local evidence: repeated engineering/support time, incidents, release delay, reliability/security exposure, opportunity blockage and migration risk. Use ranges and assumptions when data is weak. Do not invent dollars, velocity gains, ROI, fixed scoring scales, line-count thresholds, coverage targets, “one sprint per quarter” or universal capacity percentages.

Prioritize relative to roadmap timing, risk appetite, dependency/EOL deadlines, reversibility and learning value. Security debt severity still requires threat/exposure evidence; “outdated” is not automatically exploitable. High-cost rewrites need staged compatibility, observability, cutover and rollback; opportunistic cleanup must remain within task scope.

Define a concrete acceptance signal for each proposed paydown item: removed failure mode, measured lead-time/latency improvement, supported upgrade, simplified change path, recovered ownership, testable contract or retired system. Set owners and revisit dates only when the organization provides them.

## Output

Report scope and evidence sources; a debt register with issue, category, impact, frequency, risk, business consequence, confidence, carry-cost range, paydown options/effort and dependencies; prioritized recommendations with rationale; staged verification/rollback; deferred items and trigger conditions. Clearly distinguish measured facts, estimates and missing evidence.
