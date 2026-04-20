---
name: error-tracking
description: Implement error tracking and crash reporting using Sentry, Bugsnag, or custom solutions
metadata:
  version: 1.4
  argument-hint: "tech stack (Node.js/browser/mobile), error tracking service (Sentry/Bugsnag/custom), environment (dev/staging/prod), error categorization strategy"
---

Implement error tracking for $ARGUMENTS with appropriate patterns for the use case.


## SDK Setup

### JavaScript (Browser)

```typescript
Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NODE_ENV,
  release: process.env.NEXT_PUBLIC_APP_VERSION,
  sampleRate: 1.0, tracesSampleRate: 0.2,
  replaysSessionSampleRate: 0.1, replaysOnErrorSampleRate: 1.0,
  integrations: [Sentry.browserTracingIntegration(), Sentry.replayIntegration()],
  ignoreErrors: [
    'ResizeObserver loop limit exceeded',
    'Non-Error promise rejection captured',
    /^Loading chunk \d+ failed/, /^NetworkError/,
  ],
  denyUrls: [/extensions\//i, /^chrome:\/\//i, /^moz-extension:\/\//i],
  beforeSend(event) {
    // Drop extension errors
    if (event.exception?.values?.[0]?.stacktrace?.frames?.some(f => f.filename?.includes('extension'))) return null;
    if (event.user) delete event.user.ip_address; // privacy
    return event;
  },
});
```

### React / Next.js

```typescript
// Error boundary: Sentry.withErrorBoundary(App, { fallback: ({ error, resetError }) => <ErrorFallback /> })
// Component-level: <Sentry.ErrorBoundary fallback={...} beforeCapture={scope => scope.setTag('section', 'x')}>

// next.config.ts
export default withSentryConfig(nextConfig, { org: 'org', project: 'proj', hideSourceMaps: true });

// instrumentation.ts (App Router server init)
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const Sentry = await import('@sentry/nextjs');
    Sentry.init({ dsn: process.env.SENTRY_DSN, tracesSampleRate: 0.2 });
  }
}

// app/global-error.tsx
'use client';
export default function GlobalError({ error, reset }: { error: Error; reset: () => void }) {
  useEffect(() => { Sentry.captureException(error); }, [error]);
  return <html><body><h2>Something went wrong</h2><button onClick={reset}>Try again</button></body></html>;
}
```

### Node.js

```typescript
Sentry.init({
  dsn: process.env.SENTRY_DSN, environment: process.env.NODE_ENV, release: process.env.APP_VERSION,
  tracesSampleRate: 0.2,
  integrations: [Sentry.httpIntegration(), Sentry.expressIntegration(), Sentry.prismaIntegration()],
  beforeSend(event) {
    if (event.request?.headers) { delete event.request.headers['authorization']; delete event.request.headers['cookie']; }
    if (event.request?.data?.password) event.request.data.password = '[REDACTED]';
    return event;
  },
});
app.use(Sentry.expressErrorHandler());
```

Manual capture with context:
```typescript
Sentry.withScope(scope => {
  scope.setUser({ id: req.user.id }); scope.setTag('payment_provider', 'stripe');
  scope.setContext('payment', { amount: req.body.amount, orderId: req.body.orderId });
  scope.setLevel('fatal');
  Sentry.captureException(error);
});
```

### .NET / ASP.NET Core

```csharp
builder.WebHost.UseSentry(o => {
    o.Dsn = config["Sentry:Dsn"]; o.Environment = env.EnvironmentName;
    o.Release = typeof(Program).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;
    o.TracesSampleRate = 0.2; o.SendDefaultPii = false;
    o.SetBeforeSend((e, _) => { e.Request?.Headers?.Remove("Authorization"); return e; });
});
app.UseSentryTracing();
```

## Framework-Specific Patterns

### Angular

```typescript
// main.ts — init before bootstrapApplication()
Sentry.init({ dsn: environment.sentryDsn, integrations: [Sentry.browserTracingIntegration({ instrumentNavigation: true })], tracesSampleRate: 0.2 });
bootstrapApplication(AppComponent, appConfig);

// app.config.ts
providers: [
  { provide: ErrorHandler, useValue: Sentry.createErrorHandler({ showDialog: false }) },
  { provide: Sentry.TraceService, deps: [Router] },
  { provide: APP_INITIALIZER, useFactory: () => () => {}, deps: [Sentry.TraceService], multi: true },
]
```

Custom error handler: unwrap Angular errors, skip `ExpressionChangedAfterItHasBeenChecked`.

### Vue / Nuxt

```typescript
// Vue — @sentry/vue
Sentry.init({ app, dsn: import.meta.env.VITE_SENTRY_DSN,
  integrations: [Sentry.browserTracingIntegration({ router }), Sentry.vueIntegration({ tracingOptions: { trackComponents: true } })],
  tracesSampleRate: 0.2 });
app.config.errorHandler = (err, _, info) => Sentry.captureException(err, { extra: { componentInfo: info } });

// Pinia breadcrumbs plugin
pinia.use(({ store }) => store.$onAction(({ name, store: s, onError }) => {
  Sentry.addBreadcrumb({ category: 'pinia', message: `${s.$id}.${name}`, level: 'info' });
  onError(err => Sentry.captureException(err, { extra: { store: s.$id, action: name } }));
}));

// Nuxt — @sentry/nuxt: add module in nuxt.config.ts; configure via sentry.client.config.ts + sentry.server.config.ts
```

