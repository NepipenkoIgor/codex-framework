---
name: analytics-strategy
description: Design product questions, KPI definitions, event/identity schemas, privacy rules, decision ownership, and a measurement QA plan before instrumentation. Use for a read-only measurement plan; route implementation to analytics-implementation and causal experiment design to ab-testing.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.1
  argument-hint: "product decisions/questions, subjects and identity, funnels/cohorts, privacy policy, consumers"
---

# Analytics Strategy

Produce a measurement contract, not SDK code, provider recipes or repository changes.

## Workflow

1. Identify the product/business decision, accountable decision owner, decision cadence, affected population and action they will take. Reject metrics with no owner or decision.
2. Define questions and metrics with grain, numerator/denominator, inclusion/exclusion, source-of-truth domain state, time/calendar basis, attribution/window, dimensions, correction/backfill and quality thresholds.
3. Define a minimal versioned event schema: semantic trigger, authoritative producer, immutable event ID, subject/tenant, occurrence time, properties/types/classification and retention. Naming style and event count follow the existing taxonomy and product needs, not universal rules.
4. Define identity lifecycle: anonymous, authenticated, account/tenant switch, logout, merge/link and deletion. State which historical association is permitted and how deduplication works across client/server producers.
5. Apply approved legal/privacy policy: purpose/lawful basis or consent decision, minimization, region, retention, access/deletion and destination restrictions. PII and free-form properties are excluded by default unless a documented decision, necessity and control justify them.
6. Separate instrumentation notes from strategy. Specify recommended firing authority and QA evidence, then hand implementation to `analytics-implementation`; do not prescribe framework hooks or provider APIs here.
7. For a causal experiment, power/sample allocation, assignment, guardrails and inference belong to `ab-testing`. This skill may define the decision metric but must not claim observational funnel changes prove causality.

## Required Review Cases

- A requested property contains email, support text or arbitrary URL: classify necessity and risk; prefer bounded derived categories and accountable privacy approval.
- Client and server can emit the same irreversible outcome: select one authority or define one shared immutable event ID/dedupe contract.
- A metric has no action or owner: remove it or name the decision contract before adding telemetry.
- Stakeholder asks whether a change caused conversion lift: route experiment design/inference to `ab-testing` and label observational evidence accordingly.

## Output

Return decisions/owners, questions/KPIs, metric definitions, event/property schema, identity/dedupe model, privacy/legal decisions and approvers, instrumentation handoff notes, QA/destination evidence plan, gaps and assumptions. No implementation claims.
