---
name: ab-testing
description: Design A/B testing and experimentation infrastructure — feature flags, traffic splitting, statistical significance, and metrics collection
metadata:
  version: 1.3
  argument-hint: "feature, metric type (conversion/count/continuous), statistical method (fixed-horizon/sequential/bandit), duration/sample size"
---

Implement A/B testing for $ARGUMENTS with appropriate patterns for the use case.


## Tool Integration

- **browser automation**: use browser navigation and snapshot tools to verify UI changes across variants in a live browser — always navigate first before any interaction

## Experiment Design

### Hypothesis Framework

```
If we [change],
then [metric] will [improve/decrease] by [minimum detectable effect],
because [reasoning based on user behavior or data].
```

### Experiment Specification

Define: id, name, hypothesis, owner, status (draft/running/paused/concluded), variants (id, name, weight summing to 100), targeting (segments, platforms, enrollment percentage), primary metric, guardrail metrics, secondary metrics, minimum sample size per variant, minimum/maximum duration (7-90 days), significance level (default 0.05), minimum detectable effect.

### Control and Treatment

- Always include exactly one control group (existing experience)
- 2-4 variants maximum -- more requires larger sample sizes
- Equal traffic split is simplest and most powerful statistically
- Unequal splits (90/10) acceptable for risk reduction but require larger samples

### Sample Size Calculation

Use power analysis: given baseline rate, minimum detectable effect, significance level (0.05), and power (0.80), calculate required visitors per variant. Two-proportion z-test for conversion metrics. Always run at least 7 days to capture weekly seasonality. If traffic is insufficient within 30 days, broaden targeting or choose a different metric.

## User Bucketing

### Deterministic Hashing

```typescript
function assignVariant(userId: string, experimentId: string, variants: { id: string; weight: number }[]): string {
  const hash = createHash('sha256').update(`${experimentId}:${userId}`).digest();
  const bucket = hash.readUInt32BE(0) % 10000;
  let cumulative = 0;
  for (const variant of variants) {
    cumulative += variant.weight * 100;
    if (bucket < cumulative) return variant.id;
  }
  return variants[0].id;
}
```

### Assignment Rules

- Same userId + experimentId always produces the same variant
- Assignment independent across experiments (experiment ID in hash input)
- Never use `Math.random()` -- non-deterministic breaks analysis
- Assign by user ID, not device or session
- For anonymous users: assign by anonymous ID, merge on identification
- Persist assignment in database for reproducible analysis

### Segment Targeting

Check eligibility: platform match, segment inclusion/exclusion, enrollment percentage (hash to check). Users failing eligibility get the control experience without being tracked as experiment participants.

## Statistical Significance

### Frequentist Analysis

For conversion metrics: calculate rates per variant, pooled standard error, z-score, two-tailed p-value, confidence interval on the difference, and statistical power.

| p-value | Interpretation | Action |
|---------|---------------|--------|
| < 0.01 | Very strong evidence | Ship with high confidence |
| 0.01-0.05 | Strong evidence | Ship with confidence |
| 0.05-0.10 | Weak evidence | Consider extending |
| > 0.10 | Insufficient evidence | Do not ship based on this |

### Minimum Detectable Effect (MDE)

The smallest effect worth detecting. Smaller MDE requires larger sample size. Set based on business impact: "a 2% lift in checkout rate is worth the effort."

## Sequential Testing (Peek-Safe)

### The Peeking Problem

Checking results repeatedly inflates false positives. With daily checks over 30 days, a standard p < 0.05 test has ~25% false positive rate.

### Always-Valid P-Values

Use mixture Sequential Probability Ratio Test (mSPRT) or similar to produce p-values safe to check at any time. GrowthBook and Statsig use sequential testing by default. Still recommend 7-day minimum for weekly seasonality.

## Multi-Armed Bandit

### Thompson Sampling

Sample from Beta(successes, failures) distribution for each arm. Pick the arm with the highest sample. Update arm statistics on each outcome. Balances explore/exploit naturally.

### Epsilon-Greedy

With probability epsilon explore (random arm), otherwise exploit (best arm). Epsilon 0.05-0.20 depending on exploration need.

### When to Use

| Scenario | A/B Test | Bandit |
|----------|----------|--------|
| Statistical rigor for decisions | Yes | No |
| Minimize regret during test | No | Yes |
| Short-lived content (headlines) | No | Yes |
| Long-term product decisions | Yes | No |
| Continuous optimization | No | Yes |

## Holdout Groups

### Global Holdout

5-10% of users permanently excluded from all new features. Measures cumulative long-term impact of all product changes. Deterministic by hashing `global-holdout:{userId}`. Review metrics quarterly.

### Feature Holdout

10-20% excluded from a specific feature for 4-12 weeks post-launch. Measures long-term impact of a single feature. Users in global holdout excluded from all experiments.

## Metric Types

### Primary Metric

Single metric the experiment targets. All statistical rigor applies here. One per experiment.

### Guardrail Metrics

Must NOT degrade. Stop the experiment if any guardrail degrades significantly.

| Example | Threshold |
|---------|-----------|
| Page load time P95 | No increase >200ms |
| Error rate | No increase >0.5% |
| Revenue per user | No decrease >2% |
| Support tickets | No increase >10% |

