---
name: deployment-validation
description: Validate deployments with smoke tests, health checks, canary analysis, rollback criteria, and infrastructure verification
metadata:
  version: 1.2
  argument-hint: "environment (staging/prod), validation checks (health/smoke/E2E), rollback threshold"
---

Validate the deployment of $ARGUMENTS.

Core principles:

- Verify before trust: every deployment must prove itself healthy before receiving production traffic
- Fail closed: if validation cannot confirm health, block promotion or trigger rollback
- Automate everything: manual verification does not scale and is error-prone
- Defense in depth: layer multiple validation signals; do not rely on a single health check
- Fast feedback: validation must complete quickly; slow checks delay rollback decisions

Post-deploy smoke tests:

HTTP health checks:

- Hit /health, /ready, and /live endpoints; verify 200 responses with expected body
- Check response time is within acceptable bounds; flag degradation immediately
- Verify the deployed version identifier in response headers or body (X-Version, build SHA)
- Test with and without authentication where applicable

Critical path verification:

- Identify the 3-5 most critical user flows; test each after deploy
- For APIs: verify key endpoints return correct status codes and response shapes
- For web apps: verify login, primary feature, and payment flow respond correctly
- Use synthetic requests with test accounts; never test with real user credentials

API contract tests:

- Verify response schemas match expected OpenAPI/contract definitions
- Check backward compatibility: existing clients must not break
- Validate pagination, error responses, and edge case payloads

Health check endpoint design:

/health — overall application health:

- Database connectivity and query latency
- Cache connectivity (Redis, Memcached)
- External service dependencies (payment, email, auth providers)
- Disk space and file system access where applicable
- Return structured JSON with component status and latency

/ready — readiness to receive traffic:

- Application fully initialized; all startup tasks complete
- Warm caches populated; connection pools established
- Background job processors connected and consuming
- Return 200 only when truly ready; 503 during initialization

/live — liveness proof:

- Process is running and responsive
- Not deadlocked or stuck in an infinite loop
- Lightweight check; must respond in under 100ms
- Used by orchestrators to decide whether to restart the container

Canary deployment validation:

Traffic splitting:

- Start with 1-5% traffic to canary; increase in stages (5%, 10%, 25%, 50%, 100%)
- Hold each stage for a minimum observation window (5-15 minutes per stage)
- Route traffic by header, cookie, IP hash, or weighted load balancer rules

Metric comparison:

- Compare canary vs baseline for: error rate, latency P50/P95/P99, throughput, CPU, memory
- Use statistical significance testing; do not promote on small sample sizes
- Track business metrics: conversion rate, cart abandonment, API success rate

Auto-rollback triggers:

- Error rate exceeds baseline by more than 1% absolute or 50% relative
- P99 latency exceeds baseline by more than 2x
- Any 5xx spike lasting more than 30 seconds
- Health check failures on more than 1 canary instance
- Memory or CPU usage exceeding resource limits

Blue-green validation:

Pre-switch verification:

- Run full smoke test suite against the green (new) environment
- Verify database migrations applied and schema matches expected state
- Confirm environment variables and secrets are correctly populated
- Verify SSL certificates are valid and not expiring within 30 days
- Check external integrations respond from the green environment

DNS and load balancer cutover checks:

- Verify DNS propagation to the new environment before declaring success
- Check load balancer health targets show green instances as healthy
- Confirm old (blue) environment remains available for rapid rollback
- Test with a canary request through the new path before full switch
- Verify sticky sessions or connection draining for stateful workloads

Rollback criteria:

Error rate thresholds:

- HTTP 5xx rate above 1% of total requests
- Application exception rate above baseline by 50% relative
- Timeout rate above 0.5% of total requests
- Any critical-severity error in the first 5 minutes post-deploy

Latency thresholds:

- P50 latency above 2x baseline
- P95 latency above 2x baseline
- P99 latency above 3x baseline
- Any single request exceeding hard timeout (30s default)

