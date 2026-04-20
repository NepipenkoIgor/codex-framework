---
name: devops-ci
description: Design and implement CI/CD pipelines, Dockerfiles, GitHub Actions workflows, deployment configurations, and container setups
metadata:
  version: 1.4
  argument-hint: "CI/CD platform (GitHub Actions/GitLab CI/Jenkins), deployment target (Docker/Kubernetes/serverless), tech stack, pipeline stages (test/lint/build/deploy)"
---

Implement $ARGUMENTS.


## Example

A GitHub Actions CI/CD pipeline for a Node.js API with Docker deployment:

```yaml
# .github/workflows/ci.yml
name: CI/CD
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm test -- --coverage
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage
          path: coverage/lcov.info

  build-and-push:
    needs: lint-and-test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      id-token: write  # OIDC for ECR
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
      - uses: aws-actions/amazon-ecr-login@v2
        id: ecr
      - uses: docker/build-push-action@v6
        with:
          push: true
          tags: ${{ steps.ecr.outputs.registry }}/api:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

Matching multi-stage Dockerfile:

```dockerfile
# Dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
RUN addgroup -g 1001 app && adduser -u 1001 -G app -s /bin/sh -D app
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
USER app
EXPOSE 3000
HEALTHCHECK CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/server.js"]
```

Output format:

Provide complete, copy-pasteable configuration files with inline comments explaining non-obvious decisions.

Structure the output as:

```
Pipeline: name and purpose
Stages: ordered list of pipeline stages
Trigger: events that start the pipeline
Environments: target environments and promotion gates
Caching: what is cached and expected hit rate
Security: scanning and secret handling approach
Deployment: strategy and rollback plan
Monitoring: post-deploy verification approach
```

Output rules:

- Produce concrete configuration files, not abstract guidance
- Include inline comments for non-obvious decisions
- Specify exact action versions, base images, and tool versions
- Handle both happy path and failure scenarios
- Keep pipelines fast: target under 10 minutes for CI, under 20 for full CD
- Mention assumptions when deployment target or infrastructure is unclear

GitHub Actions patterns:

Basic CI workflow template:
- Trigger: push to main, pull_request to main, workflow_dispatch
- Jobs: lint → test → build → deploy (with needs dependencies)
- Use concurrency groups: `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }`
- Pin actions by SHA: `actions/checkout@v4` is acceptable, but prefer `actions/checkout@<sha>` for security-critical pipelines
- Always set `timeout-minutes` on jobs and steps to prevent hung runners

Caching strategies:
- Node.js: cache node_modules via `actions/setup-node` with `cache: 'npm'` or explicit `actions/cache` with `hashFiles('**/package-lock.json')`
- .NET: cache NuGet with `actions/cache` keyed on `**/*.csproj` files
- Python: cache pip with `actions/setup-python` with `cache: 'pip'`
- Docker: use `docker/build-push-action` with `cache-from: type=gha` and `cache-to: type=gha,mode=max`
- Turborepo / Nx: cache build outputs between runs with `actions/cache`

Matrix builds:
- Use matrix for multi-version testing: `strategy: { matrix: { node-version: [18, 20, 22] } }`
- Use matrix for multi-platform: `runs-on: ${{ matrix.os }}` with `os: [ubuntu-latest, windows-latest, macos-latest]`
- Use `fail-fast: false` when you need all matrix combinations to run even if one fails
- Limit matrix with `include` and `exclude` for targeted combinations

Environment and secrets management:
- Use GitHub Environments for deployment gates: `environment: production` with required reviewers
- Use environment-scoped secrets for per-environment credentials
- Use OIDC for cloud providers: `permissions: { id-token: write }` + `aws-actions/configure-aws-credentials` with `role-to-assume`
- Never use `${{ secrets.* }}` in echo or log statements — mask automatically, but avoid exposure
- Use `gh secret set` for programmatic secret management

Reusable workflows:
- Extract common CI logic into reusable workflows: `.github/workflows/ci-shared.yml` with `workflow_call` trigger
- Pass inputs and secrets explicitly: `inputs:` for config, `secrets: inherit` or explicit secret mapping
- Use composite actions for reusable steps within a workflow: `.github/actions/setup-project/action.yml`

Multi-stage Dockerfile patterns:

Node.js multi-stage:
- Stage 1 (deps): FROM node:20-alpine, COPY package*.json, RUN npm ci
- Stage 2 (build): FROM deps, COPY source, RUN npm run build
- Stage 3 (runtime): FROM node:20-alpine, COPY --from=build built output, USER node, CMD node server.js
- Use .dockerignore to exclude: node_modules, .git, .env*, *.md, tests/

.NET multi-stage:
- Stage 1 (build): FROM mcr.microsoft.com/dotnet/sdk:8.0, COPY csproj, RUN dotnet restore, COPY ., RUN dotnet publish -c Release -o /app
- Stage 2 (runtime): FROM mcr.microsoft.com/dotnet/aspnet:8.0, COPY --from=build /app, USER app, ENTRYPOINT dotnet App.dll
- Use .dockerignore to exclude: bin/, obj/, .git, .env*

Python multi-stage:
- Stage 1 (build): FROM python:3.12-slim, COPY requirements.txt, RUN python -m venv /opt/venv && /opt/venv/bin/pip install -r requirements.txt
- Stage 2 (runtime): FROM python:3.12-slim, COPY --from=build /opt/venv /opt/venv, ENV PATH="/opt/venv/bin:$PATH", COPY app/, USER nobody
- Consider using `--target` for conditional stage building

Common pipeline anti-patterns to avoid:
- Running all steps in a single job instead of splitting into parallel jobs
- Not caching dependencies — every run downloads everything from scratch
- Using `latest` tag for base images — breaks reproducibility
- Echoing or logging secrets (even masked, they can appear in artifacts)
- Running CI with elevated permissions when read-only is sufficient
- Not setting job timeouts — hung processes consume runner minutes
- Skipping lint/format checks in CI — leads to noisy diffs and style debt
- Deploying without a preceding quality gate (tests, scans, approvals)
- Hardcoding environment-specific values in pipeline config instead of using variables
- Not generating test reports or coverage artifacts — makes debugging CI failures harder
