---
name: payment-integration
description: Implement provider payment collection, checkout, refunds, marketplaces, and payment webhooks with monetary integrity and auditable state transitions. Use when provider plumbing or money movement changes; route product subscription transitions, proration, seats, cancellation/resume, and portal-return behavior to subscription-lifecycle, and do not use for pricing-page UI without a payment contract.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.1
  argument-hint: "provider, payment model, currencies, ledger/source of truth, webhook events, compliance scope"
---

# Payment Integration

This skill owns payment commands, monetary state, fulfillment convergence and reconciliation; generic webhook infrastructure and subscription/product UX remain with their neighboring owners unless explicitly requested.

For Stripe work, read the [Stripe capability guide](references/full-guide.md) only after Stripe is selected and verify idempotency, webhook, payment-method and refund behavior against current official Stripe documentation applicable to the pinned SDK/API/event version. For other providers, use current official documentation while preserving the provider-neutral integrity rules below. Existing manifests, lockfiles, SDK types, runtime engine/deployment constraints, account capabilities, API/event versions, and provider configuration form one compatibility unit and are authority; a provider SDK upgrade is a separate migration. Never persist remembered retention windows, test values, status sets, signature formats or idempotency rules as universal application policy.

## Integrity Rules

- Represent money with integer minor units plus ISO currency; never binary floating point.
- Keep one authoritative payment/subscription state machine and map provider events into it idempotently.
- Use a durable business-operation identity and provider idempotency facility for retryable mutations; scope and reuse keys according to the verified provider contract.
- Calculate authoritative amounts server-side from versioned products/prices and validated entitlements.
- Never store raw card data or weaken the provider-hosted compliance boundary.
- Record external IDs, state transitions, actor/reason, reconciliation status, and monetary totals without leaking secrets.

## Workflow

1. Define money, tax, refund, dispute, settlement, and entitlement contracts before API calls.
2. Inspect repository/provider configuration, models, webhook route, transaction boundary, nearby tests and authorize the exact customer, tenant, resource, amount source, currency, provider account, mode/environment, and callback targets. Stop when provider account, mode or acting authority remains unresolved.
3. Implement the provider boundary and local state transitions with idempotency, transaction protection, durable acceptance, and reconciliation. Serialize or transactionally protect cumulative concurrent refunds; reconcile provider success followed by local failure before another refund proceeds.
4. Verify signed webhooks using raw request bytes and the secret for the exact endpoint; tolerate duplicate/out-of-order delivery and distinct events for the same object transition.
5. Test immediate success and decline, authentication-required, delayed-method success plus delayed rejection/return/expiry, timeout, retry, concurrent duplicate, refund, cancellation, dispute, fulfillment failure, and reconciliation paths. Tamper with the submitted amount independently of authenticated customer/tenant identity and order IDs; prove provider and local state use server-authoritative money and cannot be redirected or disclosed.
6. Verify sandbox/test-mode operations, audit records, alerts, and a concrete compensation/disable/reconciliation plan before any explicitly authorized live write or enablement. Never treat redirect or configuration success alone as proof of payment or entitlement. For refunds and other irreversible provider actions, prove the caller-visible result/status communication as well as provider, ledger and entitlement outcomes.

## Output Contract

- Monetary and state-machine contract
- Idempotency, webhook, reconciliation, and entitlement behavior
- Current official provider documentation pages actually consulted for idempotency, webhook, payment-method, and refund behavior, or an explicit `Not available` when tool access/content is withheld
- Compliance/security boundary, explicitly including provider-hosted collection and confirmation that raw card data is not stored or newly brought into application scope
- Tests and exact provider account/mode evidence, or `Not available`
- Pre-execution rollback/disable, compensation and unknown-outcome reconciliation plan for every authorized live mutation, or the mutation remains blocked
- Exact authorized external mutation and target, provider response, reconciled local/caller-visible outcome, and outstanding settlement/webhook state, with secrets and sensitive payment details excluded
- Unverified live/provider risk and withheld actions
