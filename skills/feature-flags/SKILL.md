---
name: feature-flags
description: Implement feature flag systems using LaunchDarkly, Unleash, Statsig, or custom implementations for .NET, Node.js, or frontend frameworks
metadata:
  version: 1.4
  argument-hint: "feature name, flag provider (LaunchDarkly/Unleash/custom), targeting rules, stack"
---

Implement feature flags for $ARGUMENTS with appropriate patterns for the use case.


## Flag Types

| Type | Use case | Example |
|------|----------|---------|
| Boolean (kill switch) | On/off toggle | `enableNewCheckout: true/false` |
| Multivariate (string) | Multiple variants | `checkoutLayout: "single-page" \| "multi-step"` |
| Numeric | Threshold config | `maxUploadSizeMb: 10 \| 50` |
| Experiment | A/B test | `signupFlowVariant: "control" \| "variant-a"` |

## Flag Lifecycle

Created -> Development -> Testing -> Staged Rollout (1%->5%->25%->50%->100%) -> GA -> Cleanup

Every flag needs: key, name, description, type, defaultValue (safe=off), owner, expiresAt, temporary flag.

## Targeting

- **User targeting**: by userId, plan, email domain
- **Percentage rollout**: hash(userId + flagKey) % 100 for deterministic bucket. Monotonic -- only adds users.
- **Environment rules**: different defaults per dev/staging/production
- **Evaluation order**: user overrides -> segment rules -> percentage -> env default -> flag default

```typescript
function isUserInRollout(userId: string, flagKey: string, percentage: number): boolean {
  return murmur3(`${flagKey}:${userId}`) % 100 < percentage;
}
```

## SDK Patterns

### React

```tsx
function CheckoutPage() {
  const showNew = useFlag('enable-new-checkout', false);
  return showNew ? <NewCheckoutFlow /> : <LegacyCheckoutFlow />;
}

// Wrapper component
<FeatureGate flag="enable-ai-assistant" fallback={<ClassicSearch />}>
  <AiAssistant />
</FeatureGate>
```

### Node.js

```typescript
app.post('/api/checkout', flagContext, async (req, res) => {
  const useNew = await flags.getBooleanValue('enable-new-payment-flow', req.flagUser, false);
  return useNew ? newPaymentService.process(req.body) : legacyPaymentService.process(req.body);
});
```

### .NET

```csharp
public async Task<CheckoutResult> ProcessAsync(CheckoutRequest request, CancellationToken ct) {
    var useNew = await _flags.GetBooleanValueAsync("enable-new-checkout",
        new EvaluationContext { UserId = request.UserId }, defaultValue: false, ct);
    return useNew
        ? await _newService.ProcessAsync(request, ct)
        : await _legacyService.ProcessAsync(request, ct);
}
```

## Frontend Framework Integration

### Angular + Feature Flags

- LaunchDarkly: `launchdarkly-js-client-sdk` with injectable service
- Signal-based flag: `readonly showNewUI = signal(false)` updated by LD listener
- `inject()` pattern: `private ld = inject(FeatureFlagService)` in standalone components
- Template: `@if (flags.showNewUI()) { <app-new-dashboard /> } @else { <app-old-dashboard /> }`
- Directive: `*appFeatureFlag="'new-checkout'"` (structural directive wrapping flag check)
- Statsig: `statsig-js` with `checkGate('feature_name')` in service

### Vue / Nuxt + Feature Flags

- LaunchDarkly: `launchdarkly-vue-client-sdk` -- `useLDFlag('show-new-ui')` composable
- Nuxt plugin: `defineNuxtPlugin` initializing LD client, `useState('flags')` for SSR
- Custom composable: `useFeatureFlag(flagName)` returning `computed(() => flags.value[flagName])`
- Template: `<template v-if="showNewUI">` with composable in `<script setup>`
- Statsig: `statsig-vue` or manual `checkGate()` in composable

### SvelteKit + Feature Flags

