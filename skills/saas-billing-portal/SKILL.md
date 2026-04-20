---
name: saas-billing-portal
description: Stripe billing portal integration, self-serve plan management, plan comparison UI, proration display, credit balance, seat management, upgrade/downgrade UX.
metadata:
  version: 1.0
  domain: backend
  keywords: [billing portal, stripe portal, plan upgrade, plan downgrade, self-serve billing, proration, credit balance, seat management, plan comparison, subscription management, customer portal, billing UI]
---

# SaaS Billing Portal

## Stripe Customer Portal Setup

```typescript
// One-time portal configuration (run during Stripe setup)
async function configureStripePortal() {
  await stripe.billingPortal.configurations.create({
    business_profile: {
      headline: 'Manage your subscription',
    },
    features: {
      subscription_update: {
        enabled: true,
        default_allowed_updates: ['price', 'quantity', 'promotion_code'],
        proration_behavior: 'always_invoice',
        products: [
          { product: process.env.STRIPE_PRODUCT_ID, prices: [
            process.env.STRIPE_PRICE_FREE,
            process.env.STRIPE_PRICE_PRO,
            process.env.STRIPE_PRICE_ENTERPRISE,
          ]},
        ],
      },
      subscription_cancel: {
        enabled: true,
        mode: 'at_period_end',      // don't cancel immediately
        cancellation_reason: { enabled: true, options: ['too_expensive', 'missing_features', 'switched_service', 'other'] },
      },
      invoice_history: { enabled: true },
      payment_method_update: { enabled: true },
      customer_update: { enabled: true, allowed_updates: ['email', 'name', 'address'] },
    },
  });
}

// Create portal session — redirect user to Stripe-hosted portal
async function createPortalSession(userId: string, returnUrl: string) {
  const user = await db.users.findById(userId);
  if (!user.stripeCustomerId) {
    throw new NotFoundError('No billing account found');
  }

  const session = await stripe.billingPortal.sessions.create({
    customer: user.stripeCustomerId,
    return_url: returnUrl,
  });

  await auditLog({ action: 'billing.portal_opened', actorId: userId });
  return session.url;
}
```

## Plan Comparison Data

```typescript
// Serve plan data from server — never hard-code in frontend
const PLANS = {
  free: {
    name: 'Free',
    price: 0,
    interval: null,
    seats: 1,
    features: ['Up to 1 user', '5 projects', 'Community support'],
    stripePriceId: null,
    limits: { projects: 5, storage_gb: 1, api_calls_per_month: 1000 },
  },
  pro: {
    name: 'Pro',
    price: 49,
    interval: 'month',
    seats: 10,
    features: ['Up to 10 users', 'Unlimited projects', 'Priority support', 'API access'],
    stripePriceId: process.env.STRIPE_PRICE_PRO,
    limits: { projects: -1, storage_gb: 50, api_calls_per_month: 100000 },
  },
  enterprise: {
    name: 'Enterprise',
    price: null, // contact sales
    interval: 'month',
    seats: -1,   // unlimited
    features: ['Unlimited users', 'SSO', 'SLA', 'Dedicated support', 'Custom contracts'],
    stripePriceId: process.env.STRIPE_PRICE_ENTERPRISE,
    limits: { projects: -1, storage_gb: -1, api_calls_per_month: -1 },
  },
} as const;

// GET /api/billing/plans — returns plans with current plan highlighted
async function getPlans(userId: string) {
  const subscription = await getCurrentSubscription(userId);
  return {
    plans: Object.values(PLANS),
    currentPlan: subscription?.plan ?? 'free',
    currentPeriodEnd: subscription?.currentPeriodEnd,
  };
}
```

## Proration Preview

```typescript
// Show user what they'll be charged before confirming plan change
async function previewProration(userId: string, newPriceId: string) {
  const user = await db.users.findById(userId);
  const subscription = await stripe.subscriptions.retrieve(user.stripeSubscriptionId!);

  const proration_date = Math.floor(Date.now() / 1000);
  const preview = await stripe.invoices.retrieveUpcoming({
    customer: user.stripeCustomerId!,
    subscription: user.stripeSubscriptionId!,
    subscription_items: [{ id: subscription.items.data[0].id, price: newPriceId }],
    subscription_proration_date: proration_date,
  });

  return {
    immediateCharge: preview.amount_due / 100,          // charge today (upgrade)
    nextBillingAmount: preview.lines.data
      .filter(l => l.period.start === subscription.current_period_end)
      .reduce((sum, l) => sum + l.amount, 0) / 100,
    currency: preview.currency,
    prorationDate: new Date(proration_date * 1000),
  };
}

// POST /api/billing/upgrade
async function upgradePlan(userId: string, newPriceId: string) {
  const user = await db.users.findById(userId);
  const subscription = await stripe.subscriptions.retrieve(user.stripeSubscriptionId!);

  await stripe.subscriptions.update(user.stripeSubscriptionId!, {
    items: [{ id: subscription.items.data[0].id, price: newPriceId }],
    proration_behavior: 'always_invoice',
    payment_behavior: 'error_if_incomplete', // fail fast if payment fails
  });

  const newPlan = Object.values(PLANS).find(p => p.stripePriceId === newPriceId);
  await db.users.update({ id: userId }, { plan: newPlan?.name.toLowerCase() });
  await auditLog({ action: 'billing.plan_upgraded', actorId: userId, meta: { newPriceId } });
}
```

