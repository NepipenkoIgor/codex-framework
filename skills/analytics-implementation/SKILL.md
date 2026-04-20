---
name: analytics-implementation
description: Implement product analytics and event tracking using Amplitude, Mixpanel, Segment, PostHog, or custom solutions
metadata:
  version: 1.6
  argument-hint: "analytics platform (GA4/Mixpanel/Amplitude), events to track, user properties, conversion goals"
---

Implement analytics for $ARGUMENTS with appropriate patterns for the use case.


## Tool Integration

- **browser automation**: use browser navigation and snapshot tools to verify event firing in browser DevTools console — always navigate first before any interaction

## Event Taxonomy Design

Format: `Object Action` (past tense) — `Page Viewed`, `Checkout Started`, `Payment Completed`.

Rules:
- Title Case (Amplitude/Mixpanel) or snake_case (PostHog/Segment) — be consistent
- Be specific: `Checkout Started` not `Button Clicked`; group by feature
- Limit to 50-100 events total
- Never include dynamic values in event names: `Product Viewed` not `Widget Pro Viewed`

| Category | Examples | Purpose |
|----------|---------|---------|
| Acquisition | `User Signed Up`, `Invite Accepted` | How users arrive |
| Activation | `Onboarding Completed`, `First Project Created` | First value moment |
| Engagement | `Page Viewed`, `Feature Used` | Ongoing usage |
| Conversion | `Checkout Started`, `Payment Completed` | Revenue events |
| Retention | `Session Started`, `Return Visit` | Coming back |
| Referral | `Invite Sent`, `Referral Completed` | Growth loops |

## Tracking Plan

Single source of truth — typed tracking plan file:

```typescript
export const EVENTS = {
  USER_SIGNED_UP: {
    name: 'User Signed Up',
    properties: {
      method: { type: 'string', required: true, values: ['email', 'google', 'github'] },
      plan: { type: 'string', required: true, values: ['free', 'pro', 'enterprise'] },
    },
  },
  CHECKOUT_STARTED: {
    name: 'Checkout Started',
    properties: {
      planName: { type: 'string', required: true },
      planPrice: { type: 'number', required: true },
      billingCycle: { type: 'string', required: true, values: ['monthly', 'annual'] },
    },
  },
} as const;
```

Property standards: camelCase names, include types and required flag, define enum values, consistent names across events, max 15 properties per event, never include PII without consent.

## SDK Integration

### Analytics Wrapper (Vendor Abstraction)

```typescript
class Analytics {
  private initialized = false;

  init(config: { apiKey: string; userId?: string }) {
    if (this.initialized) return;
    amplitude.init(config.apiKey, { defaultTracking: { sessions: true, pageViews: true } });
    if (config.userId) this.identify(config.userId);
    this.initialized = true;
  }

  track(event: { name: string; properties?: Record<string, unknown> }) {
    if (!this.initialized) return;
    amplitude.track(event.name, { ...event.properties, timestamp: Date.now(), pagePath: window.location.pathname });
  }

  identify(userId: string, traits?: Record<string, unknown>) { /* set user */ }
  reset() { amplitude.reset(); }
}

export const analytics = new Analytics();
```

### React Hook

```tsx
export function useAnalytics() {
  const track = useCallback((eventKey: keyof typeof EVENTS, properties?: Record<string, unknown>) => {
    analytics.track({ name: EVENTS[eventKey].name, properties });
  }, []);
  return { track };
}

function PageViewTracker() {
  const pathname = usePathname();
  const { track } = useAnalytics();
  useEffect(() => { track('PAGE_VIEWED', { pageName: getPageName(pathname) }); }, [pathname]);
  return null;
}
```

### Server-Side (Node.js)

```typescript
const analytics = new SegmentAnalytics({ writeKey: process.env.SEGMENT_WRITE_KEY! });

export function trackServerEvent(userId: string, event: string, properties?: Record<string, unknown>) {
  analytics.track({ userId, event, properties: { ...properties, source: 'server' } });
}

process.on('SIGTERM', async () => { await analytics.closeAndFlush(); process.exit(0); });
```

### Blazor / .NET

Server-side (Segment HTTP or Application Insights):
```csharp
public class AnalyticsService(HttpClient http, IConfiguration config)
{
    public async Task TrackAsync(string userId, string eventName, object? properties = null, CancellationToken ct = default)
    {
        var payload = new { userId, @event = eventName, properties, timestamp = DateTime.UtcNow };
        var request = new HttpRequestMessage(HttpMethod.Post, "https://api.segment.io/v1/track")
        {
            Content = JsonContent.Create(payload),
            Headers = { Authorization = new("Basic", Convert.ToBase64String(Encoding.UTF8.GetBytes($"{config["Segment:WriteKey"]}:"))) },
        };
        await http.SendAsync(request, ct);
    }
}
```

