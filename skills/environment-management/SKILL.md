---
name: environment-management
description: Manage dev/staging/prod environment parity, provisioning, per-environment configuration with dotenv, Vault, and AWS SSM, preview environments, config promotion, and environment-specific secrets
metadata:
  version: 1.4
  argument-hint: "environments (dev/staging/prod), config management tool (dotenv/Vault/AWS SSM), secret rotation policy, preview environment needs"
---

Implement environment management for $ARGUMENTS.


## Environment Tiers

| Tier | Purpose | Data | Access |
|------|---------|------|--------|
| local | Developer workstation | Seed/fixture | Developer only |
| preview | PR-specific ephemeral | Seed data | PR author + reviewers |
| staging | Pre-production validation | Production-like (anonymized) | Engineering + QA |
| production | Live users | Real data | Restricted (SRE + on-call) |

Rules: local/preview are disposable and reproducible from code. Staging matches production architecture (not scale). Production changes must pass through staging. Dev/staging never contains real PII. Each tier has own secrets/credentials.

## Configuration Strategy

Hierarchy (highest to lowest priority):
1. Environment variables (runtime override)
2. `.env.{environment}.local` (gitignored, machine-specific)
3. `.env.{environment}` (committed, env defaults)
4. `.env` (committed, shared defaults)
5. Application defaults in code

.env rules: never commit secrets (use placeholders), committed files contain non-sensitive defaults, `.local` files are gitignored, document every variable in `.env.example`, validate at startup with fail-fast.

## Secret Management

| Tool | Best for |
|------|----------|
| GitHub Actions Secrets | CI/CD pipelines |
| AWS SSM Parameter Store | AWS workloads (free tier) |
| AWS Secrets Manager | AWS with auto-rotation |
| HashiCorp Vault | Multi-cloud, dynamic secrets |
| Azure Key Vault / GCP Secret Manager | Native cloud workloads |

Naming: `/{app}/{environment}/{key}` (e.g., `/myapp/production/database-url`).

Rules: never in source control, different secrets per environment, rotate on schedule (90d API keys, 30d DB passwords), audit access, use IAM roles over long-lived credentials, retrieve at startup (not baked into images).

### Secret Rotation Without Downtime

Dual-read strategy: application reads both current and previous secret versions. Rotation steps:

1. Generate new secret, store as "pending" version in secret manager
2. Deploy application update that accepts both old and new secret
3. Activate new secret as "current" in all consumers
4. Verify all services use new secret (monitor auth failures)
5. Mark old secret as deprecated, remove after grace period (24-48h)

```typescript
// Dual-read pattern for database credentials
async function getDbConnection() {
  const current = await secretManager.getSecret('/myapp/prod/db-password', { version: 'AWSCURRENT' });
  try {
    return await createConnection({ password: current });
  } catch (err) {
    if (isAuthError(err)) {
      const previous = await secretManager.getSecret('/myapp/prod/db-password', { version: 'AWSPREVIOUS' });
      return await createConnection({ password: previous });
    }
    throw err;
  }
}
```

AWS Secrets Manager auto-rotation: configure Lambda rotation function with `rotationRules.automaticallyAfterDays`. For RDS, use built-in rotation templates. For custom secrets, implement the four-step Lambda (createSecret, setSecret, testSecret, finishSecret).

Schedule: database passwords every 30 days, API keys every 90 days, TLS certificates 30 days before expiry, OAuth client secrets every 180 days.

## Local Development (Docker Compose)

One command to start: `docker compose up`. Use named volumes for persistence, bind mounts for source (live reload), healthchecks with `depends_on` conditions. Provide stubs for external services (MailHog for email, MinIO for S3). Seed DB on first run.

```yaml
services:
  app:
    build: { context: ., dockerfile: Dockerfile, target: development }
    ports: ["3000:3000"]
    volumes: [".:/app", "/app/node_modules"]
    env_file: [.env.development, .env.local]
    depends_on: { db: { condition: service_healthy }, redis: { condition: service_healthy } }
  db:
    image: postgres:16-alpine
    environment: { POSTGRES_DB: myapp_dev, POSTGRES_USER: postgres, POSTGRES_PASSWORD: postgres }
    volumes: [postgres_data:/var/lib/postgresql/data]
    healthcheck: { test: ["CMD-SHELL", "pg_isready -U postgres"], interval: 5s, retries: 5 }
  redis:
    image: redis:7-alpine
    healthcheck: { test: ["CMD", "redis-cli", "ping"], interval: 5s, retries: 5 }
```

### Multi-Environment Compose Files

Use `docker compose -f` with layered files. Base defines services, overrides add env-specific config.

```
docker-compose.yml              # base: service definitions, healthchecks
docker-compose.dev.yml          # dev: bind mounts, debug ports, hot reload
docker-compose.staging.yml      # staging: production images, staging env vars
docker-compose.prod.yml         # prod: resource limits, restart policies, no debug
```

