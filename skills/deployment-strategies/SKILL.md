---
name: deployment-strategies
description: Implement blue-green, canary, rolling update, and GitOps deployment strategies with health checks and automated rollback
metadata:
  version: 1.3
  argument-hint: "deployment type (blue-green/canary/rolling), platform, traffic split %, rollback trigger"
---

Implement deployment strategy for $ARGUMENTS.


## Strategy Selection

| Strategy | Risk | Rollback speed | Complexity | Best for |
|----------|------|----------------|------------|----------|
| Rolling update | Medium | Minutes | Low | Stateless services, small teams |
| Blue-green | Low | Seconds (DNS/LB switch) | Medium | Critical services, database migrations |
| Canary | Low | Seconds (traffic shift) | Medium-High | High-traffic services, risky changes |
| Progressive delivery | Lowest | Seconds (automated) | High | SaaS products, continuous deployment |
| Feature flags | Lowest | Instant (toggle) | Low-Medium | Decoupling deploy from release |

Decision guide:
- Simple stateless service, small team -> rolling update
- Critical service, needs instant rollback -> blue-green
- High traffic, want metric-based validation -> canary
- Continuous deployment with automated promotion -> progressive delivery (Flagger/Argo Rollouts)
- Decouple deployment from release -> feature flags + any strategy above

## Rolling Updates