### Metric Categories

| Type | Definition | Example |
|------|-----------|---------|
| Conversion (binary) | Did user do X? | Completed checkout |
| Count | How many times? | Searches per session |
| Continuous | What value? | Revenue per user |
| Ratio | X / Y | Click-through rate |

Use ratio metrics for experiments -- they normalize for traffic differences.

## Integration with Feature Flags

Evaluate experiment flags: check eligibility, assign variant via deterministic hash, track exposure event, return variant value. Ineligible users get control value. Percentage rollout can serve as a lightweight A/B test by tracking on/off metrics.

## Integration with Analytics

### Exposure Events

Fire on every variant render: `{ experimentId, variantId, userId, timestamp }`. Deduplicate per session.

### Conversion Events

Track primary metric events normally -- the analytics platform joins exposure + conversion by userId. Analyze funnel steps per variant. Compare cohorts over time (day 1/7/30 retention, revenue curves).

## Client-Side vs Server-Side

| Aspect | Client-side | Server-side |
|--------|-------------|-------------|
| Render speed | Risk of flicker | No flicker |
| Security | Logic exposed | Logic hidden |
| Best for | UI changes, copy | Pricing, algorithms, APIs |

Anti-flicker for client-side: hide content (max 200ms timeout), resolve assignment, show. Prefer server-side for critical UI elements.

## Platform Integration

### LaunchDarkly

`client.variation('experiment-key', 'control')` -- handles assignment, exposure, and analysis.

### Statsig

`Statsig.getExperiment('experiment-name').get('variant', 'control')` -- sequential testing by default.

### GrowthBook

`gb.getFeatureValue('feature-key', 'control')` with `trackingCallback` for exposure events.

### Amplitude Experiment

`experiment.variant('experiment-name')` with automatic Amplitude analytics integration.

## Custom Implementation

### Assignment Table

```sql
CREATE TABLE experiment_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  experiment_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  variant_id TEXT NOT NULL,
  assigned_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  UNIQUE (experiment_id, user_id)
);
```

### Experiment Service

Check existing assignment -> load experiment spec -> check eligibility -> check global holdout -> assign variant via hash -> persist assignment -> track exposure -> return variant.

### Analysis Queries

Join `experiment_assignments` with conversion events by `user_id` where conversion happened after assignment within the attribution window. Group by `variant_id`. Calculate conversion rate, lift, and statistical significance.

## Avoiding Pitfalls

### P-Hacking

Analyzing many metrics until one shows significance. Mitigation: define primary metric before start, apply Bonferroni correction for multiple metrics, pre-register analysis plan.

### Simpson's Paradox

Aggregated trend reverses when segmented. Mitigation: segment by key dimensions, verify balanced assignment across segments, use stratified analysis if imbalanced.

### Novelty Effect

Users engage more because it is new. Mitigation: run 2-4 weeks minimum, compare week-1 vs week-3 metrics, compare new-user vs existing-user behavior.

### Survivorship Bias

Analyzing only funnel completers ignores drop-offs. Mitigation: use assignment population as denominator (intent-to-treat), track all funnel steps.

### Interaction Effects

Concurrent experiments may interact. Mitigation: track all experiment exposures per user, use mutual exclusion groups for conflicting experiments, platforms like Statsig handle this automatically.

## Reporting

### Decision Framework

| Primary metric | Guardrails | Recommendation |
|---------------|------------|----------------|
| Significant positive | All pass | Ship |
| Significant positive | Any regressed | Iterate |
| Not significant | All pass | Extend or abandon |
| Not significant | Any regressed | Abandon |
| Significant negative | Any | Abandon |

### Rollout After Decision

1. Verify treatment wins on primary metric (p < 0.05)
2. Verify no guardrail regressions
3. Check segment-level results
4. Roll out gradually: 25% -> 50% -> 100% over 1-2 weeks
5. Monitor guardrails during rollout
6. Clean up experiment code after full rollout

## Anti-Patterns

- Peeking with standard statistics instead of sequential methods -- inflated false positives
- `Math.random()` for assignment -- non-deterministic, different variant across sessions for same user
- P-hacking: testing many metrics until one hits significance
- Ignoring novelty effect -- concluding within days of launch
- No global holdout -- no way to measure long-term impact
- Mutually interacting experiments running simultaneously without awareness

## Output Format

```
Experiment:        [name and hypothesis]
Platform:          [LaunchDarkly / Statsig / GrowthBook / custom]
Variants:          [control + treatment(s) with traffic split]
Targeting:         [segments, platforms, enrollment %]
Primary Metric:    [metric name, type, MDE]
Guardrail Metrics: [list with thresholds]
Sample Size:       [per variant, estimated duration]
Assignment:        [deterministic hash, client/server-side]
Statistical Method:[fixed-horizon / sequential / bandit]
Reporting:         [automated report structure]
Decision Framework:[ship / iterate / abandon criteria]
```

## Done Criteria

- Experiment has a hypothesis with defined primary and guardrail metrics
- Sample size calculated with power analysis; duration planned for weekly seasonality
- Assignment is deterministic, consistent, and independent across experiments
