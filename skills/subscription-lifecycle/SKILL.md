---
name: subscription-lifecycle
description: Design and implement product subscription transitions, proration previews, scheduled changes, cancellation/resume, entitlement convergence, seat quantities, and hosted portal returns. Use when behavior around an existing subscription changes; do not use for provider plumbing alone or organization-membership authorization.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.1
  argument-hint: "transition, provider/API version, money representation, product policy, entitlement timing"
---

# Subscription Lifecycle

## Workflow

1. Inspect product policy, provider adapter and pinned API/SDK version, subscription and entitlement state machines, exact money representation, webhook verification, reconciliation, seat authority, and tests. Generate project stack context before applying version-specific provider APIs; preserve installed pins and verify matching versioned official documentation. If the preferred preview/update API or field is unavailable, use a documented supported equivalent or treat adoption as a separate migration. For greenfield work, resolve the stable SDK/runtime from official distribution and support data, select and configure an explicit provider API version supported by the target account, SDK and webhook/event contract, check compatibility, generate manifest/provider config plus lockfile, and make all of those artifacts authoritative.
2. Define each transition from product policy: who may request it, effective time, proration/credit/tax behavior, payment behavior, entitlement timing, cancellation/resume semantics, scheduled changes, reversibility, and user-visible pending/failure states. No cancellation or payment mode is universal.
3. Persist an idempotent pending intent before the provider command. Bind actor, account/tenant, current subscription generation, target product/quantity, effective time, provider idempotency key, preview fingerprint/expiry, and allowed return destination.
4. When the installed Stripe capability supports invoice preview, use the current `invoices.createPreview` contract. Capture one `proration_date` and pass that same instant in `subscription_details.proration_date` for preview and the corresponding subscription update. Verify field names from installed types/current official docs; do not revive remembered `retrieveUpcoming` recipes.
5. Keep monetary values in provider minor units or an exact decimal type with explicit currency exponent/rounding. Never use binary floating point or universal `/100`; currencies and provider decimal fields do not all share that assumption.
6. Treat a command response as acceptance, not final local truth. Verified webhooks plus explicit provider reconciliation advance the durable transition using provider event/object versions and idempotent state rules. Handle duplicates, out-of-order delivery, missing events, timeout-after-commit, and payment failure.
7. Derive entitlements from the reconciled subscription/product contract. Membership remains authoritative for active seats; billing quantity converges from that authority through an idempotent outbox/reconciliation boundary.
8. For provider-hosted portals, derive the customer/account server-side and select `return_url` from an environment-specific allowlist. Never accept an arbitrary client URL or treat the return redirect as proof that provider state changed.

When the task mentions a provider-hosted portal, load [provider-hosted portal notes](references/provider-hosted-portals.md) and do not load the transition reference unless transition policy is also unresolved. Otherwise, read [transition flow notes](references/transition-flows.md) only when product transition policy is unresolved.

## Verification

Test duplicate commands, stale preview, price/quantity change after preview, the same proration instant on preview and update—including type-checking both exact request constructions and provider test-mode preview/update results when that authorized environment is available—zero- and non-two-decimal currency handling, payment failure/pending update, timeout after provider commit, duplicate/out-of-order/missing webhooks, scheduled cancellation/resume, two concurrent transitions, seat reconciliation, malicious return URL, and portal return before webhook arrival. Before an upgrade mutation, define compensation/rollback or forward recovery for incorrect and partially applied transitions. Derive user polling/reconciliation attempt and elapsed-time bounds from provider event latency, operation state and product deadline, then expose durable pending/manual resolution after exhaustion.

Assert persisted intent, provider object/invoice, reconciled subscription generation, money/currency, entitlements, and user-visible state. Label provider paths not exercised against the configured test environment.

## Output

Report product policy decisions, authorities, transition state machine, pinned provider capability evidence, preview/update timing, exact money rules, idempotency/reconciliation, allowlisted returns, executed failure tests, unresolved billing/legal/product decisions, and residual or unverified provider/test-mode/deployment boundaries.
