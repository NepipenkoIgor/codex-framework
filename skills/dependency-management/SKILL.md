---
name: dependency-management
description: Implement automated dependency management using Renovate, Dependabot, or manual strategies for npm, NuGet, pip, and Go modules
metadata:
  version: 1.3
  argument-hint: "package manager (npm/NuGet/pip), automation tool (Renovate/Dependabot), update strategy (major/minor/patch), monorepo or single package"
---

Implement dependency management for $ARGUMENTS.


## Strategy Selection

| Tool | Best for | Hosting | PR style | Ecosystem support |
|------|----------|---------|----------|-------------------|
| Renovate | Flexible config, monorepos, grouping | Self-hosted or Mend cloud | Grouped or individual | npm, NuGet, pip, Go, Docker, Helm, Terraform |
| Dependabot | GitHub-native, simple setup | GitHub-managed | Individual PRs | npm, NuGet, pip, Go, Docker, GitHub Actions |
| Manual | Small teams, infrequent updates | N/A | Manual PRs | Any |

Decision guide:
- GitHub + simple config -> Dependabot (zero setup)
- Complex grouping, monorepo, non-GitHub -> Renovate
- Enterprise with strict approval -> Renovate (fine-grained control)
- <10 dependencies, rarely changes -> Manual with periodic audit

## Renovate Configuration

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended", "schedule:weekdays", ":semanticCommits", ":automergeMinor", "group:monorepos", "group:recommended"],
  "timezone": "America/New_York",
  "schedule": ["before 6am on Monday"],
  "labels": ["dependencies"],
  "assignees": ["team-lead"],
  "reviewers": ["team:platform"],
  "prHourlyLimit": 3,
  "prConcurrentLimit": 10,
  "dependencyDashboard": true,
  "vulnerabilityAlerts": {
    "enabled": true,
    "labels": ["security", "priority:high"],
    "schedule": ["at any time"],
    "automerge": false
  },
  "packageRules": [
    {
      "description": "Automerge patch and minor for dev dependencies",
      "matchDepTypes": ["devDependencies"],
      "matchUpdateTypes": ["patch", "minor"],
      "automerge": true,
      "automergeType": "branch"
    },
    {
      "description": "Automerge patch for production dependencies",
      "matchDepTypes": ["dependencies"],
      "matchUpdateTypes": ["patch"],
      "automerge": true,
      "automergeType": "pr",
      "platformAutomerge": true
    },
    {
      "description": "Group ESLint ecosystem updates",
      "matchPackagePatterns": ["eslint"],
      "groupName": "eslint"
    },
    {
      "description": "Group testing framework updates",
      "matchPackagePatterns": ["vitest", "@testing-library", "jest", "playwright"],
      "groupName": "testing"
    },
    {
      "description": "Group TypeScript and build tools",
      "matchPackageNames": ["typescript"],
      "matchPackagePatterns": ["@types/", "tslib"],
      "groupName": "typescript"
    },
    {
      "description": "Require manual review for major updates",
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["dependencies", "breaking-change"],
      "reviewers": ["team:senior-engineers"]
    },
    {
      "description": "Pin Docker digests for reproducibility",
      "matchDatasources": ["docker"],
      "pinDigests": true
    },
    {
      "description": "Group Terraform provider updates monthly",
      "matchManagers": ["terraform"],
      "groupName": "terraform-providers",
      "schedule": ["before 6am on the first day of the month"]
    },
    {
      "description": "Do not update engines or peerDependencies automatically",
      "matchDepTypes": ["engines", "peerDependencies"],
      "enabled": false
    }
  ],
  "ignoreDeps": ["node"]
}
```

### Renovate Schedule Reference

| Schedule | Expression | Use when |
|----------|-----------|----------|
| Weekdays before work | `"before 6am on weekdays"` | Default — PRs ready for morning review |
| Weekly on Monday | `"before 6am on Monday"` | Lower frequency for stable projects |
| Monthly | `"before 6am on the first day of the month"` | Infrastructure deps, Terraform |
| At any time | `"at any time"` | Security vulnerabilities only |

### Renovate Preset Reference

| Preset | What it does |
|--------|-------------|
| `config:recommended` | Sensible defaults: group monorepos, pin, schedule weekly |
| `:automergeMinor` | Automerge minor and patch when CI passes |
| `:semanticCommits` | Conventional commit format: `fix(deps):`, `chore(deps):` |
| `group:monorepos` | Group updates from known monorepos (babel, jest, angular, etc.) |
| `:pinVersions` | Pin exact versions (remove `^` and `~`) |

## Dependabot Configuration

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "06:00"
      timezone: "America/New_York"
    open-pull-requests-limit: 10
    labels: ["dependencies"]
    reviewers: ["team-platform"]
    commit-message:
      prefix: "fix"
      prefix-development: "chore"
      include: "scope"
    groups:
      production-minor-patch:
        dependency-type: "production"
        update-types: ["minor", "patch"]
      dev-dependencies:
        dependency-type: "development"
        update-types: ["minor", "patch"]
      eslint:
        patterns: ["eslint*", "@eslint/*"]
      testing:
        patterns: ["vitest*", "@testing-library/*", "playwright*"]

  - package-ecosystem: "docker"
    directory: "/"
    schedule: { interval: "weekly" }
    labels: ["dependencies", "docker"]

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly" }
    labels: ["dependencies", "ci"]

  - package-ecosystem: "nuget"
    directory: "/"
    schedule: { interval: "weekly" }
    labels: ["dependencies"]
```

