---
name: saas-starter
description: Opinionated SaaS scaffold — mandatory tables, middleware stack, webhook receiver, directory structure for Next.js + Supabase/Postgres + Stripe. Fast path from 0 to production-ready skeleton.
metadata:
  version: 1.0
  domain: backend
  keywords: [saas starter, saas scaffold, saas boilerplate, saas skeleton, project scaffold, saas setup, saas template, next.js saas, full-stack saas, saas architecture]
---

# SaaS Starter Scaffold

## Mandatory Database Tables

Every SaaS needs these. Create them before building features.

```sql
-- 1. Users (extend your auth provider's user table)
CREATE TABLE users (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email             TEXT UNIQUE NOT NULL,
  name              TEXT,
  avatar_url        TEXT,
  plan              TEXT NOT NULL DEFAULT 'free',
  stripe_customer_id TEXT UNIQUE,
  stripe_subscription_id TEXT,
  subscription_status TEXT DEFAULT 'inactive',
  current_period_end  TIMESTAMPTZ,
  email_verified_at TIMESTAMPTZ,
  welcome_sent_at   TIMESTAMPTZ,
  deleted_at        TIMESTAMPTZ,           -- soft delete for GDPR
  created_at        TIMESTAMPTZ DEFAULT now()
);

-- 2. Organizations (for B2B — skip for B2C)
CREATE TABLE organizations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  plan        TEXT NOT NULL DEFAULT 'free',
  seat_limit  INT,
  owner_id    UUID REFERENCES users(id),
  stripe_customer_id TEXT UNIQUE,
  stripe_subscription_id TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- 3. Memberships (B2B)
CREATE TABLE memberships (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL CHECK (role IN ('owner','admin','member','viewer')),
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE(org_id, user_id)
);

-- 4. Subscriptions log (immutable billing history)
CREATE TABLE subscription_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES users(id),
  org_id        UUID REFERENCES organizations(id),
  event_type    TEXT NOT NULL,             -- created, upgraded, downgraded, cancelled, payment_failed
  from_plan     TEXT,
  to_plan       TEXT,
  stripe_event_id TEXT UNIQUE,
  occurred_at   TIMESTAMPTZ DEFAULT now()
);

-- 5. Audit log (append-only — never UPDATE or DELETE)
CREATE TABLE audit_logs (
  id          BIGSERIAL PRIMARY KEY,
  action      TEXT NOT NULL,
  actor_id    UUID,
  org_id      UUID,
  resource    TEXT,
  resource_id TEXT,
  meta        JSONB,
  ip_address  INET,
  user_agent  TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX audit_logs_actor_id_idx ON audit_logs(actor_id);
CREATE INDEX audit_logs_org_id_idx ON audit_logs(org_id);
CREATE INDEX audit_logs_created_at_idx ON audit_logs(created_at DESC);

-- 6. Feature flag overrides (per-user/org overrides)
CREATE TABLE feature_flag_overrides (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  flag_key    TEXT NOT NULL,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('user','org')),
  entity_id   UUID NOT NULL,
  enabled     BOOLEAN NOT NULL,
  set_by      UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE(flag_key, entity_type, entity_id)
);

-- 7. Webhook endpoints (outbound — for B2B API)
CREATE TABLE webhook_endpoints (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID REFERENCES organizations(id) ON DELETE CASCADE,
  url         TEXT NOT NULL,
  secret      TEXT NOT NULL,             -- hashed HMAC secret
  events      TEXT[] NOT NULL,
  active      BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- 8. Webhook deliveries (delivery tracking + retry)
CREATE TABLE webhook_deliveries (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  endpoint_id     UUID REFERENCES webhook_endpoints(id) ON DELETE CASCADE,
  event_type      TEXT NOT NULL,
  payload         JSONB NOT NULL,
  response_status INT,
  response_body   TEXT,
  attempts        INT DEFAULT 0,
  next_retry_at   TIMESTAMPTZ,
  delivered_at    TIMESTAMPTZ,
  failed_at       TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT now()
);
```

## Directory Structure (Next.js App Router)

```
app/
├── (auth)/
│   ├── login/page.tsx
│   ├── signup/page.tsx
│   └── verify-email/page.tsx
├── (app)/                          # Protected routes
│   ├── layout.tsx                  # Auth + verification gate
│   ├── dashboard/page.tsx
│   ├── settings/
│   │   ├── profile/page.tsx
│   │   ├── billing/page.tsx
│   │   └── team/page.tsx           # B2B: org member management
│   └── [orgSlug]/                  # Multi-tenant routing
│       └── ...
├── api/
│   ├── auth/
│   │   ├── [...nextauth]/route.ts
│   │   ├── verify-email/route.ts
│   │   └── resend-verification/route.ts
│   ├── billing/
│   │   ├── portal/route.ts
│   │   ├── plans/route.ts
│   │   └── webhooks/route.ts       # Stripe webhook receiver
│   ├── orgs/
│   │   ├── route.ts
│   │   └── [orgId]/
│   │       ├── members/route.ts
│   │       └── invitations/route.ts
│   └── webhooks/
│       └── outbound/route.ts       # Deliver webhooks to customers
lib/
├── auth.ts                         # Auth config + session helpers
├── db.ts                           # Prisma/Drizzle client singleton
├── stripe.ts                       # Stripe client singleton
├── redis.ts                        # Redis client singleton
├── email.ts                        # Email provider wrapper
├── audit.ts                        # auditLog() helper
└── plans.ts                        # Plan definitions + limits
proxy.ts                            # Auth guard + tenant resolver (Next.js 16)
```

