# Backend Helm Chart

This Helm chart deploys the cuddly-disco backend API to Kubernetes.

## Prerequisites

- Kubernetes cluster (Kind, EKS, GKE, AKS, etc.)
- Helm 3.x
- kubectl configured to access the cluster

## Installation

### Install the chart

```bash
# Install with default values
helm install backend ./k8s/backend

# Install with custom values
helm install backend ./k8s/backend \
  --set image.tag=v1.1.0 \
  --set replicaCount=3

# Install from values file
helm install backend ./k8s/backend -f my-values.yaml

# Install to specific namespace
helm install backend ./k8s/backend --namespace cuddly-disco-backend --create-namespace
```

### Upgrade the chart

```bash
# Upgrade with new values
helm upgrade backend ./k8s/backend \
  --set image.tag=v1.2.0

# Upgrade with values file
helm upgrade backend ./k8s/backend -f my-values.yaml
```

### Uninstall the chart

```bash
helm uninstall backend --namespace cuddly-disco-backend
```

## Configuration

### Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of backend replicas | `2` |
| `image.repository` | Container image repository | `ghcr.io/natosullivan/cuddly-disco/backend` |
| `image.tag` | Container image tag | `v1.0.0` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `namespace.name` | Namespace to deploy to | `cuddly-disco-backend` |
| `namespace.create` | Create namespace if it doesn't exist | `true` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `5000` |
| `resources.limits.cpu` | CPU limit | `200m` |
| `resources.limits.memory` | Memory limit | `256Mi` |
| `resources.requests.cpu` | CPU request | `50m` |
| `resources.requests.memory` | Memory request | `64Mi` |

### Service Type

The backend uses **ClusterIP** service type by default, which means:
- ✅ Accessible only from within the Kubernetes cluster
- ✅ Not exposed to external traffic
- ✅ Frontend pods can access via DNS: `backend-service.cuddly-disco-backend.svc.cluster.local:5000`

This ensures the backend API is not directly accessible from outside the cluster.

### Example values files

**Production values** (`values-prod.yaml`):
```yaml
replicaCount: 3

image:
  tag: v1.2.0
  pullPolicy: IfNotPresent

resources:
  limits:
    cpu: 500m
    memory: 512Mi
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
```

## Usage with ArgoCD

The chart is designed to work seamlessly with ArgoCD for GitOps deployment.

### ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backend
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/natosullivan/cuddly-disco
    targetRevision: main
    path: k8s/backend
    helm:
      valueFiles:
      - values.yaml

  destination:
    server: https://kubernetes.default.svc
    namespace: cuddly-disco-backend

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Chart Structure

```
k8s/backend/
├── Chart.yaml           # Chart metadata
├── values.yaml          # Default configuration values
├── README.md            # This file
└── templates/
    ├── _helpers.tpl     # Template helpers
    ├── namespace.yaml   # Namespace resource
    ├── deployment.yaml  # Deployment resource
    └── service.yaml     # Service resource (ClusterIP)
```

## Development

### Template the chart locally

```bash
# See what Helm will generate
helm template backend ./k8s/backend

# See with custom values
helm template backend ./k8s/backend --set image.tag=v2.0.0

# Output to file
helm template backend ./k8s/backend > rendered.yaml
```

### Validate the chart

```bash
# Lint the chart
helm lint ./k8s/backend

# Dry-run install
helm install backend ./k8s/backend --dry-run --debug
```

### Package the chart

```bash
# Package for distribution
helm package ./k8s/backend

# Creates: backend-0.1.0.tgz
```

## Accessing the Backend

The backend is **not exposed externally** by design. It can only be accessed from within the cluster.

### From Frontend Pods

The frontend accesses the backend via Kubernetes DNS:
```
http://backend-service.cuddly-disco-backend.svc.cluster.local:5000
```

### From kubectl (for testing)

```bash
# Port-forward to local machine
kubectl port-forward -n cuddly-disco-backend svc/backend-service 5000:5000

# Test locally
curl http://localhost:5000/health
curl http://localhost:5000/api/message
```

### From a debug pod

```bash
# Run a temporary pod for testing
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh

# Inside the pod:
curl http://backend-service.cuddly-disco-backend.svc.cluster.local:5000/health
```

## Troubleshooting

### Check pod logs

```bash
kubectl logs -n cuddly-disco-backend -l app=backend
```

### Check events

```bash
kubectl get events -n cuddly-disco-backend --sort-by='.lastTimestamp'
```

### Describe resources

```bash
kubectl describe deployment backend -n cuddly-disco-backend
kubectl describe pod -n cuddly-disco-backend <pod-name>
```

### Check service

```bash
kubectl get svc -n cuddly-disco-backend
kubectl describe svc backend-service -n cuddly-disco-backend
```

### Test connectivity from frontend

```bash
# Get a frontend pod
kubectl get pods -n cuddly-disco-frontend

# Exec into frontend pod
kubectl exec -it -n cuddly-disco-frontend <frontend-pod-name> -- sh

# Test backend connection
curl http://backend-service.cuddly-disco-backend.svc.cluster.local:5000/health
```

## Notes

- The backend uses ClusterIP service - **not accessible from outside the cluster**
- Only pods within the Kubernetes cluster can access the backend
- The frontend is configured to use the backend's DNS name
- Health probes ensure pods are ready before receiving traffic
- Resource limits prevent pods from consuming excessive resources
