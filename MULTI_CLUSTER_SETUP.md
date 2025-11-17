# Multi-Cluster Deployment Setup Guide

This guide provides step-by-step instructions for setting up and testing the multi-cluster deployment system.

## Overview

The multi-cluster deployment architecture uses:
- **Management Cluster (`kind-mgmt`)**: Central ArgoCD control plane
- **Dev Cluster (`kind-dev`)**: Development environment for all teams
- **Prod Cluster (`kind-prod`)**: Production environment for all teams
- **ApplicationSets**: Auto-discover and deploy team apps to both clusters

## Prerequisites

- Docker
- Terraform
- kubectl
- Kind (Kubernetes in Docker)
- Helm 3

## Step 1: Create Infrastructure

### 1.1 Create Dev Cluster

```bash
cd infrastructure/dev
terraform init
terraform apply

# Note the outputs
terraform output kubeconfig_path
terraform output argocd_admin_password_command
```

### 1.2 Create Prod Cluster

```bash
cd ../prod
terraform init
terraform apply

# Note the outputs
terraform output kubeconfig_path
terraform output argocd_admin_password_command
```

### 1.3 Create Management Cluster

**IMPORTANT:** This step automatically registers dev and prod clusters with the management ArgoCD.

```bash
cd ../mgmt
terraform init
terraform apply

# This will:
# 1. Create the management cluster
# 2. Install ArgoCD
# 3. Read dev and prod cluster credentials from their Terraform state
# 4. Register both clusters with management ArgoCD

# View registered clusters
terraform output registered_clusters
```

## Step 2: Verify Cluster Registration

```bash
# Set context to management cluster
export KUBECONFIG=~/.kube/kind-kind-mgmt

# List cluster secrets
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster

# Expected output:
# cluster-kind-dev
# cluster-kind-prod

# Verify ArgoCD can reach clusters
kubectl exec -it -n argocd deployment/argocd-server -- argocd cluster list
```

**Troubleshooting:**
- If secrets are missing, check Terraform state files exist in dev/prod directories
- Run `terraform apply` again in mgmt directory
- Check logs: `kubectl logs -n argocd deployment/argocd-server`

## Step 3: Deploy ApplicationSet

```bash
# Still in management cluster context
export KUBECONFIG=~/.kube/kind-kind-mgmt

# Apply the team-apps ApplicationSet
kubectl apply -f k8s/argocd-appsets/team-apps.yaml

# Verify ApplicationSet was created
kubectl get applicationset -n argocd

# Check ApplicationSet status
kubectl get applicationset team-apps -n argocd -o yaml
```

## Step 4: Verify Application Generation

The ApplicationSet should automatically generate 4 Applications (2 apps × 2 environments):

```bash
# List all generated Applications
kubectl get applications -n argocd

# Expected Applications:
# - frontend-dev
# - frontend-prod
# - backend-dev
# - backend-prod

# Check sync status
kubectl get applications -n argocd -o wide

# View specific application
kubectl get application frontend-dev -n argocd -o yaml
```

**Troubleshooting:**
- If Applications not created, check ApplicationSet controller logs:
  ```bash
  kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller
  ```
- Verify Git directories exist: `ls k8s/team-apps/`
- Check ApplicationSet generators match repo structure

## Step 5: Monitor Deployment Progress

### Via kubectl

```bash
# Watch application sync status
watch kubectl get applications -n argocd

# Check specific application health
kubectl describe application team-a-dev -n argocd

# View sync errors (if any)
kubectl get application team-a-dev -n argocd -o jsonpath='{.status.conditions[*].message}'
```

### Via ArgoCD UI

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo

# Open ArgoCD UI
open http://localhost:30082

# Login:
# Username: admin
# Password: <from above command>

# Navigate to Applications
# You should see 4 applications in grid view
# Click each to see deployment details
```

## Step 6: Verify Deployments on Target Clusters

### Dev Cluster

```bash
# Switch to dev cluster
export KUBECONFIG=~/.kube/kind-kind-dev

# Check namespaces
kubectl get namespaces | grep -E 'frontend|backend'

# Expected:
# frontend
# backend

# Check pods
kubectl get pods -n frontend
kubectl get pods -n backend

# Expected: 1 replica each (dev environment)

# Check HTTPRoutes (frontend only - backend is internal)
kubectl get httproute -n frontend

# Check Gateway
kubectl get gateway -n istio-system cuddly-disco-gateway
```

### Prod Cluster

```bash
# Switch to prod cluster
export KUBECONFIG=~/.kube/kind-kind-prod

# Check namespaces
kubectl get namespaces | grep -E 'frontend|backend'

# Check pods
kubectl get pods -n frontend
kubectl get pods -n backend

# Expected: 3 replicas frontend, 2 replicas backend (prod environment)

# Check HTTPRoutes (frontend only - backend is internal)
kubectl get httproute -n frontend
```

## Step 7: Test Application Access

### Frontend Dev

```bash
# Test routing
curl -v -H "Host: dev.cuddly-disco.ai.localhost" http://localhost:3000/

# Expected: HTTP 200 with message from Development environment
```

### Frontend Prod

```bash
# Test routing
curl -v -H "Host: cuddly-disco.ai.localhost" http://localhost:3001/

# Expected: HTTP 200 with message from Sydney (Production)
```

### Backend (Internal Only)

```bash
# Backend is internal only, test from within a cluster pod
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://backend-service.backend.svc.cluster.local:5000/health

# Expected: {"status": "healthy"}
```

## Step 8: Test Adding a New Team App

The frontend and backend apps are now deployed. To test adding a new team application:

```bash
# Copy frontend as template for a new team app
cp -r k8s/team-apps/frontend k8s/team-apps/team-analytics

