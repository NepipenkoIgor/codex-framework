---
name: technical-debt
description: Quantify, prioritize, and manage technical debt including debt identification, impact scoring, paydown planning, cost-benefit analysis, and team alignment
metadata:
  version: 1.4
  argument-hint: "codebase scope, debt areas (code/infra/testing), team capacity, repayment timeline"
---

Assess and manage technical debt for $ARGUMENTS.


## Debt Taxonomy

**Code debt:** duplicated logic (same logic across files, bug fixes must apply multiple places) | dead code (unused functions, unreachable branches) | god classes >500 lines/>10 public methods | primitive obsession (strings/numbers instead of domain types) | deep nesting >3 levels (cyclomatic complexity) | poor naming (ambiguous/misleading) | missing abstractions (repeated patterns without shared interface).

**Architecture debt:** tight coupling (modules depend on internals, changes cascade) | missing boundaries (no clear feature/layer separation, spaghetti imports, circular deps) | wrong abstraction (premature/incorrect, every modification fights the abstraction) | monolithic structure | outdated patterns (deprecated APIs) | leaky abstractions (internals exposed in public APIs).

**Test debt:** low coverage on critical paths | brittle tests (break on unrelated changes, CI unreliable) | missing integration tests (unit tests pass, features fail) | slow test suite >10min | test duplication | no E2E for critical paths.