### SvelteKit

```typescript
// vite.config.ts: sentrySvelteKit({ sourceMapsUploadOptions: { org, project, authToken } })
// hooks.client.ts: Sentry.init({ dsn: PUBLIC_SENTRY_DSN }); export const handleError = handleErrorWithSentry();
// hooks.server.ts: Sentry.init({ dsn: env.SENTRY_DSN }); export const handle = sequence(sentryHandle(), ...others); export const handleError = handleErrorWithSentry();
```

### Blazor

```csharp
// Server: builder.WebHost.UseSentry(o => { o.Dsn = ...; }); + optional Application Insights dual setup
// ErrorBoundary: <ErrorBoundary @ref="_eb"><ChildContent>...</ChildContent><ErrorContent Context="ex">@{ SentrySdk.CaptureException(ex); } <button @onclick="() => _eb?.Recover()">Retry</button></ErrorContent></ErrorBoundary>
// JS interop: wrap IJSRuntime calls with try/catch, forward JSException to SentrySdk.CaptureException()
// SignalR circuit: custom CircuitHandler, capture in OnConnectionDownAsync
```

## Source Maps

Always upload and delete from deployed bundle. Tag with release version. Fail CI if upload fails.

```typescript
// vite.config.ts
sentryVitePlugin({ org: 'org', project: 'proj', authToken: process.env.SENTRY_AUTH_TOKEN,
  release: { name: process.env.APP_VERSION },
  sourcemaps: { filesToDeleteAfterUpload: ['./dist/**/*.map'] } })
```

## Breadcrumbs

Automatic: HTTP requests, console.warn/error, DOM interactions, navigation, XHR/fetch.

```typescript
Sentry.addBreadcrumb({ category: 'user.action', message: 'Added item to cart', data: { productId, quantity }, level: 'info' });
```

Keep 20–30 max. Never include PII, passwords, or tokens. Add before critical operations (payment, auth, data mutation).

## Tags, Context, User

```typescript
// Tags (indexed, searchable — low cardinality)
Sentry.setTag('feature_flag', 'new-checkout');
Sentry.setTag('subscription_plan', 'enterprise');

// Context (structured, not indexed — high cardinality)
Sentry.setContext('order', { orderId, itemCount, total, currency });

// User — set on login, clear on logout
Sentry.setUser({ id: user.id, email: user.email, segment: user.plan });
Sentry.setUser(null); // on logout
```

## Error Grouping

Default: by stack trace fingerprint. Customize when different stack traces share a root cause, or same stack from a generic handler:

```typescript
Sentry.withScope(scope => {
  scope.setFingerprint(['payment-error', paymentProvider]); // group by provider
  // or: scope.setFingerprint(['{{ default }}', tenantId]); // default + tenant
  Sentry.captureException(error);
});
```

## Alert Rules

| Alert | Condition | Channel |
|-------|-----------|---------|
| New issue | First occurrence | Slack |
| Regression | Resolved issue reappears | Slack + PagerDuty |
| Spike | 10x baseline in 5 min | PagerDuty |
| Critical | `level: fatal` | PagerDuty (immediate) |
| User impact | >1% of users affected | Slack + email |

Noise reduction: `ignoreErrors` for benign errors, `denyUrls` for extensions, `beforeSend` to drop bots/crawlers. Rate limit alerts: 1 per issue per hour.

## Release Health

```typescript
Sentry.init({ release: 'my-app@2.4.1' }); // or commit SHA
```

| Metric | Healthy |
|--------|---------|
| Crash-free sessions | >99.5% |
| Crash-free users | >99% |

Compare error rates between releases. Auto-detect regressions. Notify on deploy:
```bash
sentry-cli releases deploys $VERSION new --env production
```

## Sample Rates by Environment

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| tracesSampleRate | 1.0 | 0.5 | 0.1–0.2 |
| replaysSessionSampleRate | 0.0 | 0.5 | 0.1 |
| replaysOnErrorSampleRate | 1.0 | 1.0 | 1.0 |
| Send to Sentry | false | true | true |

## Anti-Patterns

- No release tagging -- cannot correlate error spikes with specific deployments
- Same DSN for all environments -- dev noise pollutes production grouping and alerts
- Capturing expected errors (404, validation) as exceptions -- inflates issue counts; use breadcrumbs
- No custom fingerprinting for generic handlers -- one real problem appears as hundreds of issues

## Workflow

1. Install SDK; configure DSN, environment, release, sample rates
2. Set up source map upload in CI build
3. Add user context on authentication
4. Add custom breadcrumbs before critical operations
5. Configure error grouping and fingerprinting
6. Set up alert rules with noise reduction
7. Configure release health tracking
8. Verify errors appear with full context in dashboard

Done: ✓ errors captured with full stack traces ✓ user context on every authenticated error ✓ breadcrumbs before critical operations ✓ alerts for new issues/regressions/spikes ✓ noise filtered ✓ release version tagged ✓ release health shows crash-free rate ✓ sensitive data scrubbed ✓ actionable issue grouping