- LaunchDarkly: `launchdarkly-js-client-sdk` init in `+layout.svelte` `onMount`
- Runes: `let showNewUI = $state(false)` updated by LD `on('change')` listener
- Server-side: `launchdarkly-node-server-sdk` in `+page.server.ts` load function for SSR flags
- Template: `{#if showNewUI}<NewDashboard />{:else}<OldDashboard />{/if}`
- Context: `setContext('flags', flagStore)` for app-wide flag access

### Blazor + Feature Flags

- `Microsoft.FeatureManagement.AspNetCore` NuGet for server-side
- `IFeatureManager` injection: `@inject IFeatureManager FeatureManager`
- Razor: `@if (await FeatureManager.IsEnabledAsync("NewCheckout")) { <NewCheckout /> }`
- `<FeatureTagHelper>` in Razor views
- LaunchDarkly: `LaunchDarkly.ServerSdk` with `LdClient.BoolVariation("flag", context, false)`
- Cascading value: pass flag set down component tree

### Next.js App Router + Feature Flags

- LaunchDarkly: `@launchdarkly/vercel-server-sdk` for edge/server
- Server Component: evaluate flags server-side, pass as props (no client SDK needed)
- Client Component: `launchdarkly-react-client-sdk` with `useFlags()` hook
- Middleware: `middleware.ts` for flag-based routing/redirects
- Statsig: `statsig-node` in Server Components, `statsig-react` in Client Components

### React

- LaunchDarkly: `launchdarkly-react-client-sdk` -- `useFlags()`, `useLDClient()`
- Statsig: `statsig-react` -- `useGate('feature')`, `<StatsigProvider>`
- Custom: Zustand store with `useFeatureFlags()` hook fetching from API

## Custom Storage (DB + Redis)

Schema: `feature_flags` (key, type, default_value, enabled, temporary, owner, expires_at), `flag_targeting_rules` (flag_id, attribute, operator, values, serve_value), `flag_rollouts` (flag_id, percentage, serve_value).

Redis cache: 30s TTL, invalidate on update, publish invalidation event for cross-instance sync.

## OpenFeature Standard

Vendor-neutral API to avoid lock-in. Swap providers without changing evaluation code.

```typescript
await OpenFeature.setProviderAndWait(new LaunchDarklyProvider(sdkKey));
const client = OpenFeature.getClient();
const show = await client.getBooleanValue('show-banner', false, { targetingKey: userId });
```

## Flag Cleanup

When: at 100% for 2+ weeks, experiment concluded, past expiresAt. Checklist: verify 100% all envs, remove from code (keep winning path), remove from flag service, update tests, commit `chore: remove feature flag X`.

Stale detection: query temporary flags past expiry or unchanged for 30+ days. Alert owners weekly, block new flags if team has too many stale ones.

## Testing

```typescript
// Test both paths
it('renders new checkout when flag enabled', () => {
  renderWithFlags({ 'enable-new-checkout': true }, <CheckoutPage />);
  expect(screen.getByTestId('new-checkout')).toBeInTheDocument();
});
it('renders legacy when flag disabled', () => {
  renderWithFlags({ 'enable-new-checkout': false }, <CheckoutPage />);
  expect(screen.getByTestId('legacy-checkout')).toBeInTheDocument();
});
```

Integration: override flags in API tests, clear overrides in afterEach. E2E: use local overrides, never depend on flag service in CI.

## Rollout Patterns

**Canary**: 1% -> 5% -> 10% -> 25% -> 50% -> 100%. Monitor error rate/latency at each stage. Auto-rollback if errors exceed 2x baseline.

**Ring-based**: Ring 0 (internal) -> Ring 1 (beta) -> Ring 2 (10%) -> Ring 3 (50%) -> Ring 4 (100%).

**Kill switch**: instant disable for critical features (payments, signups). Return 503 with retryAfter.

## Experimentation

### Statistical Significance

Running experiments without statistical rigor leads to false conclusions. Every A/B test needs upfront sizing and clear stopping rules.

**Sample size calculator**: determine how many users you need before starting the test. Inputs: baseline conversion rate, minimum detectable effect (MDE), confidence level, statistical power.