**Documentation debt:** missing API docs | stale docs (don't match behavior) | missing ADRs (repeated discussions, context loss) | no onboarding guide (extended onboarding time).

**Infrastructure debt:** manual deployments | no monitoring (blind to production issues) | outdated/EOL dependencies (security vulnerabilities) | no IaC (config drift) | missing backups.

## Identification Techniques

### Automated Detection

```bash
npx complexity-report --format json src/          # cyclomatic complexity
npx jscpd --min-lines 5 --min-tokens 50 src/      # duplicate code
npx madge --circular --warning src/               # circular dependencies
npm outdated --json                               # outdated deps
npm audit --json                                  # vulnerabilities
npx vitest run --coverage --reporter=json         # coverage gaps
git log --since="6 months ago" --name-only --pretty=format: | sort | uniq -c | sort -rn | head -30  # churn hotspots
grep -r "TODO\|FIXME\|HACK\|XXX" src/            # acknowledged debt
```

### Manual Detection Signals

High churn files (unstable design) | long PR review times (complex code) | recurring bugs in same area (fragile code) | TODO/FIXME comments | long onboarding time (poor docs) | slow feature delivery in specific area | frequent merge conflicts (tight coupling).

### Developer Survey (quarterly)

1. Which area do you dread working in? Why?
2. What takes longer than it should? What do you work around?
3. What would you fix if you had a free sprint?
4. What breaks unexpectedly requiring manual intervention?
5. Where do you copy-paste instead of reuse?

Score responses by frequency and severity. Top items become debt candidates.

## Impact Scoring Matrix

```
Impact Score = Frequency × Cost × Risk

Frequency: how often the area is modified (1-5)
  1=<1x/quarter | 3=1-3x/month | 5=weekly+

Cost: extra time per modification due to debt (1-5)
  1=minutes | 3=hours | 5=days

Risk: probability and severity of failure (1-5)
  1=cosmetic | 3=feature degradation | 5=data loss/security/outage
```

Example scores: Monolithic OrderService 800 lines → 5×4×3=60 (High) | No auth token rotation → 1×2×5=10 (Medium, security minimum) | Duplicated validation → 4×3×2=24 (Medium) | Missing API docs → 2×3×1=6 (Low).

Rules: security debt = minimum Medium regardless of score; debt blocking a planned feature gets priority boost.

## Quantification Methods

**Time Tax:** `(Actual time − Estimated debt-free time) / Actual time × 100%`. Track per area across features; consistently high time tax = priority paydown target.

**Failure Rate Correlation:** `Bugs in area / Total bugs × 100%`. 10% of code, 40% of bugs = 4x bug multiplier.

**Feature Velocity Impact:** measure features/sprint before and after paydown. `ROI = (Velocity gain × Remaining sprints) / Paydown cost in sprints`.

**Cost of Delay:** `Weekly savings = hours saved/week × devs`. `Break-even = one-time fix cost / weekly savings`. Example: 2 hrs/week × 4 devs = 8 hrs/week; 40hr fix = 5-week break-even, 860% 12-month ROI.

## Prioritization Frameworks

**RICE Score:** `(Reach × Impact × Confidence) / Effort`. Reach = devs/features affected per quarter; Impact = time/quality improvement per person (0.25/0.5/1/2/3); Confidence = 0.5/0.8/1.0; Effort = person-weeks.

**Interest Rate Metaphor:** Principal = one-time fix cost; Interest = ongoing monthly cost. `Break-even = Principal / Monthly Interest`. High-interest debt (high ongoing cost relative to fix cost) paid down first.

Priority Matrix: High Interest + Low Fix Cost = fix immediately | High Interest + High Fix Cost = plan next sprint | Low Interest + Low Fix Cost = fix opportunistically | Low Interest + High Fix Cost = defer unless blocking.

## Paydown Strategies

**Boy Scout Rule (continuous):** leave code better than found; 15-30min per PR for small adjacent improvements. Effective for naming, dead code, types; not architectural changes.

**Dedicated Sprints (periodic):** 1 sprint per quarter or 1 week per month; select from debt register; define "done" criteria; track velocity improvement before/after.

**Tech Debt Budget (continuous):** 15-20% of sprint capacity for debt items. Below 10% = debt grows faster than paid; above 30% = feature delivery suffers. Increase allocation when debt trend is increasing.

**Strangler Fig (large rewrites):** build new alongside old → route new traffic/features to new → gradually migrate existing → decommission when fully migrated. Never "big bang" rewrite.

Approaches compared: dedicated sprints (focused/visible, delivery pauses, architectural changes) | continuous allocation (steady, no gaps, easy to skip, small/medium debt) | boy scout (zero overhead, culture, code-level only) | hybrid = recommended (continuous for small + quarterly for large).

## Cost-Benefit Analysis Template

```
Technical Debt Item: [name]  Area: [module]  Impact Score: [N/125]

Current State: [what is broken/slow/risky] | [frequency] | [time lost/occurrence] | [risk if not addressed]

Proposed Fix: [what changes] | [effort in person-days] | [who involved] | [fix risk: low/medium/high]

Business Impact:
  Time saved/month: [hours] = $[amount] at $[rate]/hr
  Break-even: [weeks/months] | 12-month ROI: [%]
  Velocity improvement: [before → after estimate]
  Risk reduction: [describe]

Recommendation: [fix now / next sprint / next quarter / defer]
Approach: [incremental / dedicated / strangler fig]
```

Business language translation: "technical debt" = maintenance backlog slowing delivery | "refactoring" = improving internal structure to ship faster | "high coupling" = changes in one area break another | "missing tests" = no safety net — deployments risky | "outdated deps" = unsupported software — security risk | "architecture debt" = structure doesn't match current needs.

Always frame in terms of delivery speed, risk, cost. Use specific numbers. Never say "the code is ugly."

## Tracking and Reporting

**Debt Register fields:** id, title, area, category (code/architecture/test/docs/infrastructure), description, impact_score, estimated_fix_hours, interest_hours_per_month, status (identified/planned/in_progress/resolved/deferred), owner, dates, resolution_notes, linked_issues.

**Trend metrics (monthly):** total debt items | total interest hrs/month (target: decreasing) | debt resolved this quarter | new debt identified | time tax per area | test coverage trend | dependency freshness %.

**Burndown:** track total items and total interest over time. Goal = controlled decreasing trend in high-impact items, not zero debt.

## Integration with Sprint Planning

1. Identify sprint capacity (e.g., 100 points for 5 devs)
2. Allocate 15-20% to tech debt (15-20 points)
3. Select highest-priority debt items fitting the allocation
4. Create specific, measurable tasks per item
5. Track completion and velocity improvement

Labels: `tech-debt`, `tech-debt:code`, `tech-debt:architecture`, `tech-debt:test`, `tech-debt:infrastructure`, `tech-debt:docs`, `priority:high`, `interest:high`.

Sprint review report: items resolved (count + hours saved) | items identified | net debt change | time tax reduction | remaining high-priority items.

## Prevention

**Definition of Done additions:**
- [ ] No TODO/FIXME without linked issue
- [ ] New code has test coverage for happy path + key error paths
- [ ] No increase in cyclomatic complexity above threshold
- [ ] No new circular dependencies
- [ ] API changes documented
- [ ] No new lint warnings

**ADR template:** `docs/adr/ADR-NNN.md` with Status | Context | Decision | Consequences | Alternatives considered. Prevents repeated debates; provides context for future engineers.

**Code review standards:** reject PRs introducing debt without a linked tracking issue; reject complexity increases without justification; enforce consistent patterns; flag "quick fixes" creating long-term burden.

## Code Quality Metrics

Cyclomatic complexity: 1-10 = low (no action) | 11-20 = medium (consider simplification) | 21-50 = high (refactor — debt item) | >50 = critical (immediate priority).

Code churn hotspots: `Hotspot = Change Frequency × Complexity`. High churn + high complexity = priority refactor | high churn + low complexity = healthy active code | low churn + high complexity = stable but fragile (address before next modification) | low churn + low complexity = no action.

Coverage targets: focus on business logic, data transformations, error handling. Files with 0% coverage in active development. Files <50% coverage with high bug rates. Do NOT chase 100% — focus on critical paths.

Dependency freshness: >80% on latest = healthy | 60-80% = acceptable | 40-60% = needs attention | <40% = high risk (likely security vulnerabilities).

## Anti-Patterns

Paying down low-impact debt because it is easier | zero debt allocation in sprint planning (guarantees debt grows faster) | no stakeholder communication (looks like "doing nothing") | only identifying code debt while ignoring test/docs/infrastructure debt | no prevention policies (paying down while creating at the same rate).

## Output Format

```
Assessment Summary
==================
Codebase/Area:     [scope]
Total Debt Items:  [count by category]
Critical Items:    [count]
Monthly Interest:  [hours lost/month]
Top 3 Priorities:  [items with scores]

Debt Register:
| # | Item | Category | Impact | Fix (hrs) | Interest (hrs/mo) | Priority |

Paydown Plan:
  Sprint allocation: [% and points]
  Next sprint items: [tasks]
  Quarterly target: [items to resolve, interest reduction]

Stakeholder Summary:
  Current time tax: [%]
  Projected savings: [$X over 12 months]
  Break-even: [weeks/months]
  Recommended investment: [hours/sprint]

Prevention:
  DoD additions: [checklist items]
  Metric thresholds: [complexity, coverage, freshness]
  Review cadence: [monthly/quarterly]
```

## Done Criteria

- Debt items identified across all categories
- Each item scored with Impact Scoring Matrix and quantified interest cost
- Top items have cost-benefit analysis for stakeholder review
- Debt register created with owners, categories, scores, and target dates
- Paydown strategy defined with allocation percentage, sprint items, quarterly targets
- Trend tracking established: monthly metrics, quarterly reviews
- Prevention policies in place: DoD updates, ADR template, review standards
- Stakeholder communication prepared with business-language ROI justification
- Integration with sprint planning: debt items tagged, allocation tracked
- Automated detection configured: complexity, churn, coverage, dependency freshness

## Tool Integration

- **ast-grep**: use for structural code pattern search (find function signatures, class usages, import patterns) — faster and more accurate than Grep for code structure
