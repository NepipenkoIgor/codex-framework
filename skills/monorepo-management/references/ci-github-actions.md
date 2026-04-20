# CI Optimization for Monorepos (GitHub Actions)

## Affected-Only Builds with Nx

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # needed for affected detection
      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile

      # Set base for affected comparison
      - uses: nrwl/nx-set-shas@v4

      # Run only affected tasks
      - run: npx nx affected --target=lint --parallel=3
      - run: npx nx affected --target=test --parallel=3
      - run: npx nx affected --target=build --parallel=3
```

## Dependency Caching

```yaml
# pnpm cache
- uses: actions/cache@v4
  with:
    path: |
      ~/.pnpm-store
      node_modules/.cache
    key: ${{ runner.os }}-pnpm-${{ hashFiles('**/pnpm-lock.yaml') }}
    restore-keys: |
      ${{ runner.os }}-pnpm-

# Nx cache (local, complements remote cache)
- uses: actions/cache@v4
  with:
    path: .nx/cache
    key: ${{ runner.os }}-nx-${{ hashFiles('**/pnpm-lock.yaml') }}-${{ github.sha }}
    restore-keys: |
      ${{ runner.os }}-nx-${{ hashFiles('**/pnpm-lock.yaml') }}-
      ${{ runner.os }}-nx-
```

## Parallelism and Concurrency

```bash
# Nx -- parallel execution with concurrency limit
nx run-many --target=build --all --parallel=5

# Turborepo -- parallel execution
turbo run build --concurrency=5

# CI: match concurrency to runner CPU cores
# GitHub Actions ubuntu-latest: 2 cores -> concurrency 2-3
# Self-hosted runner: match to available cores
```

## Change Detection for Deployment

### Affected Projects for Deployment

```bash
# Nx -- list affected apps
nx affected --target=build --type=app --plain

# Turborepo -- filter affected
turbo run build --filter=...[HEAD~1] --dry-run=json | jq '.tasks[].package'

# Git-based detection (fallback)
git diff --name-only HEAD~1 | grep "^apps/web/" && echo "deploy web"
git diff --name-only HEAD~1 | grep "^apps/api/" && echo "deploy api"
git diff --name-only HEAD~1 | grep "^packages/" && echo "deploy all apps"  # shared package changed
```

### GitHub Actions with Change Detection

```yaml
jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      web: ${{ steps.changes.outputs.web }}
      api: ${{ steps.changes.outputs.api }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: dorny/paths-filter@v2
        id: changes
        with:
          filters: |
            web:
              - 'apps/web/**'
              - 'packages/ui/**'
              - 'packages/shared-types/**'
            api:
              - 'apps/api/**'
              - 'packages/shared-types/**'

  deploy-web:
    needs: [detect-changes, build]
    if: needs.detect-changes.outputs.web == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying web app"

  deploy-api:
    needs: [detect-changes, build]
    if: needs.detect-changes.outputs.api == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying API"
```

## Deployment Rules

- If a shared package changed, deploy all apps that depend on it
- If only an app changed, deploy only that app
- Build dependency graph to determine transitive dependencies
- Tag deployments with the git SHA and affected packages