```typescript
// Simplified sample size per variant (two-sided test)
function sampleSizePerVariant(
  baselineRate: number,      // e.g., 0.05 (5% conversion)
  mde: number,               // e.g., 0.01 (detect 1% absolute change)
  confidence: number = 0.95, // 1 - alpha
  power: number = 0.80       // 1 - beta
): number {
  const zAlpha = confidence === 0.99 ? 2.576 : confidence === 0.95 ? 1.96 : 1.645;
  const zBeta = power === 0.90 ? 1.282 : power === 0.80 ? 0.842 : 0.674;
  const p1 = baselineRate;
  const p2 = baselineRate + mde;
  const pBar = (p1 + p2) / 2;
  const n = Math.ceil(
    ((zAlpha * Math.sqrt(2 * pBar * (1 - pBar)) + zBeta * Math.sqrt(p1 * (1 - p1) + p2 * (1 - p2))) ** 2)
    / (mde ** 2)
  );
  return n;
}
// sampleSizePerVariant(0.05, 0.01) ≈ 3,800 per variant
```

**Confidence level selection**: 95% is standard for most product experiments. Use 99% for high-stakes changes (pricing, checkout, payment flow). Use 90% for low-risk exploration (copy changes, UI tweaks).

**Minimum detectable effect (MDE)**: the smallest change worth detecting. Smaller MDE = larger sample = longer test. Choose MDE based on business impact -- a 0.5% conversion lift on checkout may be worth millions, justifying a large sample.

