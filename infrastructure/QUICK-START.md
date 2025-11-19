# Quick Start Guide

## Deploy Everything (Recommended)

```bash
cd infrastructure
./deploy-clusters.sh
```

**What this does:**
1. Creates dev and prod clusters (parallel)
2. Creates mgmt cluster
3. Runs infrastructure tests
4. Deploys apps via ApplicationSet
5. Runs application tests
6. Shows access URLs and credentials

**Duration:** ~5-10 minutes

---

## Common Commands

### Deploy Only Infrastructure

```bash
./deploy-clusters.sh --skip-apps
```

### Deploy Single Cluster

```bash
./deploy-clusters.sh --clusters dev
```

### Skip Management Cluster

```bash
./deploy-clusters.sh --exclude mgmt
```

### Single-Cluster Mode

```bash
./deploy-clusters.sh --mode single
```

---

## Access Information

### Dev Cluster

```bash
export KUBECONFIG=~/.kube/kind-kind-dev

# Get ArgoCD password
cd dev && eval $(terraform output -raw argocd_admin_password_command)

# Access URLs
# ArgoCD: http://localhost:30080
# Frontend: http://dev.cuddly-disco.ai.localhost:3000
```

### Prod Cluster

```bash
export KUBECONFIG=~/.kube/kind-kind-prod

# Get ArgoCD password
cd prod && eval $(terraform output -raw argocd_admin_password_command)

# Access URLs
# ArgoCD: http://localhost:30081
# Frontend: http://cuddly-disco.ai.localhost:3001
```

### Management Cluster

```bash
export KUBECONFIG=~/.kube/kind-kind-mgmt

# Get ArgoCD password
cd mgmt && eval $(terraform output -raw argocd_admin_password_command)

# Access URLs
# ArgoCD: http://localhost:30082
```

---

## Verification Commands

### Check Cluster Status

```bash
docker ps | grep kind
```

### Check ArgoCD Applications

```bash
export KUBECONFIG=~/.kube/kind-kind-mgmt
kubectl get applications -n argocd
```

### Check Deployed Pods

```bash
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl get pods -n cuddly-disco-backend
kubectl get pods -n cuddly-disco-frontend
```

### Test Frontend

```bash
# Dev
curl -H "Host: dev.cuddly-disco.ai.localhost" http://localhost:3000

# Prod
curl -H "Host: cuddly-disco.ai.localhost" http://localhost:3001
```

### Run Smoke Tests

```bash
cd smoke-tests
./run-smoke-tests.sh all
```

---

## Cleanup

### Destroy All Clusters

```bash
# Destroy in reverse order
cd mgmt && terraform destroy -auto-approve
cd ../prod && terraform destroy -auto-approve
cd ../dev && terraform destroy -auto-approve

# Or use kind directly
kind delete cluster --name kind-mgmt
kind delete cluster --name kind-prod
kind delete cluster --name kind-dev
```

---

## Troubleshooting

### Cluster Won't Start

```bash
# Check Docker
docker ps

# Check kubeconfig
ls -la ~/.kube/kind-*

# Recreate cluster
cd dev && terraform destroy && terraform apply
```

### Apps Not Syncing

```bash
# Check ArgoCD
export KUBECONFIG=~/.kube/kind-kind-mgmt
kubectl get applications -n argocd

# Force sync
kubectl patch application frontend-dev -n argocd \
  --type merge -p '{"operation":{"sync":{}}}'
```

### Can't Access Frontend

```bash
# Check Gateway
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl get gateway -n istio-system
kubectl get httproute -n cuddly-disco-frontend

# Check pods
kubectl get pods -n cuddly-disco-frontend
kubectl logs -n cuddly-disco-frontend -l app=frontend
```

---

## Next Steps

- View full documentation: [README.md](README.md)
- Understand project structure: [../CLAUDE.md](../CLAUDE.md)
- Explore smoke tests: [smoke-tests/](smoke-tests/)
- Review Helm charts: [../k8s/](../k8s/)