### Dependabot vs Renovate

| Feature | Dependabot | Renovate |
|---------|-----------|----------|
| Grouping | Basic (pattern matching) | Advanced (regex, managers, per-group schedules) |
| Automerge | Via GitHub branch protection | Built-in, configurable per rule |
| Monorepo support | One config per directory | Single config, multi-directory |
| Lock file maintenance | No | Yes (`lockFileMaintenance`) |
| Self-hosted | No | Yes |

## Update Grouping Strategies

### By Type (Recommended Default)

```
Group 1: devDependencies (patch + minor) -> automerge
Group 2: dependencies (patch) -> automerge
Group 3: dependencies (minor) -> review, automerge if tests pass
Group 4: dependencies (major) -> manual review required
Group 5: security updates -> immediate, any schedule
```

### By Domain

```
eslint     -> all ESLint-related packages
testing    -> vitest, jest, testing-library, playwright
typescript -> typescript, @types/*, tslib
react      -> react, react-dom, @types/react
database   -> prisma, drizzle, typeorm, @prisma/*
build      -> vite, esbuild, rollup, webpack
```

Rules:
- Group packages that must update together (e.g., `react` + `react-dom` + `@types/react`)
- Separate security updates from regular updates — security runs on any schedule
- Keep major updates as individual PRs for focused review and changelog reading
- Limit concurrent PRs to prevent CI queue saturation (5-10 max)

## Automerge Policies

### Safe to Automerge

| Condition | Why |
|-----------|-----|
| devDependencies patch/minor | Does not affect production bundle |
| Production patch (with passing CI) | Bug fixes, low risk |
| Lock file maintenance | No version changes, just lock file refresh |
| GitHub Actions minor/patch | CI tooling, low risk |
| Docker base image digest | Same version, different build |

### Require Manual Review

| Condition | Why |
|-----------|-----|
| Any major version bump | Breaking changes possible |
| Production minor (complex packages) | New features may change behavior |
| Security updates that are major versions | May require code changes |
| Framework updates (React, Angular, Next.js) | Often require migration steps |

Requirements: all CI checks must pass (lint, test, build, type-check), no merge conflicts, branch protection allows automerge. Set `"platformAutomerge": true` in Renovate to use GitHub's native auto-merge.

## Vulnerability Remediation

### Triage SLAs

| Severity | CVSS | Fix within |
|----------|------|-----------|
| Critical | >= 9.0 | 24 hours |
| High | >= 7.0 | 7 days |
| Medium | >= 4.0 | 30 days |
| Low | < 4.0 | Next scheduled cycle |

### Automated Scanning in CI

```yaml
# .github/workflows/security.yml
name: Security Audit
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }
  schedule:
    - cron: '0 6 * * 1'
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm audit --audit-level=high
        continue-on-error: true
      - run: npx better-npm-audit audit --level high
```

### Transitive Vulnerability Overrides

```json
// npm
{ "overrides": { "vulnerable-package": ">=2.0.1" } }

// pnpm
{ "pnpm": { "overrides": { "vulnerable-package": ">=2.0.1" } } }

// Yarn
{ "resolutions": { "vulnerable-package": ">=2.0.1" } }
```

Rules: document every override with a link to the advisory; review monthly; remove when the parent dependency has updated; test after applying — version mismatches cause runtime errors.

## Major Version Update Process

1. Read the changelog — identify breaking changes, deprecations, and migration steps
2. Check compatibility — verify peer dependencies and ecosystem
3. Create a branch — isolate the update
4. Follow the official migration guide if one exists
5. Run the full test suite — unit, integration, E2E
6. Check for runtime deprecation warnings
7. Test in staging — deploy and verify critical flows
8. Gradual rollout — deploy behind a feature flag if risky

### Framework Migration Guide Locations

| Framework | Guide location | Typical effort |
|-----------|---------------|----------------|
| React | reactjs.org/blog | Low-Medium (codemods available) |
| Next.js | nextjs.org/docs/upgrading | Medium (codemod + manual) |
| Angular | update.angular.io | Medium-High (ng update) |
| Vue | v3-migration.vuejs.org | Medium |
| .NET | learn.microsoft.com/dotnet/core/migration | Medium-High |
| TypeScript | typescriptlang.org/docs/handbook/release-notes | Low-Medium |

