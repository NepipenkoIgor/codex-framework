---
name: adr-management
description: Manage architecture decision records with lightweight templates, status tracking, and links to implementation changes.
metadata:
  version: 2.0
  argument-hint: "decision topic, status, alternatives, impacted systems, implementation links"
---

# ADR Management

Use this skill when the task requires creating, updating, or reviewing architecture decision records.

## When To Use

- A decision changes architecture, data model, API contracts, security posture, deployment, or operational ownership.
- Multiple viable options exist and future maintainers need the reasoning.
- A previous decision is being superseded, amended, or rejected.
- A design review needs traceability from discussion to implementation.

Do not create ADRs for routine implementation details that are obvious from code.

## Workflow

1. Capture the decision, context, options, and consequences.
2. Link the ADR to the code, issue, or spec it governs.
3. Prefer short records that explain why the decision exists.
4. Update superseded ADRs instead of leaving conflicting guidance around.
5. Record status clearly: proposed, accepted, superseded, deprecated, or rejected.
6. Add follow-up actions when the decision requires implementation, migration, or cleanup.

## ADR Shape

- Title: concise and decision-oriented
- Status: proposed | accepted | superseded | rejected | deprecated
- Context: problem, constraints, forces, and current state
- Options considered: include the rejected options, not only the winner
- Decision: the chosen approach
- Consequences: benefits, costs, tradeoffs, migration impact, operational impact
- Links: issues, PRs, specs, diagrams, related ADRs

## Quality Bar

- Keep the ADR factual, short, and durable.
- Explain why, not only what.
- Prefer explicit tradeoffs over consensus-sounding prose.
- Link implementation and verification so the record can be audited later.
- Keep ADRs aligned with current code; stale ADRs should be superseded, not silently contradicted.

## Anti-Patterns

- Writing an ADR after the fact that hides real alternatives.
- Leaving two accepted ADRs that conflict.
- Using ADRs as broad documentation dumps.
- Recording reversible code details as permanent architecture.
- Omitting consequences, owner, or follow-up work.

## Verification

- Check existing ADRs for conflicts or prior decisions.
- Confirm the implementation plan matches the accepted decision.
- Verify links to issues, PRs, specs, or code paths.
- Ensure superseded records point to the replacement ADR.

## Output Contract

Status: done | partial | blocked
Decision: [one sentence]
ADR: [path or proposed path]
Status value: [proposed/accepted/superseded/rejected/deprecated]
Links: [issues, PRs, specs, related ADRs]
Verification: [conflict check and alignment check]
Notes: [tradeoffs or unresolved decisions]
