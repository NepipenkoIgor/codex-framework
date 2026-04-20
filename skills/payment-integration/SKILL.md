---
name: payment-integration
description: Implement payment flows with Stripe including Checkout Sessions, subscriptions, webhooks, Connect platforms, refund flows, idempotency keys, test mode, and SCA/3DS handling
metadata:
  version: 1.8
  argument-hint: "payment type (checkout/subscription/connect), currency, webhook events, test/live mode"
---

Implement $ARGUMENTS using Stripe as the payment platform.

## Tool Integration

- **Type diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Tool Integration

When structured Stripe tools are available:
- **stripe:explain-error** — decode Stripe error codes during debugging
- **stripe:test-cards** — get test card numbers for 3DS, declines, specific brands
- **stripe:stripe-best-practices** — check best practices before implementing new flows
- Check up-to-date Stripe SDK docs with the available structured tools before using unfamiliar API methods

## Checkout Sessions

```typescript
// One-time payment
const session = await stripe.checkout.sessions.create({
  mode: 'payment',
  customer: customerId,
  line_items: [{ price: priceId, quantity: 1 }],
  success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}`,
  cancel_url: cancelUrl,
  metadata,
  payment_intent_data: { metadata }, // propagate to PaymentIntent for webhooks
});

// Subscription
const session = await stripe.checkout.sessions.create({
  mode: 'subscription',
  customer: customerId,
  line_items: [{ price: priceId, quantity: 1 }],
  subscription_data: { trial_period_days: trialDays, metadata: { userId: customerId } },
  success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}`,
  cancel_url: cancelUrl,
  allow_promotion_codes: true,
  billing_address_collection: 'auto',
  tax_id_collection: { enabled: true },
});
```

Rules: always use Stripe-hosted checkout for PCI compliance | set `metadata` on both session and payment_intent/subscription | verify completion via webhook (`checkout.session.completed`), NOT success redirect | use `customer` to link to existing Stripe customers.

## Subscriptions

Lifecycle: `Trial → Active → Past Due → Canceled` | `Past Due → Unpaid` (after retry exhaustion)

| Stripe Status | App State | User Experience |
|---------------|-----------|----------------|
| `trialing` | Active (trial) | Full access, show trial remaining |
| `active` | Active | Full access |
| `past_due` | Grace period | Full access + payment warning |
| `unpaid` | Restricted | Limited access, update payment prompt |
| `canceled` | Canceled | No access, resubscribe option |
| `incomplete` | Pending | Waiting for 3DS confirmation |

```typescript
// Upgrade/downgrade
await stripe.subscriptions.update(subId, {
  items: [{ id: currentItemId, price: newPriceId }],
  proration_behavior: 'create_prorations',
  payment_behavior: 'default_incomplete', // handle SCA
});

// Cancel at period end (preferred)
await stripe.subscriptions.update(subId, { cancel_at_period_end: true });

// Customer Portal
const session = await stripe.billingPortal.sessions.create({ customer: customerId, return_url: returnUrl });
```

## Webhooks

```typescript
export async function POST(req: Request) {
  const body = await req.text();
  const sig = req.headers.get('stripe-signature')!;
  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(body, sig, process.env.STRIPE_WEBHOOK_SECRET!);
  } catch { return new Response('Invalid signature', { status: 400 }); }

  switch (event.type) {
    case 'checkout.session.completed': await handleCheckoutCompleted(event.data.object); break;
    case 'customer.subscription.updated': await handleSubscriptionUpdated(event.data.object); break;
    case 'customer.subscription.deleted': await handleSubscriptionDeleted(event.data.object); break;
    case 'invoice.payment_succeeded': await handleInvoicePaid(event.data.object); break;
    case 'invoice.payment_failed': await handlePaymentFailed(event.data.object); break;
    case 'charge.refunded': await handleRefund(event.data.object); break;
  }
  return new Response('OK', { status: 200 });
}
```

For .NET: `EventUtility.ConstructEvent(json, signature, webhookSecret)`, switch on `stripeEvent.Type`.

| Event | Action |
|-------|--------|
| `checkout.session.completed` | Provision access, fulfill order |
| `customer.subscription.updated` | Update plan, handle downgrades |
| `customer.subscription.deleted` | Revoke access |
| `invoice.payment_succeeded` | Record payment, send receipt |
| `invoice.payment_failed` | Notify user, start grace period |
| `charge.refunded` | Adjust access, update records |

Webhook rules: ALWAYS verify signature | return 200 quickly, queue heavy processing | handle idempotently (check session/event ID) | handle out-of-order events | log every event with ID, type, result.

Idempotency for webhooks:
```typescript
async function handleCheckoutCompleted(session: Stripe.Checkout.Session) {
  const existing = await db.orders.findFirst({ where: { stripeSessionId: session.id } });
  if (existing) return;
  await db.orders.create({ data: { stripeSessionId: session.id, /* ... */ } });
  await provisionAccess(session.metadata?.userId, session.metadata?.planId);
}
```

## Idempotency Keys

- Every Stripe mutation must include an idempotency key
- Use deterministic keys: `payment-{orderId}`, `refund-{paymentIntentId}`
- Keys expire after 24h in Stripe; same key = same response (prevents duplicates on retry)

```typescript
await stripe.paymentIntents.create(
  { amount, currency, metadata: { orderId } },
  { idempotencyKey: `payment-${orderId}` }
);
```

## SCA / 3D Secure

- European payments (PSD2) require Strong Customer Authentication
- Use Stripe Checkout or Payment Element for automatic 3DS handling
- Custom flows: handle `requires_action`, use `confirmCardPayment(clientSecret)` on client
- Subscriptions: set `payment_behavior: 'default_incomplete'`
- Off-session renewals: `off_session: true`, handle `requires_action` via email

## Refunds

```typescript
await stripe.refunds.create(
  { payment_intent: piId, metadata: { reason } },           // full
  { idempotencyKey: `refund-full-${piId}` }
);
await stripe.refunds.create(
  { payment_intent: piId, amount: amountInCents, metadata: { reason } }, // partial
  { idempotencyKey: `refund-partial-${piId}-${amountInCents}` }
);
```

Rules: always use idempotency keys | track status in DB | handle `charge.refunded` webhook | validate total refunded ≤ original charge | 5-10 business days on statement.

## Stripe Connect (Marketplace)

| Type | Onboarding | Best for |
|------|------------|----------|
| Standard | Stripe-hosted | Existing businesses |
| Express | Stripe-hosted, simplified | Marketplaces |
| Custom | Platform-built | Full white-label |

```typescript
// Create Express account + onboarding link
const account = await stripe.accounts.create({
  type: 'express', email,
  capabilities: { card_payments: { requested: true }, transfers: { requested: true } },
});
const link = await stripe.accountLinks.create({
  account: account.id, type: 'account_onboarding',
  refresh_url: `${baseUrl}/connect/refresh`, return_url: `${baseUrl}/connect/complete`,
});

// Payment with platform fee
const session = await stripe.checkout.sessions.create({
  mode: 'payment', customer: customerId,
  line_items: [{ price_data: { currency, product_data: { name: 'Service' }, unit_amount: amount }, quantity: 1 }],
  payment_intent_data: { application_fee_amount: platformFee, transfer_data: { destination: connectedAccountId } },
  success_url, cancel_url,
});
```

Connect webhooks: `account.updated` (onboarding), `payout.paid`, `payout.failed`, `transfer.created`.

## Customer Management

- Create Stripe customer on signup, store `stripeCustomerId` in DB
- Link via `metadata.userId` | keep billing email in sync | never store card details

## Error Handling

| Error Type | Action |
|------------|--------|
| `StripeCardError` | Show friendly message to user |
| `StripeRateLimitError` | Retry with backoff |
| `StripeInvalidRequestError` | Log, fix in code |
| `StripeAuthenticationError` | Alert ops |

Never expose raw Stripe error details to users.

## Test Mode

| Card | Scenario |
|------|----------|
| `4242 4242 4242 4242` | Success |
| `4000 0025 0000 3155` | Requires 3DS |
| `4000 0000 0000 9995` | Decline |
| `4000 0000 0000 3220` | 3DS success |

```bash
stripe listen --forward-to localhost:3000/api/webhooks/stripe
stripe trigger checkout.session.completed
```

## Framework-Specific Patterns

### Next.js App Router

```typescript
// app/actions/checkout.ts — Server Action, no API route needed
'use server'
export async function createCheckout(priceId: string) {
  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${process.env.NEXT_PUBLIC_APP_URL}/billing?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.NEXT_PUBLIC_APP_URL}/pricing`,
  })
  redirect(session.url!)
}
```

Webhook handler in `app/api/webhooks/stripe/route.ts` — use `await headers()` to get `stripe-signature`.

Client-side Payment Element:
```tsx
'use client'
function CheckoutForm() {
  const stripe = useStripe(); const elements = useElements(); const [loading, setLoading] = useState(false);
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault(); if (!stripe || !elements) return; setLoading(true);
    const { error } = await stripe.confirmPayment({ elements, confirmParams: { return_url: `${window.location.origin}/payment/success` } });
    if (error) { /* show error.message */ } setLoading(false);
  }
  return <form onSubmit={handleSubmit}><PaymentElement /><button type="submit" disabled={!stripe || loading}>{loading ? 'Processing...' : 'Pay'}</button></form>;
}
export function PaymentWrapper({ clientSecret }: { clientSecret: string }) {
  return <Elements stripe={loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)} options={{ clientSecret }}><CheckoutForm /></Elements>;
}
```

Idempotency with Server Actions: store `crypto.randomUUID()` in a hidden form field via `useRef`.

Customer Portal:
```typescript
// app/actions/billing.ts
'use server'
export async function createPortalSession(customerId: string) {
  const session = await stripe.billingPortal.sessions.create({ customer: customerId, return_url: `${process.env.NEXT_PUBLIC_APP_URL}/billing` })
  redirect(session.url)
}
```

### Angular

```typescript
// services/stripe.service.ts
@Injectable({ providedIn: 'root' })
export class StripeService {
  private stripePromise = loadStripe(environment.stripePublishableKey);
  readonly loading = signal(false);
  async redirectToCheckout(sessionId: string) {
    const stripe = await this.stripePromise;
    if (!stripe) throw new Error('Stripe failed to load');
    const { error } = await stripe.redirectToCheckout({ sessionId });
    if (error) throw error;
  }
}
```

Use `ngx-stripe` + `provideNgxStripe(environment.stripePublishableKey)` for Stripe Elements. Component uses `StripePaymentElementComponent` with `viewChild`, calls `stripe.confirmPayment({ elements, confirmParams })`.

Webhook backend: use `express.raw({ type: 'application/json' })` middleware on the webhook route to preserve raw body for signature verification.

### Nuxt 3

```typescript
// server/api/webhooks/stripe.post.ts
export default defineEventHandler(async (event) => {
  const body = await readRawBody(event);
  if (!body) throw createError({ statusCode: 400 });
  const sig = getHeader(event, 'stripe-signature')!;
  let stripeEvent: Stripe.Event;
  try { stripeEvent = stripe.webhooks.constructEvent(body, sig, useRuntimeConfig().stripeWebhookSecret); }
  catch { throw createError({ statusCode: 400, statusMessage: 'Invalid signature' }); }
  switch (stripeEvent.type) {
    case 'checkout.session.completed': await handleCheckoutCompleted(stripeEvent.data.object); break;
  }
  return { received: true };
});
```

Client composable: lazy `loadStripe()` singleton in `useStripe()`, expose `redirectToCheckout(sessionId)` + `loading` ref.

### SvelteKit

```typescript
// src/routes/api/webhooks/stripe/+server.ts
export const POST: RequestHandler = async ({ request }) => {
  const body = await request.text();
  const sig = request.headers.get('stripe-signature')!;
  let event: Stripe.Event;
  try { event = stripe.webhooks.constructEvent(body, sig, STRIPE_WEBHOOK_SECRET); }
  catch { return new Response('Invalid signature', { status: 400 }); }
  switch (event.type) {
    case 'checkout.session.completed': await handleCheckoutCompleted(event.data.object); break;
  }
  return new Response('OK', { status: 200 });
};
```

Checkout via form action in `+page.server.ts`: read `priceId` from `formData()`, create session, `redirect(303, session.url!)`.

Client-side Elements: load in `onMount()` (browser-only), mount `elements.create('payment')` to a bound `<div>`, call `stripe.confirmPayment()` on submit.

### Blazor (.NET 8+)

```csharp
// Services/StripeService.cs
public class StripeService(IConfiguration config)
{
    private readonly SessionService _sessionService = new();
    public async Task<string> CreateCheckoutSessionAsync(string priceId, string customerId, CancellationToken ct)
    {
        var options = new SessionCreateOptions {
            Mode = "subscription", Customer = customerId,
            LineItems = [new SessionLineItemOptions { Price = priceId, Quantity = 1 }],
            SuccessUrl = "https://app.example.com/billing?session_id={CHECKOUT_SESSION_ID}",
            CancelUrl = "https://app.example.com/pricing",
        };
        var session = await _sessionService.CreateAsync(options, cancellationToken: ct);
        return session.Url;
    }
}
```

Minimal API webhook: `EventUtility.ConstructEvent(json, sig, config["Stripe:WebhookSecret"])`, switch on `stripeEvent.Type`.

JS interop for Elements: wrap `<div id="payment-element">` with `OnAfterRenderAsync` init via `JS.InvokeVoidAsync("stripeInterop.mountPaymentElement", ClientSecret)`. JS side stores `stripe` + `elements` on `window.stripeInterop`, exposes `mountPaymentElement(clientSecret)` and `confirmPayment(returnUrl)`.

SignalR for real-time status: webhook handler pushes subscription updates via `IHubContext<PaymentHub>` to the user's group.

### Vue (non-Nuxt)

Provide Stripe via `app.provide(STRIPE_KEY, loadStripe(key))`. Composable `useStripe()` injects the promise, exposes `initialize(clientSecret)`, `confirmPayment(returnUrl)`, `loading` ref.

## Testing Stripe

### Local Webhook Testing

```bash
stripe listen --forward-to localhost:3000/api/webhooks/stripe
stripe trigger checkout.session.completed
stripe trigger customer.subscription.updated
stripe trigger invoice.payment_failed
stripe trigger charge.refunded
```

The CLI outputs a `whsec_...` secret — use as `STRIPE_WEBHOOK_SECRET` in development.

### Test Cards

| Card Number | Scenario |
|-------------|----------|
| `4242424242424242` | Successful payment |
| `4000000000003220` | 3DS required (succeeds) |
| `4000000000000002` | Card declined |
| `4000002500003155` | 3DS on every transaction |
| `4000000000009995` | Insufficient funds |

Any future expiry, any 3-digit CVC, any postal code.

### CI Mock

```yaml
services:
  stripe-mock:
    image: stripe/stripe-mock:latest
    ports: ["12111:12111", "12112:12112"]
```

```typescript
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { host: 'localhost', port: 12111, protocol: 'http' });
```

## Anti-Patterns

- Processing payments from success page redirect instead of webhooks -- redirect is unreliable
- Missing webhook signature verification -- any caller can fake events
- Missing idempotency keys on mutations -- network retries create duplicate charges
- Not handling 3DS/SCA for European payments -- transactions silently declined
- Checking subscription status only on login -- misses mid-session payment failures

## Output Format

```
Flow:             [checkout / subscription / marketplace / refund]
Integration:      [Checkout Sessions / Payment Intents / Customer Portal]
Webhooks:         [events handled with verification]
Idempotency:      [key strategy for mutations]
SCA/3DS:          [handling approach]
Error Handling:   [error types handled]
Test Mode:        [test cards and CLI setup]
Connect:          [marketplace account type, if applicable]
```

## Done Criteria

- Checkout works end-to-end with success and decline test cards
- Webhooks verify signatures and handle events idempotently
- 3DS/SCA handled for European payments
- Test mode works with Stripe CLI
