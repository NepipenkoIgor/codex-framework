# Stripe capability guide

Load this reference only after the main skill selects Stripe. The repository's installed Stripe SDK/API version, configured products, account capabilities, webhook destination version, and current official documentation are authority. Examples below are invariants and decision points, not copy-paste API signatures.

## Select the Stripe flow

- Prefer a Stripe-hosted Checkout or Portal flow when its current capabilities satisfy the product contract and reduce card-data/compliance surface.
- Use Payment Intents or Elements only when the required payment-method, UX, confirmation, and client/server boundaries justify custom collection.
- Use Connect only after the marketplace funds-flow, merchant-of-record responsibility, charge type, fees, refunds, disputes, negative balances, payouts, tax, onboarding, and jurisdictional constraints are explicitly owned.
- Never infer payment completion from a browser redirect. Use a verified provider event or authoritative API reconciliation, and keep delayed methods pending until their final state is known.

## Server-side creation and idempotency

Authenticate the caller and authorize the exact customer, tenant, cart/order, price, currency, quantity, entitlement, and return URL. Recalculate the amount from server-owned versioned product data. Do not accept a client-provided Stripe customer, price, connected account, fee, amount, or success URL without binding it to the authorized resource.

Create one durable local operation per business intent. Derive the provider idempotency key from that operation identity and attempt policy; reuse it only for an exact retry with the same parameters. Do not assume a remembered key-retention window or that a provider idempotency response replaces local transaction protection and reconciliation. Check the installed SDK request-options shape and current [Stripe idempotency documentation](https://docs.stripe.com/api/idempotent_requests).

## Webhook ingestion

1. Preserve the raw request bytes and read the signature header and secret for the exact endpoint/environment.
2. Verify the signature with the installed official library before parsing or trusting event fields.
3. Persist a receipt/deduplication record and enqueue or transactionally apply the bounded state transition.
4. Handle duplicate delivery and distinct events representing the same object transition. Do not assume event order; retrieve or reconcile authoritative object state when ordering affects correctness.
5. Acknowledge only after durable acceptance. Bound retry/timeout behavior and surface poison or irrecoverable events for reconciliation.
6. Subscribe only to required event types and keep secrets separate across CLI, test, staging, and live endpoints.

The current raw-body, duplicate, asynchronous-processing, and signature rules are documented at https://docs.stripe.com/webhooks.

## State, fulfillment, and reconciliation

Map relevant provider states into an application-owned payment/subscription/refund/dispute state machine. The mapping is product-policy dependent; do not hard-code “past due means full access” or any grace period. Make entitlement transitions idempotent and auditable, and compensate or reconcile when payment succeeds but fulfillment fails.

Reconcile local monetary totals and state against Stripe reports/API on a scheduled and on-demand basis. Track exact, pending, failed, reversed, refunded, disputed, fee, transfer, payout, and settlement amounts as the selected flow requires. Null or missing provider cost/status is unknown, not zero or success.

## Authentication and payment methods

Let the selected Stripe integration handle currently required customer actions. Payment-method capabilities vary by country, currency, account, mode, and API version. Preserve `processing` or another nonterminal state for delayed methods and fulfill only on the business-defined authoritative success event. Verify current behavior at https://docs.stripe.com/payments/payment-methods.

Never log or persist secrets, client secrets, raw card data, or sensitive personal data in metadata. Bind any client secret to the authenticated operation and expose it only to the intended client for the required lifetime.

## Testing and live enablement

Use Stripe sandbox/test mode and current official test helpers for the selected method; do not preserve card numbers or CLI event names here as permanent truth. Cover success, decline, required customer action, delayed success/failure, timeout, same-operation retry, concurrent duplicate request, duplicate/out-of-order event, refund race, cancellation, dispute, partial provider outage, fulfillment failure, and reconciliation repair.

Before live enablement, verify exact account/mode, API/event versions, products/prices, webhook destination and secret, Connect capabilities where applicable, tax/compliance ownership, alerts, reconciliation, kill switch, and least-privilege secret placement. Live behavior remains unverified until an authorized bounded test or real event proves it.