Business metric alerts:

- Conversion rate drop of more than 5% relative
- Revenue per minute below 50% of rolling average
- User signup rate below 50% of rolling average
- API integration error rate above partner SLA threshold

Automated rollback execution:

- Rollback must be a single command or automated trigger; no manual steps
- Rollback must complete within 2 minutes for container deployments
- Rollback must preserve data written during the failed deployment
- Post-rollback: re-run smoke tests to confirm stable state

Database migration verification:

Schema verification:

- Compare deployed schema against expected migration state
- Verify all indexes, constraints, and foreign keys exist
- Check for orphaned columns or tables from failed migrations
- Verify RLS policies and permissions are correctly applied

Data integrity post-migration:

- Row count sanity checks on affected tables
- Verify backfilled data with sample queries
- Check referential integrity across related tables
- Verify enum or status values are within expected range

Feature flag verification:

Flag state validation:

- Verify feature flags are in expected state for the target environment
- Confirm new features are disabled by default in production
- Check flag targeting rules match deployment plan
- Verify kill switches are accessible and functional

Gradual rollout checks:

- Confirm percentage rollout matches the deployment plan
- Verify flag evaluation is deterministic for the same user
- Check flag provider connectivity and cache freshness
- Validate fallback behavior when flag provider is unreachable

Infrastructure validation:

Resource limits:

- Verify CPU and memory requests and limits are set correctly
- Check replica count matches expected scaling configuration
- Verify pod disruption budgets are in place
- Confirm horizontal pod autoscaler thresholds are appropriate

SSL and DNS:

- Verify SSL certificate validity; alert if expiring within 30 days
- Check certificate chain is complete and trusted
- Verify DNS records resolve to the correct endpoints
- Check HSTS headers and security headers are present

Autoscaling:

- Verify autoscaler is active and responding to load signals
- Check min/max replica bounds are appropriate
- Confirm scale-up latency is within acceptable range
- Verify scale-down cooldown prevents thrashing

Dependency checks:

Downstream service connectivity:

- Verify connections to all downstream services: databases, caches, queues, APIs
- Check connection pool health and available connections
- Verify circuit breakers are closed and healthy
- Test with actual requests, not just TCP connectivity

Cache warming:

- Verify critical caches are populated after deploy
- Check cache hit rate is recovering to baseline within acceptable time
- Warm essential caches proactively if cold start is unacceptable
- Monitor cache eviction rate for unexpected spikes

Queue backlog:

- Verify message queue consumers are connected and processing
- Check queue depth is not growing unboundedly post-deploy
- Verify dead letter queue is not accumulating new messages
- Confirm processing latency is within SLA

Monitoring setup:

Post-deploy dashboard checks:

- Verify monitoring dashboards are receiving data from the new deployment
- Check log ingestion pipeline is active; no gaps in log data
- Verify distributed tracing is connected and producing spans
- Confirm custom metrics are being emitted with correct labels

Alert status verification:

- Verify critical alerts are active and not silenced
- Check alert thresholds match deployment expectations
- Confirm on-call notification channels are functional
- Test alert escalation path with a synthetic alert if supported

Implementation targets:

GitHub Actions post-deploy steps:

```yaml
# Example structure — adapt to project
post-deploy:
  needs: deploy
  runs-on: ubuntu-latest
  steps:
    - name: Wait for deployment stabilization
      run: sleep 30
    - name: Health check
      run: |
        for i in {1..10}; do
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" $DEPLOY_URL/health)
          if [ "$STATUS" = "200" ]; then exit 0; fi
          sleep 5
        done
        exit 1
    - name: Smoke tests
      run: ./scripts/smoke-test.sh $DEPLOY_URL
    - name: Version verification
      run: |
        VERSION=$(curl -s $DEPLOY_URL/health | jq -r '.version')
        [ "$VERSION" = "$EXPECTED_VERSION" ] || exit 1
    - name: Rollback on failure
      if: failure()
      run: ./scripts/rollback.sh
```