## Credit Balance Display

```typescript
async function getCreditBalance(userId: string) {
  const user = await db.users.findById(userId);
  if (!user.stripeCustomerId) return { balance: 0, currency: 'usd' };

  const customer = await stripe.customers.retrieve(user.stripeCustomerId) as Stripe.Customer;
  // Stripe balance is stored as negative = credit, positive = debt
  const creditInCents = -customer.balance;
  return {
    balance: creditInCents / 100,
    currency: customer.currency ?? 'usd',
    hasCredit: creditInCents > 0,
  };
}
```

## Seat Management UI

```typescript
// Current seat usage for display
async function getSeatUsage(orgId: string) {
  const org = await db.organizations.findById(orgId);
  const usedSeats = await db.memberships.count({ orgId });
  const plan = PLANS[org.plan as keyof typeof PLANS];

  return {
    used: usedSeats,
    limit: plan.seats === -1 ? null : plan.seats,     // null = unlimited
    canAddMore: plan.seats === -1 || usedSeats < plan.seats,
    upgradeRequired: plan.seats !== -1 && usedSeats >= plan.seats,
  };
}

// Add seats (quantity-based billing)
async function addSeats(orgId: string, additionalSeats: number) {
  const org = await db.organizations.findById(orgId);
  const currentQuantity = await db.memberships.count({ orgId });
  const newQuantity = currentQuantity + additionalSeats;

  const subscription = await stripe.subscriptions.retrieve(org.stripeSubscriptionId!);
  await stripe.subscriptions.update(org.stripeSubscriptionId!, {
    items: [{ id: org.stripeSeatsItemId, quantity: newQuantity }],
    proration_behavior: 'always_invoice',
  });

  await db.organizations.update({ id: orgId }, { seatLimit: newQuantity });
  await auditLog({ action: 'billing.seats_added', orgId, meta: { additionalSeats, newQuantity } });
}
```

## Cancellation Flow

```typescript
// Cancel at period end — not immediately
async function cancelSubscription(userId: string, reason?: string) {
  const user = await db.users.findById(userId);

  await stripe.subscriptions.update(user.stripeSubscriptionId!, {
    cancel_at_period_end: true,
    metadata: { cancellation_reason: reason ?? 'not_specified' },
  });

  const subscription = await stripe.subscriptions.retrieve(user.stripeSubscriptionId!);
  const accessUntil = new Date(subscription.current_period_end * 1000);

  await email.send({ to: user.email, template: 'subscription-cancelled', data: { accessUntil } });
  await auditLog({ action: 'billing.cancelled', actorId: userId, meta: { reason, accessUntil } });

  return { accessUntil, message: `Your plan will remain active until ${accessUntil.toDateString()}` };
}

// Reactivate before period end
async function reactivateSubscription(userId: string) {
  const user = await db.users.findById(userId);
  await stripe.subscriptions.update(user.stripeSubscriptionId!, { cancel_at_period_end: false });
  await auditLog({ action: 'billing.reactivated', actorId: userId });
}
```

## Webhook — Sync Plan After Portal Changes

```typescript
// Handle changes made via Stripe portal (outside your app)
async function handleSubscriptionUpdated(event: Stripe.Event) {
  const subscription = event.data.object as Stripe.Subscription;
  const user = await db.users.findOne({ stripeSubscriptionId: subscription.id });
  if (!user) return;

  const priceId = subscription.items.data[0]?.price.id;
  const plan = Object.values(PLANS).find(p => p.stripePriceId === priceId)?.name.toLowerCase() ?? 'free';

  await db.users.update({ id: user.id }, {
    plan,
    subscriptionStatus: subscription.status,
    currentPeriodEnd: new Date(subscription.current_period_end * 1000),
  });
}
```

## Rules

- Never hard-code plan prices or features in frontend — serve from API
- Always preview proration before upgrade — show user what they'll be charged
- Cancellation is always "at period end" — never immediate (UX + refund complexity)
- Sync plan state from Stripe webhooks — not just from API responses (source of truth is Stripe)
- Use `error_if_incomplete` payment behavior on upgrades — fail fast, don't silently create incomplete subscriptions
- Store `stripeCustomerId`, `stripeSubscriptionId`, `stripeSeatsItemId` on user/org — not fetched from Stripe every request

## Done Criteria

- [ ] Stripe portal session created with return_url — user lands back in app after portal
- [ ] Plan data served from API — not hard-coded in frontend components
- [ ] Proration preview shown before upgrade confirmation (amount_due displayed to user)
- [ ] Cancellation sets `cancel_at_period_end: true` — not immediate
- [ ] `customer.subscription.updated` webhook syncs plan to DB after portal changes
- [ ] Credit balance displayed when positive
- [ ] All billing actions produce audit log entries
