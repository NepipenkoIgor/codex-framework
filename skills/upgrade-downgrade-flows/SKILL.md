---
name: upgrade-downgrade-flows
description: Design and implement subscription plan change flows including proration, constraints, and user communication.
metadata:
  version: 2.0
  argument-hint: "billing provider, plan model, upgrade/downgrade timing, proration policy, entitlement changes"
---

# Upgrade Downgrade Flows

Use this skill when the work involves subscription changes, plan transitions, or billing UX around upgrades and downgrades.

## When To Use

- Upgrade, downgrade, cancellation, resume, or plan-switch flows
- Entitlement changes caused by billing plan transitions
- Proration, scheduled changes, trials, or billing-cycle alignment
- User communication around plan consequences
- Billing state audits or bug fixes

## Workflow

1. Identify the billing provider, plan model, entitlement model, and current subscription state machine.
2. Define transition rules for each path: upgrade, downgrade, lateral move, cancellation, trial conversion, and failed payment recovery.
3. Decide timing: immediate, end of billing period, scheduled date, or after admin approval.
4. Define proration, credits, refunds, tax handling, invoices, and payment confirmation behavior.
5. Map entitlements before and after the transition; prevent access gaps and over-entitlement.
6. Design UI copy and confirmation states that explain cost, timing, lost features, and reversibility.
7. Persist an audit trail of requested, scheduled, applied, failed, and reverted changes.
8. Verify webhooks, retries, idempotency, and race conditions between UI actions and provider events.

## Quality Bar

- Treat billing provider state as authoritative, but keep local entitlements consistent and recoverable.
- Make state transitions explicit and idempotent.
- Use existing billing abstractions and plan constants; do not hardcode price IDs in UI or business logic.
- Prefer clear user communication over clever flows.
- Keep finance-impacting decisions testable and auditable.

## Anti-Patterns

- Updating local entitlements before provider confirmation without rollback logic.
- Hardcoding plan IDs, prices, feature limits, or billing intervals in multiple layers.
- Ignoring downgrade timing and data-loss consequences.
- Treating webhook delivery as exactly once.
- Letting users trigger duplicate plan changes through repeated submissions.

## Verification

- Test each transition path with provider test mode or mocked provider events.
- Verify idempotency for repeated button clicks and duplicate webhooks.
- Check entitlement state after successful, failed, pending, and reverted transitions.
- Verify invoices, proration, and billing-cycle timing against the stated policy.
- Check audit logs and user-facing confirmation messages.

## Output Contract

Status: done | partial | blocked
Transition policy: [upgrade/downgrade/cancel/resume timing]
Entitlements: [before/after behavior]
Billing effects: [proration, invoice, refund, credit]
Changed: [files or design artifacts]
Verification: [transition tests and provider checks]
Notes: [risks, provider limitations, assumptions]