# Update config.yaml
sed -i 's/frontend/team-analytics/g' k8s/team-apps/team-analytics/config.yaml
sed -i 's/platform-team@example.com/analytics-team@example.com/g' k8s/team-apps/team-analytics/config.yaml
sed -i 's/#frontend-alerts/#analytics-alerts/g' k8s/team-apps/team-analytics/config.yaml
sed -i 's|routePath: /|routePath: /analytics|g' k8s/team-apps/team-analytics/config.yaml

# Update Chart.yaml
sed -i 's/frontend-app/team-analytics-app/g' k8s/team-apps/team-analytics/Chart.yaml
sed -i 's/Frontend/Team Analytics/g' k8s/team-apps/team-analytics/Chart.yaml

# Update values files
sed -i 's/teamName: frontend/teamName: team-analytics/g' k8s/team-apps/team-analytics/values.yaml
sed -i 's|routePath: /|routePath: /analytics|g' k8s/team-apps/team-analytics/values.yaml
sed -i 's/name: frontend/name: team-analytics/g' k8s/team-apps/team-analytics/values.yaml
sed -i 's/name: frontend-service/name: team-analytics-service/g' k8s/team-apps/team-analytics/values.yaml

# Update location values
sed -i 's/location: "Development"/location: "Analytics Dev"/g' k8s/team-apps/team-analytics/values-dev.yaml
sed -i 's/location: "Sydney"/location: "Analytics Team"/g' k8s/team-apps/team-analytics/values-prod.yaml

# Commit and push
git add k8s/team-apps/team-analytics
git commit -m "feat: Add team-analytics application"
git push

# Wait ~1 minute for ApplicationSet to detect changes
# Then check for new Applications
export KUBECONFIG=~/.kube/kind-kind-mgmt
kubectl get applications -n argocd -l team=team-analytics

# Expected:
# team-analytics-dev
# team-analytics-prod

# Test access
curl -H "Host: dev.cuddly-disco.ai.localhost" http://localhost:3000/analytics
```

## Verification Checklist

- [ ] Management cluster created and running
- [ ] Dev cluster created and running
- [ ] Prod cluster created and running
- [ ] Both clusters registered in management ArgoCD
- [ ] ApplicationSet deployed to management cluster
- [ ] 4 Applications auto-generated (frontend × 2, backend × 2)
- [ ] All Applications synced successfully
- [ ] Pods running in dev cluster (1 replica each)
- [ ] Pods running in prod cluster (frontend: 3 replicas, backend: 2 replicas)
- [ ] HTTPRoute created for frontend namespace
- [ ] Gateway API route working for frontend
- [ ] Frontend dev accessible at `/` on dev hostname
- [ ] Frontend prod accessible at `/` on prod hostname
- [ ] Backend accessible internally within cluster
- [ ] New team app auto-created when directory added

## Common Issues and Solutions

### Issue: Cluster secrets not created

**Symptom:** `kubectl get secrets -n argocd` shows no cluster secrets

**Solution:**
```bash
cd infrastructure/mgmt
terraform destroy -auto-approve
cd ../dev && terraform apply
cd ../prod && terraform apply
cd ../mgmt && terraform apply
```

### Issue: Applications not syncing

**Symptom:** Applications stuck in "OutOfSync" state

**Solution:**
```bash
# Check application health
kubectl describe application frontend-dev -n argocd

# Force sync
kubectl patch application frontend-dev -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
```

### Issue: HTTPRoute not working

**Symptom:** 404 when accessing frontend URL

**Solution:**
```bash
# Verify Gateway exists
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl get gateway -n istio-system

# Check HTTPRoute
kubectl get httproute -n frontend -o yaml

# Verify Gateway status
kubectl describe gateway -n istio-system cuddly-disco-gateway
```

### Issue: ApplicationSet not generating Applications

**Symptom:** `kubectl get applications -n argocd` shows no Applications

**Solution:**
```bash
# Check ApplicationSet logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller

# Verify Git repo is accessible
kubectl exec -it -n argocd deployment/argocd-server -- git ls-remote https://github.com/natosullivan/cuddly-disco.git

# Check ApplicationSet spec
kubectl get applicationset team-apps -n argocd -o yaml
```

## Cleanup

To tear down the entire infrastructure:

```bash
# Delete ApplicationSet (cascades to Applications)
export KUBECONFIG=~/.kube/kind-kind-mgmt
kubectl delete applicationset team-apps -n argocd

# Destroy clusters
cd infrastructure/mgmt && terraform destroy -auto-approve
cd ../prod && terraform destroy -auto-approve
cd ../dev && terraform destroy -auto-approve
```

## Next Steps

Once the multi-cluster deployment is working:

1. **Add CI/CD integration:** Update `.github/workflows/ci.yml` to update Helm charts on new releases
2. **Implement version pinning:** Use `config.yaml` version field to control `targetRevision`
3. **Add resource quotas:** Limit CPU/memory per team namespace
4. **Implement RBAC:** Restrict team access to their namespaces
5. **Add monitoring:** Deploy Prometheus/Grafana for observability
6. **Progressive delivery:** Integrate Argo Rollouts for canary deployments

## Reference

- **CLAUDE.md:** Complete documentation of multi-cluster patterns
- **k8s/team-apps/README.md:** Team onboarding guide
- **Terraform modules:** `infrastructure/modules/argocd-cluster-registration/`
- **ApplicationSet:** `k8s/argocd-appsets/team-apps.yaml`