### Kubernetes Rolling Update

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    spec:
      containers:
        - name: api
          image: registry.example.com/api:v2.4.1
          readinessProbe:
            httpGet: { path: /ready, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 3
          livenessProbe:
            httpGet: { path: /live, port: 8080 }
            initialDelaySeconds: 30
            periodSeconds: 10
          resources:
            requests: { cpu: 250m, memory: 256Mi }
            limits: { cpu: 500m, memory: 512Mi }
      terminationGracePeriodSeconds: 30
```

Rules: readiness probe must pass before traffic routes to the new pod; `terminationGracePeriodSeconds` must be long enough to drain in-flight requests; handle SIGTERM gracefully; monitor error rate during rollout.

### AWS ECS Rolling Update

```json
{
  "deploymentConfiguration": {
    "maximumPercent": 200,
    "minimumHealthyPercent": 100,
    "deploymentCircuitBreaker": { "enable": true, "rollback": true }
  }
}
```

`minimumHealthyPercent: 100` ensures no capacity reduction during deployment. The circuit breaker auto-rolls back on health check failures.

## Blue-Green Deployments

### Kubernetes Blue-Green with Service Selector

```yaml
# blue deployment (current live)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-blue
spec:
  replicas: 4
  selector:
    matchLabels: { app: api, version: blue }
  template:
    metadata:
      labels: { app: api, version: blue }
    spec:
      containers:
        - name: api
          image: registry.example.com/api:v2.3.0
---
# green deployment (new version, pre-verified)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-green
spec:
  replicas: 4
  selector:
    matchLabels: { app: api, version: green }
  template:
    metadata:
      labels: { app: api, version: green }
    spec:
      containers:
        - name: api
          image: registry.example.com/api:v2.4.0
---
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
    version: blue    # change to 'green' to switch traffic
  ports:
    - port: 80
      targetPort: 8080
```

### Blue-Green Procedure

1. Deploy green with the same replica count as blue
2. Run smoke tests against green directly (internal endpoint or port-forward)
3. Verify database migrations applied and health checks pass on all green pods
4. Switch service selector from blue to green (atomic traffic switch)
5. Monitor error rate, latency, and business metrics for 5-15 minutes
6. Healthy: scale down blue (keep for 1 hour as rollback target)
7. Unhealthy: switch selector back to blue (instant rollback)

### Azure App Service Deployment Slots

```bash
az webapp deployment source config-zip --resource-group mygroup --name myapp --slot staging --src app.zip
curl https://myapp-staging.azurewebsites.net/health
az webapp deployment slot swap --resource-group mygroup --name myapp --slot staging --target-slot production
# Rollback:
az webapp deployment slot swap --resource-group mygroup --name myapp --slot production --target-slot staging
```

Rules: green must have identical resource allocation as blue; run full smoke tests before switching; keep blue for at least 1 hour post-switch; database migrations must use expand-contract pattern; verify SSL certificates and secrets on green.

## Canary Deployments

### Traffic Splitting with Istio

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api
spec:
  hosts:
    - api.example.com
  http:
    - route:
        - destination: { host: api-stable, port: { number: 80 } }
          weight: 95
        - destination: { host: api-canary, port: { number: 80 } }
          weight: 5
```

### Traffic Splitting with NGINX Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "5"
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-canary
                port: { number: 80 }
```

### Canary Promotion Schedule

```
Stage 1:  1% traffic for 10 minutes  -> check error rate < baseline + 0.5%
Stage 2:  5% traffic for 15 minutes  -> check latency P95 < baseline * 1.5
Stage 3: 25% traffic for 30 minutes  -> check business metrics stable
Stage 4: 50% traffic for 30 minutes  -> check all metrics within thresholds
Stage 5: 100% traffic                -> canary is the new stable
```

### Metric-Based Promotion Criteria

| Metric | Threshold | Action if exceeded |
|--------|-----------|-------------------|
| Error rate (5xx) | > baseline + 1% | Rollback immediately |
| Latency P95 | > baseline * 2x | Pause, investigate |
| Latency P99 | > baseline * 3x | Rollback immediately |
| Success rate | < 99% | Pause promotion |
| CPU usage | > 80% of limit | Pause, investigate sizing |
| Memory usage | > 85% of limit | Pause, investigate memory leak |

## Progressive Delivery with Flagger

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: api
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  service:
    port: 80
    targetPort: 8080
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
      - name: request-success-rate
        thresholdRange: { min: 99 }
        interval: 1m
      - name: request-duration
        thresholdRange: { max: 500 }
        interval: 1m
    webhooks:
      - name: smoke-test
        type: pre-rollout
        url: http://smoke-tester.default/api/test
        timeout: 60s
      - name: load-test
        type: rollout
        url: http://load-tester.default/api/test
        timeout: 60s
```

Flagger flow: detects deployment change -> creates canary pods -> runs pre-rollout webhook -> shifts traffic in steps (10% -> 20% ... -> 50%) -> checks metrics at each step -> promotes or rolls back automatically.

## GitOps with ArgoCD

### Application Manifest

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/k8s-manifests.git
    targetRevision: main
    path: environments/production/api
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
    retry:
      limit: 3
      backoff: { duration: 5s, factor: 2, maxDuration: 1m }
```

### Argo Rollouts

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: api
spec:
  replicas: 4
  strategy:
    canary:
      canaryService: api-canary
      stableService: api-stable
      trafficRouting:
        istio:
          virtualService:
            name: api
            routes: [primary]
      steps:
        - setWeight: 5
        - pause: { duration: 10m }
        - setWeight: 20
        - pause: { duration: 10m }
        - setWeight: 50
        - pause: { duration: 15m }
        - setWeight: 80
        - pause: { duration: 10m }
      analysis:
        templates:
          - templateName: success-rate
        startingStep: 2
        args:
          - name: service-name
            value: api-canary
  template:
    spec:
      containers:
        - name: api
          image: registry.example.com/api:v2.4.0
```

### GitOps Rules

- All deployment configuration lives in Git — infrastructure as code
- Changes to production happen only via pull request to the manifests repo
- ArgoCD syncs automatically — no manual kubectl commands
- Use sealed secrets or external secrets operator for credentials
- Separate application code repo from deployment manifests repo
- Tag images with immutable identifiers (SHA, semver) — never use `:latest`

## Vercel Deployments

- Every branch push creates a preview deployment with a unique URL; merging to main triggers production
- Instant rollback: `vercel promote <deployment-url>` or via dashboard
- Enable skew protection to prevent mismatches when clients have cached old JavaScript bundles

## Health Check Gates

**Pre-deployment:** all pods pass readiness probe, migrations applied, smoke tests pass against new version, SSL certificates valid (not expiring within 30 days), feature flags in expected state.

**During deployment (each canary stage):** error rate and latency within thresholds, no pod restarts or OOM kills, CPU and memory within resource limits, custom business metrics stable.

**Post-deployment:** full smoke suite passes, synthetic monitoring confirms end-to-end flows, log pipeline receiving data, distributed tracing shows healthy spans, alert rules active.

## Rollback Procedures

```bash
# Kubernetes
kubectl rollout undo deployment/api -n production
kubectl rollout undo deployment/api -n production --to-revision=3
kubectl rollout history deployment/api -n production
```

```bash
#!/bin/bash
# rollback.sh <environment> <previous-version>
set -euo pipefail
ENVIRONMENT=$1
PREVIOUS_VERSION=$2

sed -i "s|image: .*|image: registry.example.com/api:$PREVIOUS_VERSION|" \
  "environments/$ENVIRONMENT/api/deployment.yaml"

git add . && git commit -m "rollback: $ENVIRONMENT to $PREVIOUS_VERSION" && git push origin main
kubectl rollout status deployment/api -n "$ENVIRONMENT" --timeout=300s
curl -sf "https://api.$ENVIRONMENT.example.com/health" || { echo "Health check failed"; exit 1; }
```

Rollback rules:
- Single command or automated trigger — no manual multi-step process
- Must complete within 2 minutes for container deployments
- Must preserve data written during the failed deployment
- Re-run smoke tests after rollback to confirm stability
- Document every rollback: trigger, duration, root cause, prevention plan
- Practice rollbacks regularly — untested procedures fail when needed

## Database Migration Coordination

Expand-contract pattern — never deploy breaking schema changes in a single deployment:
- Phase 1 (expand): deploy code that writes to both old and new schema
- Phase 2 (migrate): backfill data from old to new
- Phase 3 (contract): deploy code using only new schema, drop old columns

Rollback must work at every phase without data loss.

## Anti-Patterns

- Deploying migrations and code simultaneously — a failed migration blocks code rollback
- Rollback requiring migration reversal — use expand-contract to keep schema changes reversible
- No metric comparison between canary and stable — never promote based on "it looks fine"
- Skipping canary stages under time pressure — compressed timelines increase blast radius
- Deploying to all regions simultaneously — a bad deploy hits global traffic before detection

## Implementation Workflow

1. Identify the deployment target (Kubernetes, ECS, App Service, Vercel, bare Docker)
2. Select strategy based on service criticality and team capability
3. Configure health check endpoints (readiness, liveness, startup probes)
4. Define promotion criteria with specific metric thresholds
5. Set up traffic management (Istio, NGINX canary, service selector, DNS)
6. Implement automated rollback triggers
7. Configure GitOps sync (ArgoCD or Flux) for declarative deployments
8. Add pre/during/post deployment gates
9. Test the rollback procedure in staging
10. Document the deployment and rollback runbook

## Output Format

```
Service:            [name and type]
Strategy:           [rolling / blue-green / canary / progressive]
Platform:           [Kubernetes / ECS / App Service / Vercel]
Traffic Management: [Istio / NGINX / ALB / DNS / service selector]
Promotion Criteria: [metrics and thresholds per stage]
Rollback:           [trigger conditions and procedure]
GitOps:             [ArgoCD / Flux / manual apply]
Health Gates:       [pre / during / post checks]
Migration:          [database coordination approach]
```

## Done Criteria

- Deployment completes with zero downtime for end users
- Health check gates prevent unhealthy versions from receiving traffic
- Canary/progressive stages validate metrics before promotion
- Rollback executes in under 2 minutes and restores healthy state
- GitOps ensures all deployment state is version-controlled
- Database migrations use expand-contract pattern
- Post-deployment verification confirms the new version is healthy
- Rollback procedure is tested and documented
- Deployment runbook exists with step-by-step instructions
- Monitoring dashboards show deployment events correlated with metrics
