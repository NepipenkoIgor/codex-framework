---
name: saas-org-membership
description: Implement organization membership, invitations, policy-driven authorization, seat reservation and billing reconciliation, owner invariants, and durable organization deletion. Use for shared-workspace membership; do not use for generic RBAC or subscription presentation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "membership policy, owner invariant, invitation flow, seat authority, deletion dependencies"
---

# SaaS Organization Membership

## Workflow

1. Inspect identity, organization boundary, current membership/authorization policy, owner invariant, subscription and seat authority, audit/outbox contracts, external resources, manifests, migrations, and tests. Call each artifact inspected only after it was supplied or opened; keep existence and planned inspection separate, and never infer manifest/lockfile inspection from general repository context. Do not replace policy with a fixed role ladder.
2. Define subject, tenant, action, resource, membership state, role/capability/attribute conditions, ownership rule, separation-of-duty constraints, and who may change each field. Support policy-driven roles, capabilities or ABAC; fixed `owner/admin/member/viewer` is only valid when the product explicitly defines it.
3. Define the owner invariant from policy. Some products require one owner, multiple owners, or no owner role at all. Enforce the chosen minimum/maximum atomically for active organizations and decide who may transfer, add, remove, or leave.
4. Store invitation bearer tokens only as keyed hashes; bind invite to organization, normalized recipient identity, intended policy attributes, issuer, generation, expiry from policy, and single-use state. Acceptance reauthenticates the recipient and transactionally consumes the invite, checks policy, reserves a seat, creates/updates membership, and writes outbox/audit intent.
5. Make seat reservation concurrent-safe against active memberships, pending accepted operations, plan changes, removals, and two invitations for the final seat. Membership is the declared seat authority; billing quantity converges from versioned snapshots/events and reconciliation, never from unverified webhook order.
6. Make role/attribute changes, owner transitions, leave/removal, invite revocation, and organization deletion idempotent and concurrency-safe. Recheck actor authority and target state inside the transaction; prevent self-approval/escalation and stale-session access.
7. Start deletion by atomically revoking access and persisting a tombstoned workflow. Idempotently cancel/reconcile billing, delete or retain external resources per policy, record every step, and finalize only after required evidence. Before automated retry, derive a concrete attempts or elapsed-time ceiling from the deletion SLO/operation deadline, provider limits, idempotency and ambiguous-outcome reconciliation, queue visibility/lease, downstream capacity, and observed recovery behavior; unresolved inputs block retry enablement. Do not delete independent user identities.

## Required Race Tests

- Two invite acceptances compete for the final seat; at most the policy-allowed count commits and billing converges.
- Invite is revoked, recipient identity changes, or membership already exists while acceptance runs.
- Last required owner leaves/removes self while another owner change executes; the invariant remains valid for policies with one or multiple required owners.
- Plan quantity changes while a member joins/leaves and webhook/outbox events arrive duplicate or out of order.
- Deletion races with invitation acceptance, role change, billing webhook, and external cleanup failure; access remains revoked and recovery resumes safely.

## Verification and Output

Test the authorization matrix with multiple tenants and policy attributes, transaction isolation under races, token secrecy, idempotent replay, stale sessions, audit completeness, billing reconciliation, and each deletion dependency failure. Assert persisted and external outcomes, not only API status.

Report policy and owner invariants, invitation/seat transactions, billing authority and convergence, authorization checks, deletion state machine, idempotency keys, executed race/failure evidence, and unresolved product/billing policy.