```yaml
# docker-compose.dev.yml — override for development
services:
  app:
    build: { target: development }
    volumes: [".:/app", "/app/node_modules"]
    environment: { DEBUG: "true", LOG_LEVEL: debug }
    ports: ["9229:9229"]  # debugger
  mailhog:
    image: mailhog/mailhog
    ports: ["8025:8025"]
  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    ports: ["9000:9000", "9001:9001"]
```

```yaml
# docker-compose.prod.yml — override for production
services:
  app:
    image: registry.example.com/myapp:${IMAGE_TAG}
    restart: always
    deploy:
      resources:
        limits: { cpus: "2", memory: 1G }
    environment: { NODE_ENV: production, LOG_LEVEL: warn }
```

Run with: `docker compose -f docker-compose.yml -f docker-compose.dev.yml up`

Use a `Makefile` or scripts to wrap common commands:

```makefile
dev:   docker compose -f docker-compose.yml -f docker-compose.dev.yml up
stage: docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d
prod:  docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## Preview / Ephemeral Environments

Auto-provision on PR open, auto-destroy on close/merge. Max lifetime 48-72h of inactivity. Lightweight: single replica, shared DB cluster. Seed with fixture data. Limit 5-10 concurrent per team.

Workflow: PR opened -> create namespace/project -> deploy with PR config -> provision temp DB -> seed -> smoke test -> comment PR with URL. PR closed -> tear down everything.

### Platform-Specific Preview Environments

**Vercel Preview Deployments**: automatic per-branch deploys. Configure `vercel.json` with environment variable overrides per branch. Use `VERCEL_ENV=preview` to detect preview mode. Set preview-specific API endpoints and feature flags. Branch protection: only deploy from PRs (not every push).

**Netlify Deploy Previews**: automatic per-PR deploy with unique URL. Use `CONTEXT=deploy-preview` in `netlify.toml` for preview-specific config. Configure `_redirects` for API proxying to staging backend.

**PR-Based K8s Environments**: use Argo CD ApplicationSet or Flux Kustomization with PR label triggers. Namespace: `preview-pr-{number}`. Share database cluster with per-PR schema or lightweight DB instance.

```yaml
# GitHub Actions — preview environment lifecycle
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]
jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - if: github.event.action != 'closed'
        run: |
          helm upgrade --install preview-pr-${{ github.event.number }} ./chart \
            --namespace preview-pr-${{ github.event.number }} --create-namespace \
            --set image.tag=${{ github.sha }} \
            --set ingress.host=pr-${{ github.event.number }}.preview.example.com
      - if: github.event.action == 'closed'
        run: |
          helm uninstall preview-pr-${{ github.event.number }} \
            --namespace preview-pr-${{ github.event.number }}
          kubectl delete namespace preview-pr-${{ github.event.number }}
```

Cost control: set resource quotas per preview namespace, auto-delete after 72h inactivity, limit concurrent previews (5-10), use spot instances for preview clusters.

## Staging Environment

Must match production in: architecture, DB engine version, container images. Can differ in: scale, instance size. Use anonymized production snapshots or representative seed data. Deploy to staging before production (no exceptions). Run same CI pipeline + smoke tests.

## Configuration Promotion

Promotes (same everywhere): application code (Docker image SHA), DB migrations, API contracts.
Differs per environment: env vars, secrets, infrastructure scale, feature flag values, external endpoints, log levels.

Use Kustomize overlays or Helm values files: `config/base/` + `config/overlays/{environment}/`.

### Promotion Workflow with Approval Gates

```
dev (auto) -> staging (auto on merge to main) -> production (manual approval)
```

1. **Dev**: auto-deploy on every push to feature branch. No approval needed.
2. **Staging**: auto-deploy on merge to `main`. Run full test suite + smoke tests. Block promotion if tests fail.
3. **Production**: require explicit approval (GitHub Environment protection rules, Argo CD sync policy, or CI manual gate). Require at least 1 hour soak time on staging before production promotion.

```yaml
# GitHub Actions — promotion with approval gate
jobs:
  deploy-staging:
    environment: staging
    steps:
      - run: helm upgrade myapp ./chart --set image.tag=${{ github.sha }} -f values.staging.yaml
      - run: ./scripts/smoke-test.sh https://staging.example.com

  deploy-production:
    needs: deploy-staging
    environment:
      name: production
      url: https://example.com
    # GitHub Environment protection: required reviewers + wait timer
    steps:
      - run: helm upgrade myapp ./chart --set image.tag=${{ github.sha }} -f values.production.yaml
      - run: ./scripts/smoke-test.sh https://example.com
