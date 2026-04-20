# Changesets Version Management

## Independent Versioning

Each package has its own version -- versioned and released independently.

When to use:
- Packages are consumed by external projects (published to npm)
- Packages have different release cadences
- Team autonomy is important

## Fixed Versioning

All packages share a single version -- released together.

When to use:
- Internal packages not published externally
- Tight coupling between packages
- Simpler mental model for the team

## Changeset Workflow

```bash
# Developer adds a changeset describing their change
pnpm changeset
# Select affected packages, semver bump type, write description

# CI: consume changesets, bump versions, update changelogs, publish
pnpm changeset version   # bump package.json versions, update CHANGELOG.md
pnpm changeset publish   # publish changed packages to npm
```

## Configuration

```json
// .changeset/config.json
{
  "$schema": "https://unpkg.com/@changesets/config@3.0.0/schema.json",
  "changelog": "@changesets/changelog-github",
  "commit": false,
  "fixed": [],
  "linked": [["@acme/ui", "@acme/shared-types"]],
  "access": "restricted",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": []
}
```

## Release Workflow (GitHub Actions)

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - name: Create Release PR or Publish
        uses: changesets/action@v1
        with:
          publish: pnpm changeset publish
          version: pnpm changeset version
          commit: 'chore: version packages'
          title: 'chore: version packages'
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```
