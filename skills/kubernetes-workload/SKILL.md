---
name: kubernetes-workload
description: Design and implement Kubernetes workload configurations including Deployments, Services, Ingress, HPA, PodDisruptionBudgets, network policies, Helm charts, Kustomize overlays, resource limits, probes, and RBAC
metadata:
  version: 1.2
  argument-hint: "workload type (Deployment/StatefulSet/Job), resource requirements, scaling needs, health probes, RBAC roles"
---

Design and implement Kubernetes workload configuration for $ARGUMENTS.


## Deployment Patterns

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  labels:
    app.kubernetes.io/name: api-server
    app.kubernetes.io/version: "1.2.0"
    app.kubernetes.io/managed-by: helm
spec:
  replicas: 3
  revisionHistoryLimit: 5
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: api-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: api-server
    spec:
      serviceAccountName: api-server
      securityContext:
        runAsNonRoot: true
        fsGroup: 1000
      terminationGracePeriodSeconds: 60
      containers:
        - name: api-server
          image: registry.example.com/api-server:1.2.0
          ports:
            - containerPort: 8080
              name: http
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: [ALL]
          env:
            - name: NODE_ENV
              value: production
          envFrom:
            - secretRef:
                name: api-server-secrets
            - configMapRef:
                name: api-server-config
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 10
            periodSeconds: 15
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
          startupProbe:
            httpGet:
              path: /healthz
              port: http
            failureThreshold: 30
            periodSeconds: 2
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

## Resource Management

| Workload Type | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---|---|---|---|---|
| API server | 100-250m | 500m-1 | 256-512Mi | 512Mi-1Gi |
| Worker/consumer | 50-200m | 500m | 128-256Mi | 512Mi |
| Background job | 50-100m | 250m | 64-128Mi | 256Mi |

Rules:
- Always set requests AND limits for memory
- CPU limits optional (consider removing if throttling causes latency spikes)
- Request:Limit ratio no wider than 1:4
- Use LimitRange for namespace defaults
- Use ResourceQuota for namespace caps

## Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-server
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-server
  minReplicas: 3
  maxReplicas: 20
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 120
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

## Pod Disruption Budgets

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-server
spec:
  minAvailable: 2  # or maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: api-server
```

Rules: every production Deployment with replicas > 1 MUST have a PDB. Use `minAvailable` for critical services, `maxUnavailable: 1` for most workloads.

## Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-server
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: api-server
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
      ports:
        - port: 8080
  egress:
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: postgres
      ports:
        - port: 5432
    - to:  # DNS
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - port: 53
          protocol: UDP
```

Default deny all, then allow specific paths. Always allow DNS egress.

## Helm Chart Structure

```
chart/
  Chart.yaml
  values.yaml
  values-staging.yaml
  values-production.yaml
  templates/
    _helpers.tpl
    deployment.yaml
    service.yaml
    ingress.yaml
    hpa.yaml
    pdb.yaml
    networkpolicy.yaml
    serviceaccount.yaml
    configmap.yaml
    secret.yaml (external-secrets or sealed-secrets)
```

Template patterns:
- Use `include` for reusable labels/selectors
- Always template image tag, replicas, resources
- Use `with` for optional sections
- Validate with `helm template . | kubeval`

## Kustomize Overlays

```
base/
  kustomization.yaml
  deployment.yaml
  service.yaml
overlays/
  staging/
    kustomization.yaml
    patches/
      replicas.yaml
      resources.yaml
  production/
    kustomization.yaml
    patches/
      replicas.yaml
      resources.yaml
      hpa.yaml
```

## Probes

| Probe | Purpose | Path | Timing |
|---|---|---|---|
| Startup | Wait for app init | /healthz | period 2s, failure 30 |
| Liveness | Restart if stuck | /healthz | period 15s, failure 3 |
| Readiness | Remove from LB | /ready | period 5s, failure 2 |

Liveness: check process is alive (basic). Readiness: check dependencies (DB, cache). Never make liveness depend on external services.

## RBAC

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-server
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::role/api-server  # IRSA
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: api-server
rules:
  - apiGroups: [""]
    resources: [configmaps, secrets]
    verbs: [get, list, watch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: api-server
subjects:
  - kind: ServiceAccount
    name: api-server
roleRef:
  kind: Role
  name: api-server
  apiGroup: rbac.authorization.k8s.io
```

Principle of least privilege. Always use ServiceAccount per workload.

## Scheduling

- `topologySpreadConstraints` for zone distribution
- `affinity.podAntiAffinity` to spread replicas across nodes
- `nodeSelector` or `nodeAffinity` for GPU/spot/dedicated nodes
- `tolerations` for tainted nodes (spot instances)
- `priorityClassName` for critical workloads

## ConfigMap and Secret Patterns

- Use `envFrom` for bulk injection
- Use `configMapKeyRef` for selective keys
- Mount secrets as volumes for files (TLS certs)
- Use External Secrets Operator or Sealed Secrets for GitOps
- Trigger rolling restart on config change: add `checksum/config` annotation

## Anti-Patterns

- Liveness probe depends on database — one DB hiccup cascades into pod restart loop
- No PDB — all pods evicted simultaneously during node drain or rolling update
- HPA without understanding baseline CPU/memory — oscillates between scale-up and scale-down
- Network policy with no DNS egress rule — pods silently fail to resolve service names

## Workflow

1. Detect existing K8s setup (Helm, Kustomize, raw manifests)
2. Design workload spec with security context, probes, resources
3. Add HPA if applicable (CPU/memory/custom metrics)
4. Add PDB for multi-replica workloads
5. Add NetworkPolicy for namespace isolation
6. Validate: `helm template`, `kubeval`, `kube-score`
7. Test: deploy to staging, verify probes, trigger scale events

Done: ✓ resource requests and limits set ✓ all three probes configured ✓ PDB for multi-replica workloads ✓ network policy restricts traffic ✓ RBAC with least privilege ✓ security context (non-root, read-only root, drop caps) ✓ HPA with stabilization windows ✓ topology spread for zone resilience ✓ no `latest` tags ✓ secrets managed securely