## Proxy Stack

```typescript
// proxy.ts — runs before matched requests in Next.js 16
import { auth } from '@/auth';
import { NextResponse } from 'next/server';

export default auth(
  function proxy(req) {
    const { pathname } = req.nextUrl;
    const user = req.auth?.user;

    // 1. Verification gate — redirect unverified users
    const publicPaths = ['/login', '/signup', '/verify-email', '/api/auth'];
    const isPublic = publicPaths.some(p => pathname.startsWith(p));

    if (!isPublic && user && !user.emailVerifiedAt) {
      return NextResponse.redirect(new URL('/verify-email?required=true', req.url));
    }

    // 2. Tenant resolver — inject org context from slug
    const orgSlug = req.nextUrl.pathname.split('/')[1];
    if (orgSlug && !orgSlug.startsWith('api') && !orgSlug.startsWith('_')) {
      const response = NextResponse.next();
      response.headers.set('x-org-slug', orgSlug);
      return response;
    }

    return NextResponse.next();
  }
);

export const config = { matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'] };
```

## Stripe Webhook Receiver

```typescript
// app/api/billing/webhooks/route.ts
import Stripe from 'stripe';
import { headers } from 'next/headers';

const HANDLED_EVENTS = new Set([
  'customer.subscription.created',
  'customer.subscription.updated',
  'customer.subscription.deleted',
  'invoice.payment_succeeded',
  'invoice.payment_failed',
  'customer.subscription.trial_will_end',
]);

export async function POST(req: Request) {
  const body = await req.text();
  const signature = headers().get('stripe-signature')!;

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(body, signature, process.env.STRIPE_WEBHOOK_SECRET!);
  } catch {
    return Response.json({ error: 'Invalid signature' }, { status: 400 });
  }

  if (!HANDLED_EVENTS.has(event.type)) {
    return Response.json({ received: true }); // Acknowledge unhandled events
  }

  // Idempotency — skip already-processed events
  const existing = await db.subscriptionEvents.findOne({ stripeEventId: event.id });
  if (existing) return Response.json({ received: true });

  try {
    await handleStripeEvent(event);
    return Response.json({ received: true });
  } catch (err) {
    console.error('Stripe webhook error:', err);
    return Response.json({ error: 'Handler failed' }, { status: 500 }); // Stripe retries on 5xx
  }
}

async function handleStripeEvent(event: Stripe.Event) {
  switch (event.type) {
    case 'customer.subscription.updated':
    case 'customer.subscription.created':
      await syncSubscription(event.data.object as Stripe.Subscription);
      break;
    case 'customer.subscription.deleted':
      await handleSubscriptionCancelled(event.data.object as Stripe.Subscription);
      break;
    case 'invoice.payment_failed':
      await handlePaymentFailed(event.data.object as Stripe.Invoice);
      break;
  }
  await db.subscriptionEvents.create({ stripeEventId: event.id, eventType: event.type });
}
```

## Environment Variables

```bash
# .env.example — copy to .env and fill in
DATABASE_URL=postgresql://...
REDIS_URL=redis://...

NEXTAUTH_SECRET=<32-byte-random>
NEXTAUTH_URL=http://localhost:3000

STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_FREE=price_...
STRIPE_PRICE_PRO=price_...
STRIPE_PRICE_ENTERPRISE=price_...

EMAIL_FROM=noreply@yourapp.com
EMAIL_TOKEN_SECRET=<32-byte-random>

APP_URL=http://localhost:3000
```

## Launch Checklist

```
Auth & Security:
- [ ] Email verification enforced before dashboard access
- [ ] Rate limiting on auth endpoints (login, signup, magic link)
- [ ] CSRF protection on all mutations
- [ ] Secrets in environment variables — not committed

Billing:
- [ ] Stripe webhook signature verification
- [ ] Idempotency on all webhook handlers
- [ ] Subscription sync tested: create, upgrade, cancel, payment failure

Data:
- [ ] All 8 core tables created with correct indexes
- [ ] Audit log append-only (no UPDATE/DELETE permissions on audit_logs)
- [ ] DB backups configured

Operations:
- [ ] Error tracking (Sentry) initialized
- [ ] Structured logging with correlation IDs
- [ ] Health check endpoint (/api/health)
- [ ] Uptime monitoring configured
```

## Done Criteria

- [ ] All 8 core tables exist with correct constraints and indexes
- [ ] Middleware enforces auth + email verification gate on all protected routes
- [ ] Stripe webhook receiver validates signature + handles idempotency
- [ ] Environment variables documented in .env.example — no secrets in code
- [ ] auditLog() helper available globally — used by auth, billing, and membership flows
- [ ] Directory structure follows Next.js App Router conventions with (auth)/(app) groups