Blazor Server — skip tracking during prerender (check `WebSockets.IsWebSocketRequest`). Blazor WASM — JS interop: `await JS.InvokeVoidAsync("analytics.track", eventName, properties)`.

Application Insights: `builder.Services.AddApplicationInsightsTelemetry()`, inject `TelemetryClient`, call `telemetry.TrackEvent(name, properties, metrics)`.

Page tracking: subscribe `NavigationManager.LocationChanged` in a disposable component; track in `OnAfterRenderAsync(firstRender)` to skip SSR prerender.

MudBlazor: wrap `IDialogService` to track dialog opens; track form submission in `HandleFormSubmit()` after save.

### Angular (Standalone, Signals, inject())

```typescript
@Injectable({ providedIn: 'root' })
export class AnalyticsService {
  private router = inject(Router);

  init() {
    this.router.events
      .pipe(filter((e): e is NavigationEnd => e instanceof NavigationEnd))
      .subscribe((e) => this.page(e.urlAfterRedirects));
  }

  track(event: string, properties?: Record<string, unknown>) { analytics.track({ name: event, properties }); }
  page(path: string) { analytics.track({ name: 'Page Viewed', properties: { pagePath: path } }); }
  identify(userId: string, traits?: Record<string, unknown>) { analytics.identify(userId, traits); }
}

// app.config.ts — init via APP_INITIALIZER
providers: [{ provide: APP_INITIALIZER, useFactory: (svc: AnalyticsService) => () => svc.init(), deps: [AnalyticsService], multi: true }]
```

SSR-safe init: `afterNextRender(() => analytics.init())` in `AppComponent` constructor.

NgZone note: third-party analytics callbacks that update UI state need `NgZone.run()`. Fire-and-forget tracking calls need no zone handling.

GTM: `window.dataLayer.push({ event, ...data })` directly. Or use `angular-google-tag-manager`.

PostHog: init via `APP_INITIALIZER` with `capture_pageview: false`, manual via router events.

### Vue / Nuxt

```typescript
// nuxt.config.ts — nuxt-gtag module
modules: ['nuxt-gtag'], gtag: { id: 'G-XXXXXXXXXX' }
// Usage: const { gtag } = useGtag(); gtag('event', 'begin_checkout', { ... })
```

PostHog plugin (`plugins/posthog.client.ts`): init with `capture_pageview: false`, auto page view in `router.afterEach` via `nextTick(() => posthog.capture('$pageview', ...))`.

Segment composable: lazy singleton `AnalyticsBrowser.load({ writeKey })`, expose `track`, `identify`, `page`.

### SvelteKit

```typescript
// +layout.svelte
import { afterNavigate } from '$app/navigation';
import { browser } from '$app/environment';

onMount(() => { if (browser) analytics.init({ apiKey: PUBLIC_ANALYTICS_KEY }); });
afterNavigate(({ to }) => {
  if (browser && to?.url) analytics.track({ name: 'Page Viewed', properties: { pagePath: to.url.pathname } });
});
```

PostHog: guard all calls with `if (!browser) return`. Init in `onMount`, track in `afterNavigate`.

Server-side events: in `+page.server.ts` load functions via `trackServerEvent(locals.user.id, ...)`.

### Next.js App Router

```tsx
// app/layout.tsx
import { Analytics } from '@vercel/analytics/react';
import { SpeedInsights } from '@vercel/speed-insights/next';
import { GoogleAnalytics } from '@next/third-parties/google';
// Add <Analytics />, <SpeedInsights />, <GoogleAnalytics gaId="G-XXXXXXXXXX" /> in body
```

PostHog: init on `typeof window !== 'undefined'`, use `PostHogProvider` wrapper with `usePostHog()` hook for page view tracking via `usePathname()` + `useSearchParams()` in a `useEffect`.

Edge middleware for server-side page views: fire-and-forget `fetch` to PostHog capture API in `middleware.ts`.

## Cross-Framework Event Taxonomy

Standard events — use consistently across all frameworks and providers:

| Event | When | Required Properties |
|-------|------|---------------------|
| `page_view` | Route change | `page_path`, `page_title` |
| `sign_up` | Account created | `method` (email/google/github) |
| `login` | User authenticated | `method` |
| `purchase` | Payment completed | `value`, `currency`, `plan` |
| `begin_checkout` | Checkout started | `value`, `currency`, `item_count` |
| `add_to_cart` | Item added | `item_name`, `item_price`, `currency` |
| `search` | Search performed | `search_term`, `results_count` |
| `feature_used` | Feature engaged | `feature_name`, `context` |
| `error_occurred` | Error shown to user | `error_type`, `error_message`, `page_path` |
| `invite_sent` | User invited | `invite_method`, `recipient_domain` |

Property rules: `snake_case` for all names | never abbreviate | same name across events | prefix provider-specific: `posthog_session_id`.

User identification (consistent across providers):
```typescript
// Amplitude
amplitude.setUserId(userId); const id = new amplitude.Identify(); Object.entries(traits).forEach(([k,v]) => id.set(k,v)); amplitude.identify(id);
// PostHog
posthog.identify(userId, traits);
// Segment
analytics.identify(userId, traits);
// Mixpanel
mixpanel.identify(userId); mixpanel.people.set(traits);
```

## Segment as Event Router

Single SDK → Segment → multiple destinations (Amplitude, Mixpanel, GA, BigQuery, Braze). Benefits: swap providers without code changes, server-side forwarding for privacy, schema enforcement.

```typescript
analytics.track('Checkout Started', { planName: 'pro', planPrice: 29.99 });
analytics.identify(userId, { email, plan, createdAt, company });
analytics.group(orgId, { name, plan, employeeCount }); // B2B: track per company
```

## User Identification

- Identify on login with server-assigned user ID (not email)
- Set traits: plan, role, company, createdAt
- Reset on logout to prevent cross-user merging
- Anonymous-to-known linking: `analytics.identify(newUserId)` merges pre-signup events (Segment/Amplitude)
- Update traits on plan upgrade or role change

## Group Analytics (B2B)

Associate users with companies via `analytics.group()`. Track feature adoption, conversion, engagement per company. Segment by plan, industry, size.

## Privacy and GDPR

- Initialize analytics ONLY after consent
- Track behavior, not identity — anonymous IDs where possible
- Never track PII without consent; strip IP when not needed, hash emails for matching
- Set data retention policies (90 days to 1 year)
- Implement user data deletion on request (GDPR Art. 17)
- Cookie-less: first-party domain proxy, disable IP/city tracking

```typescript
function initializeAnalytics(consent: ConsentState) {
  if (consent.analytics) analytics.init({ apiKey: process.env.NEXT_PUBLIC_ANALYTICS_KEY });
  if (consent.marketing) { /* marketing pixels */ }
}
```

## Funnel Tracking

```typescript
const CHECKOUT_FUNNEL = [
  'Pricing Page Viewed', 'Plan Selected', 'Checkout Started', 'Payment Info Entered', 'Payment Completed',
] as const;
```

Track each step explicitly. Track abandonment with `beforeunload` at critical steps (step name, time on step, fields completed).

## Event Validation (Development)

```typescript
function validateEvent(eventKey: string, properties: Record<string, unknown>): string[] {
  const def = EVENTS[eventKey];
  if (!def) return [`Unknown event: ${eventKey}`];
  const errors: string[] = [];
  for (const [name, prop] of Object.entries(def.properties)) {
    if (prop.required && properties[name] === undefined) errors.push(`Missing: ${name}`);
    if (properties[name] !== undefined && prop.values && !prop.values.includes(properties[name] as string))
      errors.push(`${name}: invalid value`);
  }
  return errors;
}
```

## Anti-Patterns

- Dynamic event names (`Viewed ${pageName}`) -- creates thousands of unique events that defeat funnel analysis
- No anonymous-to-known user linking -- attribution breaks at the login boundary
- Initializing analytics SDK before consent is given -- GDPR violation regardless of what data is sent
- Client-only tracking for revenue events -- refunds and chargebacks are invisible without server-side signals
- Not resetting identity on logout -- subsequent anonymous sessions are attributed to the previous user

## Output Format

```
Platform:            [Amplitude / Mixpanel / PostHog / Segment / custom]
Event Count:         [number of tracked events]
Tracking Plan:       [location of tracking plan file]
User Identification: [how users are identified and linked]
Group Analytics:     [company/org tracking approach]
Consent:             [consent management approach]
Server-Side:         [which events are tracked server-side]
Validation:          [how events are validated in dev]
```

## Done Criteria

- Tracking plan documented with event names, properties, and triggers
- Analytics wrapper abstracts vendor SDK
- User identification on login, cleared on logout
