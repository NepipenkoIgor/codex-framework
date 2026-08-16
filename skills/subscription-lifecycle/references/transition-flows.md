# Subscription transition policy

Use when upgrade, downgrade, cancellation, resume, trial conversion, quantity, or schedule behavior is not already approved.

For every source state and requested transition define: authorized actor; effective time; preview requirement and expiry; proration, credit, refund, tax and currency rules; payment behavior; entitlement timing; data-loss consequences; reversibility; communication; and failure/reconciliation path. Product and finance owners decide these semantics.

Persist requested, accepted, applied, failed and superseded states, plus pending-payment, scheduled and reverted states only when the approved product/provider policy permits those transitions. Bind every persisted state to idempotency keys and provider object/event generations. A repeated command or webhook must converge without repeating monetary or entitlement effects. Resolve concurrent incompatible transitions explicitly.

Verification covers duplicate clicks/events, stale preview, failed payment, timeout-after-commit, out-of-order webhook, missing webhook plus reconciliation, scheduled change superseded before effective time, cancellation/resume race, and entitlement state after every terminal and pending provider state.

Official Stripe sources for current capability checks:

- `https://docs.stripe.com/api/invoices/create_preview`
- `https://docs.stripe.com/billing/subscriptions/prorations`
- `https://docs.stripe.com/billing/subscriptions/change`
