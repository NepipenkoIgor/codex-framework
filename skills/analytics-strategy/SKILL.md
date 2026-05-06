---
name: analytics-strategy
description: Design event taxonomies, KPI coverage, and measurement plans before implementation.
metadata:
  version: 2.0
  argument-hint: "product area, business questions, funnel, analytics tools, privacy constraints"
---

# Analytics Strategy

Use this skill when the user needs a tracking plan rather than raw analytics instrumentation.

## When To Use

- Product questions, KPI definitions, funnel or retention analysis
- Event taxonomy design before implementation
- Analytics review for noisy, missing, or inconsistent events
- Experiment measurement planning
- Privacy-sensitive tracking decisions

## Workflow

1. Define product questions and KPIs first.
2. Map events to funnels, retention, activation, or revenue goals.
3. Keep event naming stable and explicit.
4. Separate must-have product events from optional diagnostics noise.
5. Define event properties, identity rules, source of truth, and expected cardinality.
6. Specify where events fire and how duplicate firing is prevented.
7. Add privacy constraints: PII, consent, retention, and regional restrictions.
8. Define validation: QA checklist, dashboard checks, and backfill expectations.

## Quality Bar

- Track decisions users make and outcomes the product cares about, not every click.
- Prefer stable event names and typed property schemas.
- Keep client and server events consistent; use server events for billing, auth, and irreversible actions.
- Avoid high-cardinality properties unless explicitly needed.
- Tie every must-have event to a decision, KPI, or operational alert.

## Anti-Patterns

- Adding events without a product question.
- Tracking PII or free-form user content by default.
- Using inconsistent names for the same concept.
- Firing events from both client and server without deduplication.
- Treating analytics as a substitute for audit logging.

## Verification

- Review the plan against the product questions and KPIs.
- Check event names and property schemas for consistency.
- Confirm privacy and consent handling.
- Define QA steps to verify events in the analytics destination.
- Identify dashboards or alerts that prove the plan is useful.

## Output Contract

Status: done | partial | blocked
Questions/KPIs: [what we need to answer]
Event taxonomy: [events and properties]
Implementation notes: [client/server firing points and dedupe]
Privacy: [PII, consent, retention]
Verification: [QA and dashboard checks]
Notes: [tradeoffs or open questions]