## Lock File Management

- Always commit lock files (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`)
- Use `--frozen-lockfile` in CI to prevent unexpected changes
- Never manually edit lock files
- Renovate: `"lockFileMaintenance": { "enabled": true, "schedule": ["before 6am on Monday"] }` — refreshes the entire lock file to pick up transitive security patches
- Review lock file diffs in PRs for unexpected transitive changes

## Monorepo Dependencies

```bash
# Detect and fix version mismatches across packages
npx syncpack list-mismatches
npx syncpack fix-mismatches
```

- Single lock file at root (pnpm/npm/yarn workspaces)
- `workspace:*` — always use local version; `workspace:^1.0.0` — use local if compatible
- Use pnpm for strict dependency isolation (hoisting off by default)
- Set `strict-peer-dependencies=true` and `auto-install-peers=true` in `.npmrc`

## Custom Registries

```
# .npmrc — private npm
@acme:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${NPM_TOKEN}
```

```xml
<!-- nuget.config -->
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
    <add key="acme-feed" value="https://pkgs.dev.azure.com/acme/_packaging/main/nuget/v3/index.json" />
  </packageSources>
</configuration>
```

Renovate private registry access: configure `hostRules` with `matchHost`, `hostType`, and encrypted token.

## Dashboard and Reporting

| Metric | Target | Alert |
|--------|--------|-------|
| % dependencies on latest | >70% | <50% |
| Avg days behind latest | <30 days | >90 days |
| Critical CVEs unpatched | 0 | >0 |
| High CVEs unpatched | 0 | >0 for >7 days |
| Open dependency PRs | <10 | >20 |
| Automerge success rate | >90% | <70% |

Enable `"dependencyDashboard": true` in renovate.json for a tracking issue showing pending updates, open PRs, and detected issues.

## Testing Strategy

- All CI checks must pass before automerge (lint, type-check, unit, integration)
- UI dependency updates (React, MUI, Tailwind): run visual regression tests (Chromatic, Percy)
- Critical production dependencies: deploy to canary/staging, run smoke tests, monitor error rates for 30-60 minutes before promoting

## Common Pitfalls

- **Breaking transitive dependencies** — a direct update may bring in a new transitive version. Review the full dependency tree diff.
- **Phantom dependencies** — using a hoisted package not declared in `package.json`. Fix: use pnpm strict mode or explicitly declare all imports.
- **Version conflicts** — two packages require incompatible versions. Check for newer compatible versions or use overrides temporarily.
- **Lock file conflicts** — frequent merge conflicts from concurrent dependency PRs. Fix: limit concurrent PRs, use `rebaseWhen: "conflicted"` in Renovate.

## Anti-Patterns

- Updating everything at once — impossible to bisect regressions
- Automerging major updates without changelog review
- Manual lock file edits — causes phantom dependencies
- Too many concurrent dependency PRs — overwhelms CI and reviewers
- Overrides without documentation
- Different dependency versions across monorepo packages

## Implementation Workflow

1. Choose Renovate or Dependabot based on project needs
2. Configure update schedule (weekly for most, any time for security)
3. Set up grouping rules (by type, domain, and criticality)
4. Configure automerge policies (dev deps patch/minor, prod deps patch)
5. Set up vulnerability scanning in CI
6. Define major update review process
7. Enable lock file maintenance (weekly)
8. Configure dashboards and freshness metrics
9. Document override/resolution policies
10. Review and refine configuration monthly

## Output Format

```
Tool:              [Renovate / Dependabot / manual]
Schedule:          [update frequency and timing]
Grouping:          [group strategy per dependency type]
Automerge:         [what automerges, what requires review]
Vulnerability SLA: [critical/high/medium/low remediation timelines]
Lock File:         [maintenance strategy]
CI Checks:         [what runs on dependency PRs]
Registries:        [private registries configured]
Monorepo:          [shared constraint and hoisting strategy]
Dashboard:         [reporting and metrics tracked]
```

## Done Criteria

- Automated dependency updates run on schedule with grouped PRs
- Automerge works for low-risk updates (dev deps patch/minor, prod deps patch)
- Major updates require manual review with changelog reading
- Vulnerability alerts trigger immediate PR creation
- Critical CVEs patched within 24 hours; high within 7 days
- CI passes before any dependency PR can merge
- Lock file maintained weekly to catch transitive updates
- Override/resolution entries documented with rationale and review date
- Dependency freshness tracked: >70% on latest, <30 days average age
- Concurrent PR limit prevents CI queue saturation
- Monorepo dependencies aligned with no version mismatches
