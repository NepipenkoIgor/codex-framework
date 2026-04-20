---
name: monorepo-management
description: Configure and manage monorepo tooling including Nx, Turborepo, pnpm workspaces, npm workspaces, and Lerna
metadata:
  version: 1.4
  argument-hint: "monorepo tool (Turborepo/Nx/Lerna), workspace structure, affected packages, CI strategy"
---

Configure or manage monorepo setup for $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

## Tool Selection

| Tool | Best for | Key feature | Remote cache | Complexity |
|------|----------|-------------|-------------|------------|
| Nx | Large monorepos, enterprise | Computation caching, generators, plugins | Nx Cloud (free tier) | Medium-High |
| Turborepo | Simple setup, Vercel ecosystem | Pipeline caching, minimal config | Vercel Remote Cache | Low-Medium |
| pnpm workspaces | Package management focused | Strict dependencies, fast installs | N/A (pair with Nx/Turbo) | Low |
| npm workspaces | Simple, no extra tooling | Built-in, zero config | N/A (pair with Nx/Turbo) | Low |
| Lerna | Legacy, publishing focused | Version management, changelog | N/A (deprecated as build tool) | Low |
| Yarn workspaces | Yarn ecosystem | PnP, constraints, protocols | N/A (pair with Nx/Turbo) | Low-Medium |

### Nx vs Turborepo vs pnpm Workspaces

| Dimension | Nx | Turborepo | pnpm Workspaces (alone) |
|-----------|-----|-----------|------------------------|
| Setup complexity | Medium -- plugins, generators, nx.json | Low -- single turbo.json | Minimal -- pnpm-workspace.yaml |
| Task orchestration | Full -- dependency graph, affected, DTE | Good -- pipeline, affected, caching | None -- only dependency management |
| Code generation | Built-in generators + custom plugins | turbo gen (Plop-based) | Manual or external (Plop) |
| Module boundaries | Built-in ESLint rule | Manual (ESLint, dependency-cruiser) | Manual |
| Remote caching | Nx Cloud (free tier, DTE) | Vercel Remote Cache or self-hosted | N/A |
| Plugin ecosystem | Rich -- first-party plugins | Minimal | N/A |
| Language support | Polyglot (JS, Go, Rust, Java) | JS/TS focused | JS/TS only |
| Best for | 5+ packages, multi-team, enterprise | 2-20 packages, JS/TS, fast setup | Dependency linking only |

Decision:
- **Start with pnpm workspaces** for dependency management in any monorepo
- **Add Turborepo** when you need task caching and affected builds (most projects)
- **Use Nx instead** when you need generators, module boundary enforcement, distributed execution, or polyglot support
- **Never use pnpm workspaces alone for 5+ packages** -- lack of caching makes CI slow
- **Existing Lerna repo**: migrate task running to Nx or Turborepo

For Nx configuration, generators, and module boundaries, read `references/nx.md`.
For Turborepo configuration and generators, read `references/turborepo.md`.

## Naming Conventions

- Packages: `@scope/package-name` (e.g., `@acme/ui`, `@acme/api-client`)
- Feature libs: `@scope/feature-name` (e.g., `@acme/auth`, `@acme/dashboard`)
- Shared libs: `@scope/shared-name` (e.g., `@acme/shared-types`, `@acme/shared-utils`)
- Apps: plain names (e.g., `web`, `api`, `admin`)

## Migration from Polyrepo to Monorepo

Phase 1 -- Setup (1 day):
1. Create the monorepo repository with workspace configuration
2. Set up shared config (tsconfig, eslint, prettier)
3. Configure task runner (Nx or Turborepo)
4. Set up CI pipeline

Phase 2 -- Move repositories (per repo, 2-4 hours):
1. Move source code into `apps/` or `packages/` directory
2. Update import paths and package references
3. Align dependency versions with root lockfile
4. Verify build, test, and lint pass

Phase 3 -- Extract shared code (iterative):
1. Identify duplicated code across packages
2. Extract into shared packages (`packages/shared-*`)
3. Update consumers to import from shared packages
4. Add dependency boundaries

### Preserving Git History

