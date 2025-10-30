# Frontend Helm Chart

This Helm chart deploys the cuddly-disco frontend application to Kubernetes.

## Prerequisites

- Kubernetes cluster (Kind, EKS, GKE, AKS, etc.)
- Helm 3.x
- kubectl configured to access the cluster

## Installation

### Install the chart

```bash
# Install with default values
helm install frontend ./k8s/frontend

# Install with custom values
helm install frontend ./k8s/frontend \
  --set image.tag=v1.1.0 \
  --set replicaCount=3

# Install from values file
helm install frontend ./k8s/frontend -f my-values.yaml

# Install to specific namespace
helm install frontend ./k8s/frontend --namespace cuddly-disco-frontend --create-namespace
```

### Upgrade the chart

```bash
# Upgrade with new values
helm upgrade frontend ./k8s/frontend \
  --set image.tag=v1.2.0

# Upgrade with values file
helm upgrade frontend ./k8s/frontend -f my-values.yaml
```

### Uninstall the chart

```bash
helm uninstall frontend --namespace cuddly-disco-frontend
```

## Configuration

### Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of frontend replicas | `2` |
| `image.repository` | Container image repository | `ghcr.io/natosullivan/cuddly-disco/frontend` |
| `image.tag` | Container image tag | `v1.0.0` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `namespace.name` | Namespace to deploy to | `cuddly-disco-frontend` |
| `namespace.create` | Create namespace if it doesn't exist | `true` |
| `service.type` | Kubernetes service type | `NodePort` |
| `service.port` | Service port | `80` |
| `service.nodePort` | NodePort (if type is NodePort) | `30001` |
| `config.viteLocation` | Location displayed in app | `"Kubernetes Dev"` |
| `config.viteBackendUrl` | Backend API URL | `"http://backend-service.cuddly-disco-backend.svc.cluster.local:5000"` |
| `resources.limits.cpu` | CPU limit | `100m` |
| `resources.limits.memory` | Memory limit | `128Mi` |
| `resources.requests.cpu` | CPU request | `50m` |
| `resources.requests.memory` | Memory request | `64Mi` |

### Example values files

**Production values** (`values-prod.yaml`):
```yaml
replicaCount: 3

image:
  tag: v1.2.0
  pullPolicy: IfNotPresent

service:
  type: LoadBalancer
  nodePort: null

config:
  viteLocation: "Production - US East"
  viteBackendUrl: "http://backend-service.cuddly-disco-backend.svc.cluster.local:5000"

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

**Development values** (`values-dev.yaml`):
```yaml
replicaCount: 1

image:
  tag: latest
  pullPolicy: Always

config:
  viteLocation: "Development"
  viteBackendUrl: "http://backend-service.cuddly-disco-backend.svc.cluster.local:5000"
```

## Usage with ArgoCD

The chart is designed to work seamlessly with ArgoCD for GitOps deployment.

### ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/natosullivan/cuddly-disco
    targetRevision: main
    path: k8s/frontend
    helm:
      valueFiles:
      - values.yaml
      # Optional overrides
      values: |
        replicaCount: 3
        image:
          tag: v1.2.0

  destination:
    server: https://kubernetes.default.svc
    namespace: cuddly-disco-frontend

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Chart Structure

```
k8s/frontend/
├── Chart.yaml           # Chart metadata
├── values.yaml          # Default configuration values
├── README.md            # This file
└── templates/
    ├── _helpers.tpl     # Template helpers
    ├── namespace.yaml   # Namespace resource
    ├── configmap.yaml   # ConfigMap for env vars
    ├── deployment.yaml  # Deployment resource
    └── service.yaml     # Service resource
```

## Development

### Template the chart locally

```bash
# See what Helm will generate
helm template frontend ./k8s/frontend

# See with custom values
helm template frontend ./k8s/frontend --set image.tag=v2.0.0

# Output to file
helm template frontend ./k8s/frontend > rendered.yaml
```

### Validate the chart

```bash
# Lint the chart
helm lint ./k8s/frontend

# Dry-run install
helm install frontend ./k8s/frontend --dry-run --debug
```

### Package the chart

```bash
# Package for distribution
helm package ./k8s/frontend

# Creates: frontend-0.1.0.tgz
```

## Accessing the Frontend

After installation:

```bash
# Check deployment status
kubectl get pods -n cuddly-disco-frontend

# Get service details
kubectl get svc -n cuddly-disco-frontend

# For NodePort (Kind/local):
# Access at http://localhost:3000 (mapped via Kind)

# For LoadBalancer (cloud):
kubectl get svc frontend-service -n cuddly-disco-frontend
# Use EXTERNAL-IP
```

## Troubleshooting

### Check pod logs

```bash
kubectl logs -n cuddly-disco-frontend -l app=frontend
```

### Check events

```bash
kubectl get events -n cuddly-disco-frontend --sort-by='.lastTimestamp'
```

### Describe resources

```bash
kubectl describe deployment frontend -n cuddly-disco-frontend
kubectl describe pod -n cuddly-disco-frontend <pod-name>
```

### Verify ConfigMap

```bash
kubectl get configmap -n cuddly-disco-frontend
kubectl describe configmap frontend-config -n cuddly-disco-frontend
```

## Notes

- The chart automatically creates the namespace if it doesn't exist
- ConfigMap changes trigger pod restarts via checksum annotation
- Health probes ensure pods are ready before receiving traffic
- Resource limits prevent pods from consuming excessive resources