**Early stopping rules**: do NOT peek at results daily and stop when p < 0.05 -- this inflates false positive rate to 25-30%. Options:
- **Fixed horizon**: decide sample size upfront, run until reached, analyze once
- **Sequential testing**: use group sequential boundaries (O'Brien-Fleming, Lan-DeMets) that allow periodic looks with controlled error rate
- **Always-valid p-values**: use mixture sequential probability ratio test (mSPRT) for continuous monitoring without inflating error

### Multi-Armed Bandit

Bandits dynamically allocate traffic to better-performing variants during the experiment, reducing opportunity cost compared to fixed 50/50 splits.

**Thompson sampling**: model each variant's conversion rate as a Beta distribution. On each request, sample from each variant's distribution and serve the variant with the highest sample. Naturally shifts traffic toward winners.

```typescript
// Thompson sampling for two variants
function selectVariant(stats: { a: { successes: number; failures: number }; b: { successes: number; failures: number } }): 'a' | 'b' {
  const sampleA = betaSample(stats.a.successes + 1, stats.a.failures + 1);
  const sampleB = betaSample(stats.b.successes + 1, stats.b.failures + 1);
  return sampleA >= sampleB ? 'a' : 'b';
}

// Beta distribution sampling (Joenssen approximation or use a stats library)
function betaSample(alpha: number, beta: number): number {
  // Use jstat, simple-statistics, or server-side stats library
  return jStat.beta.sample(alpha, beta);
}
```

**Epsilon-greedy**: serve the best-performing variant (1-epsilon)% of the time, random variant epsilon% of the time. Simple but less efficient than Thompson sampling. Start with epsilon=0.1 (10% exploration).

**When to prefer bandit over fixed A/B split**:
- Short-lived promotions where you want to maximize conversions during the test
- High opportunity cost of showing the losing variant
- When you care more about cumulative reward than statistical proof
- NOT when you need clean causal inference or statistical significance for stakeholder reporting

**Trade-off**: bandits minimize regret during the experiment but make it harder to reach statistical significance. For important decisions that need clear evidence, use fixed splits. For optimization, use bandits.

### Holdout Groups

Measure the cumulative impact of all feature changes over time by keeping a control group on the old experience.

**Global holdout**: a small percentage (5-10%) of users never see any new features. Compare their metrics against the rest to measure the cumulative impact of all shipped features. Essential for understanding whether the sum of many small changes is positive.

```typescript
function isInGlobalHoldout(userId: string): boolean {
  return murmur3(`global-holdout:${userId}`) % 100 < 5; // 5% holdout
}

function evaluateFlag(userId: string, flagKey: string, defaultValue: boolean): boolean {
  if (isInGlobalHoldout(userId)) return defaultValue; // always gets default (control)
  return normalFlagEvaluation(userId, flagKey);
}
```

**Per-experiment holdout**: each experiment reserves its own control group. After the experiment concludes and rolls out, the per-experiment holdout still sees the old behavior for a measurement window (2-4 weeks) to confirm long-term impact.

**Measuring cumulative impact**: compare global holdout vs treatment on key business metrics (revenue per user, retention, engagement). Run this comparison monthly. If holdout outperforms treatment, your feature velocity may be introducing regressions.

**Rules**: holdout group assignment must be stable (same user always in/out). Holdout percentage should be small enough to not harm business but large enough for statistical power. Document holdout group in the flag service; make it visible to PMs.

### Experiment Lifecycle

Every experiment follows a structured lifecycle to prevent abandoned tests and ensure clean data.

```
Draft → Running → Analyzing → Decided → Archived
```

**Draft**: hypothesis documented, metrics defined, sample size calculated, targeting configured, both code paths implemented and tested. Review by PM + engineer before launch.

**Running**: traffic split active, metrics collecting. Monitor for: sample ratio mismatch (SRM -- actual split deviates from intended), data quality issues, critical metric guardrails (e.g., error rate stays below threshold). Duration: run until sample size reached or max duration (4-6 weeks).

**Analyzing**: experiment reached required sample size. Calculate statistical significance for primary metric. Check secondary metrics and guardrails. Document: effect size, confidence interval, p-value, segment breakdowns.

**Decided**: decision made -- ship (roll out to 100%), rollback (revert to control), or iterate (new variant). Document the decision and rationale. If shipping: schedule flag cleanup.

**Archived**: flag code removed, experiment record preserved for institutional knowledge.

**Auto-stop rules**:
- Stop and rollback if guardrail metric degrades beyond threshold (e.g., error rate >2x baseline)
- Stop and analyze when sample size reached
- Stop and force decision at max duration (prevent indefinite experiments)
- Alert experiment owner when significance reached

**Experiment cleanup**: after decision is made and rolled out for 2+ weeks, remove the flag from code. Keep only the winning code path. Remove from flag service. Update the experiment record with final results and cleanup date.

```typescript
// Experiment metadata schema
interface Experiment {
  key: string;
  hypothesis: string;
  primaryMetric: string;
  secondaryMetrics: string[];
  guardrailMetrics: { metric: string; threshold: number }[];
  sampleSizePerVariant: number;
  status: 'draft' | 'running' | 'analyzing' | 'decided' | 'archived';
  startedAt?: Date;
  decidedAt?: Date;
  decision?: 'ship' | 'rollback' | 'iterate';
  decisionRationale?: string;
  cleanupDate?: Date;
  owner: string;
  maxDurationDays: number;
}
```

## Anti-Patterns

- Nested flags (A controls B controls C) -- impossible to reason about or test
- Flags in data layer -- gate behavior and access, not schema structure
- Non-deterministic rollout -- same user gets different experience on each request
- Evaluating in hot loops -- flag SDK calls without caching add latency on every render

## Output Format

```
Flag:              [key and name]
Type:              [boolean / multivariate / experiment]
Provider:          [LaunchDarkly / Unleash / custom]
Default Value:     [safe default]
Targeting:         [segments, percentage, env rules]
Rollout Plan:      [stages with observation windows]
Kill Switch:       [instant disable approach]
Cleanup Date:      [when to remove]
Testing:           [both paths tested]
```

## Done Criteria

- Flag evaluates correctly for all targeting rules
- Both paths work and are tested
- Rollout deterministic per user (consistent hashing)
- Kill switch disables instantly
- Flag has owner, description, expiry date
- Metrics tracked per variant
- Stale detection alerts owners
- Evaluation fast (<5ms), non-blocking
- Safe default when flag service unavailable