Docker health checks:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```

- Set start-period long enough for application initialization
- Use curl or wget for HTTP checks; use pg_isready or similar for database checks
- Return exit code 1 for unhealthy; 0 for healthy
- Keep the check lightweight; do not trigger expensive operations

Kubernetes probes:

```yaml
# Liveness — restart if stuck
livenessProbe:
  httpGet:
    path: /live
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3

# Readiness — remove from service if not ready
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2

# Startup — wait for slow-starting apps
startupProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 30
```

- Separate concerns: liveness for deadlock detection, readiness for traffic routing, startup for initialization
- Set initialDelaySeconds based on actual application startup time
- Keep timeout short; probe handlers must respond fast

Shell scripts for manual deploy verification:

- Provide a single entry-point script: `verify-deployment.sh <environment> <version>`
- Check health endpoints, version, database schema, feature flags, SSL, DNS
- Output a structured report: PASS / WARN / FAIL per check
- Exit with non-zero code if any critical check fails
- Support --json flag for machine-readable output

Terraform plan verification:

- Verify terraform plan output before apply; flag destructive changes
- Check for resource deletions, replacements, or security group modifications
- Verify state file is not corrupted or out of sync
- Confirm plan matches expected infrastructure changes; no drift

Deployment receipt:

After validation completes, produce a structured deployment receipt:

```
Deployment Receipt
==================
Environment:   production
Version:       v2.4.1 (abc123f)
Deployed at:   2024-01-15T14:30:00Z
Deployed by:   github-actions / manual

Validation Results
------------------
Health checks:     PASS (3/3 endpoints healthy)
Smoke tests:       PASS (5/5 critical paths verified)
Schema version:    PASS (migration 20240115_001 applied)
Feature flags:     PASS (2 new flags disabled by default)
SSL certificate:   PASS (expires 2024-07-15)
DNS resolution:    PASS (resolves to correct endpoint)
Dependencies:      PASS (database, cache, queue connected)
Monitoring:        PASS (dashboards receiving data)

Warnings
--------
- Cache hit rate at 45% (baseline: 92%) — warming in progress
- Queue backlog: 1,200 messages (clearing, ETA 5 min)

Rollback
--------
Rollback command:  ./scripts/rollback.sh production v2.4.0
Previous version:  v2.4.0 (def456a)
Rollback tested:   yes (staging)
```

Implementation workflow:

1. Identify the deployment target: container, serverless, VM, static site
2. Identify the orchestration platform: Kubernetes, ECS, Cloud Run, bare Docker, static hosting
3. Design health check endpoints appropriate to the application stack
4. Configure probe/healthcheck settings with correct timing
5. Build smoke test scripts covering critical paths
6. Define rollback criteria with specific thresholds
7. Set up monitoring and alerting hooks for post-deploy observation
8. Produce the deployment validation configuration and deployment receipt template

Output format:

Provide complete, copy-pasteable configuration files and scripts with inline comments explaining non-obvious decisions.

Structure the output as:

```
Service:           name and type of the deployed service
Environment:       target environment
Health checks:     endpoints and expected responses
Smoke tests:       critical paths tested
Canary/Blue-green: traffic strategy and observation windows
Rollback criteria: thresholds that trigger rollback
Dependencies:      downstream services verified
Monitoring:        dashboards and alerts confirmed
Receipt:           deployment receipt template
```

Output rules:

- Produce concrete configuration files, scripts, and probe definitions; not abstract guidance
- Include specific thresholds, timeouts, and retry counts
- Handle both happy path and failure scenarios
- Provide rollback commands or automation for every deployment type
- Mention assumptions when deployment target or infrastructure is unclear
- Keep validation fast: target under 5 minutes for full validation suite