```

Rollback: keep last 3 image tags available. If smoke tests fail in production, auto-rollback to previous tag. Never promote a new version until the current promotion is verified.

## Environment Variable Validation

```typescript
// Validate at startup — fail fast
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'staging', 'production']),
  DATABASE_URL: z.string().url(),
  AUTH_SECRET: z.string().min(32),
  PORT: z.coerce.number().default(3000),
  REDIS_URL: z.string().url().optional(),
  SMTP_HOST: z.string().min(1).optional(),
});

// Group validation — clear error report
const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  console.error('Environment validation failed:');
  for (const issue of parsed.error.issues) {
    console.error(`  ${issue.path.join('.')}: ${issue.message}`);
  }
  process.exit(1);
}
export const env = parsed.data;
```

.NET: `AddOptions<AppSettings>().BindConfiguration("App").ValidateDataAnnotations().ValidateOnStart()`.

```csharp
// .NET — validate config at startup with clear errors
public class AppSettings
{
    [Required] public string DatabaseConnection { get; set; } = "";
    [Required, MinLength(32)] public string AuthSecret { get; set; } = "";
    [Range(1, 65535)] public int Port { get; set; } = 5000;
}

// In Program.cs
builder.Services.AddOptions<AppSettings>()
    .BindConfiguration("App")
    .ValidateDataAnnotations()
    .ValidateOnStart(); // fails at startup, not at first request
```

Rules: validate ALL required vars at startup, clear error messages, typed config objects (not raw `process.env`), validate format not just presence, never default secrets.

### Per-Environment Validation

Some variables are required only in certain environments. Use `.refine()` or conditional schemas:

```typescript
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'staging', 'production']),
  DATABASE_URL: z.string().url(),
  // Required in production only
  SENTRY_DSN: z.string().url().optional(),
  SMTP_HOST: z.string().min(1).optional(),
}).refine(
  (data) => data.NODE_ENV !== 'production' || (data.SENTRY_DSN && data.SMTP_HOST),
  { message: 'SENTRY_DSN and SMTP_HOST are required in production' },
);
```

## .env File Management

### File Structure

```
.env                    # committed — shared defaults (non-sensitive)
.env.development        # committed — dev defaults
.env.staging            # committed — staging defaults
.env.production         # committed — production non-sensitive defaults
.env.local              # gitignored — machine-specific overrides
.env.development.local  # gitignored — dev machine-specific
.env.example            # committed — documents ALL variables with placeholders
```

### .env.example as Contract

Every env var must appear in `.env.example` with a placeholder and comment:

```bash
# .env.example — required variables for this project
# Copy to .env.local and fill in real values

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/myapp

# Auth (min 32 chars)
AUTH_SECRET=generate-with-openssl-rand-base64-32

# External services (required in staging/production)
SENTRY_DSN=https://key@sentry.io/project-id
RESEND_API_KEY=re_your-api-key-here
STRIPE_SECRET_KEY=sk_test_your-key-here

# Optional
LOG_LEVEL=info  # debug | info | warn | error
```

### Encrypted .env Files (dotenv-vault)

For teams that need to share secrets without a secret manager:

```bash
# Encrypt .env files per environment
npx dotenv-vault push staging    # encrypts .env.staging to .env.vault
npx dotenv-vault pull staging    # decrypts for local use

# CI/CD uses DOTENV_KEY environment variable to decrypt at runtime
DOTENV_KEY=dotenv://:key_abc@dotenv.org/vault/.env.vault?environment=production
```

Rules: `.env.vault` is committed (encrypted), `DOTENV_KEY` is stored in CI secrets. Alternative: `sops` with AWS KMS or age for encrypting env files in git.

## Kubernetes Namespace Strategy

Namespace per environment with resource quotas. ConfigMap for non-sensitive config, Secret for sensitive. Use External Secrets Operator to sync from AWS SSM/Vault to K8s Secrets.

## Environment Drift Detection

Compare staging and production configs weekly. Flag unexpected differences. Use IaC (Terraform/Pulumi) and GitOps (ArgoCD/Flux) to prevent drift. Run detection in CI on schedule.

## Anti-Patterns

- Staging with production secrets -- credential leak impacts production
- No env var validation -- misconfiguration surfaces at runtime, not startup
- Different DB versions in dev vs production -- migrations work locally, fail in prod
- Preview environments without cleanup -- costs accumulate unnoticed

## Output Format

```
Environment:       [local / preview / staging / production]
Infrastructure:    [Docker Compose / K8s / Vercel]
Configuration:     [.env / ConfigMap / SSM / Vault]
Secrets:           [storage and access method]
Provisioning:      [manual / IaC / auto-provisioned]
Promotion:         [dev -> staging -> production workflow]
Drift Detection:   [approach and frequency]
```

## Done Criteria

- Env vars validated at startup with clear errors
- Each environment has own credentials
- Staging mirrors production architecture
- Configuration differences explicit and version-controlled