```bash
git clone source-repo /tmp/source-repo
cd /tmp/source-repo
git filter-repo --to-subdirectory-filter apps/web
cd /path/to/monorepo
git remote add source-web /tmp/source-repo
git fetch source-web
git merge source-web/main --allow-unrelated-histories
git remote remove source-web
```

### Migration Pitfalls

- Dependency version conflicts -- resolve before moving
- Different Node.js versions -- standardize
- Circular dependencies hidden across repos -- break before merging
- CI pipelines assuming single-repo structure -- rewrite
- Large git history -- use shallow clones in CI

## Key Concepts

### Task Pipeline

```
build:  depends on upstream ^build (all dependencies must build first)
test:   depends on own build (build must complete before testing)
lint:   no dependencies (can run in parallel with everything)
deploy: depends on build + test (both must pass)
dev:    no cache, persistent (development server)
```

### Caching

1. Task runner hashes inputs: source files, config, dependencies, environment variables
2. If hash matches a previous run, output is restored from cache
3. If no match, task runs and output is stored

Common cache miss causes:
- Unstable file (timestamp, generated ID) in cache inputs
- Environment variable changed between runs
- Different Node.js or OS version between CI and local

### Affected Commands

1. Compute the dependency graph of all packages
2. Determine which files changed (git diff against base)
3. Map changed files to affected packages
4. Include downstream dependents

### Dependency Boundaries

Rules:
- Apps can import feature libs and shared libs
- Feature libs can import only shared libs
- Shared libs can import only other shared libs
- No circular dependencies -- enforce with tooling
- Platform-specific code (web, api) must not cross-import

For boundary enforcement without Nx, read `references/boundary-enforcement.md`.

## Shared Configuration

For TypeScript, ESLint, Prettier, and pnpm workspace config patterns, read `references/shared-config.md`.

## Version Management

| Strategy | When to use |
|----------|-------------|
| Independent | Packages consumed externally, different release cadences |
| Fixed | Internal packages, tight coupling, simpler mental model |

Tools: Changesets (`@changesets/cli`) recommended for both strategies.

For Changesets configuration, workflow, and release pipeline, read `references/changesets.md`.

## Remote Caching

For teams that can't use Nx Cloud or Vercel:
- S3-compatible backend: `nx-remotecache-s3`, `turborepo-remote-cache`
- Self-hosted server: deploy cache API, store artifacts in S3/GCS
- Set TTL: 7-30 days depending on storage costs

## CI Optimization

For GitHub Actions workflows with affected detection, dependency caching, parallelism, DTE, and change-based deployment, read `references/ci-github-actions.md`.

## Generator Best Practices

- Every monorepo must have at least one generator for new packages
- Generated packages include: package.json, tsconfig.json, eslint config, test config, src/index.ts
- Generators auto-update root tsconfig paths and workspace references
- Test generators in CI
- Update templates when shared configs change

## Anti-Patterns

- All packages depending on a "shared" God package -- creates implicit coupling, makes it a bottleneck
- No dependency boundaries enforced -- architecture erodes silently over time
- No remote caching -- every CI run rebuilds the entire graph from scratch
- Workspace package without explicit exports -- consumers import internal paths, breaks refactoring
- Deploying all apps when only one changed -- defeats the purpose of affected detection

## Output Format

```
Monorepo Configuration
=======================
Tool:          Nx / Turborepo
Package manager: pnpm / npm / yarn
Workspace packages: N apps, M libraries

Structure:
  apps/         -- list of apps
  packages/     -- list of shared libraries

Task Pipeline:
  build/test/lint/typecheck/dev with dependencies and cache config

Caching:      Local and remote cache strategy
Boundaries:   Enforcement approach and rules
CI Pipeline:  Affected detection, parallelism, cache strategy
Versioning:   Strategy and tooling
Files Changed: List of created/modified files
```

## Done Criteria

- Task pipeline correctly models dependencies between packages
- Caching works: second run of unchanged tasks completes in <5 seconds
- Remote caching configured: CI and local share cache
- Affected commands only run tasks for changed packages and dependents
- Dependency boundaries enforced via lint rules -- violations fail CI
- CI pipeline uses caching and affected detection
- Shared configuration centralized and extended per package
- Version management strategy chosen and automated
- Change detection determines which apps to deploy
- Dependency graph visualized and reviewed
