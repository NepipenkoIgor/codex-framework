---
name: release-management
description: Implement semantic versioning automation, changelog generation, release branches, hotfix workflows, and monorepo release coordination
metadata:
  version: 1.4
  argument-hint: "package type, monorepo (yes/no), publishing target (npm/NuGet/Docker), pre-release channels"
---

Implement release management for $ARGUMENTS.


## Semantic Versioning

```
MAJOR.MINOR.PATCH[-prerelease]
```

| Change type | Bump | Commit prefix |
|-------------|------|---------------|
| Breaking change | MAJOR | `feat!:` or `BREAKING CHANGE:` footer |
| New feature | MINOR | `feat:` |
| Bug fix | PATCH | `fix:` |
| Performance | PATCH | `perf:` |
| Docs, refactor, test, ci, chore | No release | respective prefix |

Pre-1.0: breaking changes bump MINOR (`0.1.0`->`0.2.0`), features/fixes bump PATCH.

## Conventional Commits Enforcement

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', ['feat', 'fix', 'refactor', 'docs', 'test', 'chore', 'style', 'perf', 'ci', 'revert']],
    'subject-case': [2, 'always', 'lower-case'],
    'subject-max-length': [2, 'always', 72],
  },
};
```

Enforce in CI with `wagoid/commitlint-github-action` on pull requests.

## Tool Selection

| Tool | Style | Best for |
|------|-------|----------|
| semantic-release | Fully automated, commit-driven | Single-package, disciplined commits |
| release-please | PR-based, review before release | Explicit approval, monorepos |
| Changesets | Manual changeset files | Monorepo independent versioning |

### semantic-release

```json
{
  "branches": ["main", { "name": "next", "prerelease": true }, { "name": "beta", "prerelease": true }],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/changelog",
    "@semantic-release/npm",
    "@semantic-release/github",
    ["@semantic-release/git", { "assets": ["CHANGELOG.md", "package.json"], "message": "chore(release): ${nextRelease.version}" }]
  ]
}
```

CI: push to main/next/beta triggers `npx semantic-release` with `GITHUB_TOKEN` + `NPM_TOKEN`.

### release-please

```yaml
# .github/workflows/release-please.yml
- uses: googleapis/release-please-action@v4
  id: release
  with: { release-type: node }
# Then conditionally publish if release_created
```

### Changesets

```bash
npx @changesets/cli init
npx changeset          # add changeset in PR
npx changeset version  # update versions + CHANGELOG
npx changeset publish  # publish to npm
```

CI: use `changesets/action@v1` with `publish: npm run release`.

## Branching Strategies

**Trunk-based** (preferred): all on `main`, tags trigger releases. Hotfixes commit to `main`, cherry-pick to release branch if needed.

**Release branches**: cut from `main` when ready. Only bug fixes on release branches (cherry-pick from `main`). Best for scheduled releases or multiple supported versions.

**Hotfix workflow**: branch from release tag, fix, PR to both `main` and release branch, release patch version, delete hotfix branch.

## Pre-Release Channels

| Channel | Branch | Format | Audience |
|---------|--------|--------|----------|
| stable | main | `1.2.3` | All users |
| beta | beta | `1.3.0-beta.1` | Opt-in testers |
| next | next | `1.3.0-next.1` | Internal |
| canary | every commit | `0.0.0-canary.sha` | CI testing |

```bash
npm publish --tag beta       # install: npm install @pkg@beta
npm dist-tag add @pkg@1.3.0-beta.5 latest  # promote to stable
```

Docker tags: `1.2.3`, `1.3.0-beta.1`, `latest`, `sha-abc1234`, `main`.

## Artifact Publishing

**npm**: `npm publish --access public` with `--provenance` for SLSA. Use `.npmignore` or `files` field. Verify with `npm pack --dry-run`.

**NuGet**: `dotnet pack -c Release -o ./artifacts /p:Version=$VERSION && dotnet nuget push`.

**Docker**: `docker/build-push-action@v6` with version + `latest` tags, OCI labels.

**GitHub Releases**: auto-generate notes from commits, attach binaries, mark pre-releases.

## Changelog

Group by: Added, Changed, Deprecated, Removed, Fixed, Security. Write for users, not developers. Include PR/issue links. Note breaking changes with migration guidance. Keep `[Unreleased]` section.

## Monorepo Coordination

**Independent versioning**: each package has own version. Use Changesets or release-please manifest. Changes to A don't bump B.

**Synchronized versioning**: all packages share version. Simpler but unnecessary releases.

**Dependency cascade**: change to B triggers new B version, then A (which depends on B) also releases with updated dependency.

## Release Validation

Pre-release: all CI passes, CHANGELOG updated, version follows semver, breaking changes documented, tested in staging.

Post-release: artifact downloadable, version matches tag, docs updated, no error spike in first 30 minutes.

## Anti-Patterns

- Publishing from local machines — non-reproducible artifacts; use CI with locked environments
- Mutable tags (overwriting `latest` without version tags) — makes rollback impossible
- Releasing all monorepo packages on every change — version noise; use Changesets or release-please manifest for independent versioning
- No pre-release channel — forces breaking changes directly to stable users

## Output Format

```
Strategy:          [semantic-release / release-please / changesets]
Versioning:        [independent / synchronized]
Branching:         [trunk-based / release branches]
Channels:          [stable, beta, next, canary]
Publishing:        [npm / NuGet / Docker / GitHub Releases]
Changelog:         [auto-generated / manual changesets]
Commit Convention: [conventional commits with commitlint]
Monorepo:          [coordination approach, if applicable]
CI Pipeline:       [release workflow and triggers]
```
