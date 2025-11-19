# Infrastructure Deployment

This directory contains Terraform configurations and automation tools for deploying the cuddly-disco Kubernetes clusters.

## Quick Start

### Deploy All Clusters

```bash
# Deploy dev, prod, and mgmt clusters with multi-cluster mode
./deploy-clusters.sh
```

This single command will:
1. ✓ Create dev and prod clusters in parallel
2. ✓ Create mgmt cluster (registers dev/prod clusters)
3. ✓ Run infrastructure smoke tests on all clusters
4. ✓ Deploy ApplicationSet to mgmt cluster
5. ✓ Deploy applications to dev and prod via ArgoCD
6. ✓ Run application smoke tests to verify everything works
7. ✓ Print access information and credentials

### Deploy Infrastructure Only (No Apps)

```bash
# Deploy clusters but skip application deployment
./deploy-clusters.sh --skip-apps
```

### Deploy Specific Clusters

```bash
# Deploy only dev cluster
./deploy-clusters.sh --clusters dev

# Deploy dev and prod (skip mgmt)
./deploy-clusters.sh --exclude mgmt

# Deploy only mgmt cluster
./deploy-clusters.sh --clusters mgmt
```

### Single-Cluster Mode

```bash
# Deploy apps directly to each cluster (not via mgmt ApplicationSet)
./deploy-clusters.sh --mode single
```

## Directory Structure

```
infrastructure/
├── deploy-clusters.sh           # Main deployment automation tool
├── dev/                         # Dev cluster Terraform config
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── terraform.tfvars
├── prod/                        # Prod cluster Terraform config
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── terraform.tfvars
├── mgmt/                        # Management cluster Terraform config
│   ├── main.tf
│   ├── clusters.tf              # Registers dev/prod clusters
│   ├── outputs.tf
│   ├── provider.tf              # ArgoCD provider
│   ├── variables.tf
│   └── terraform.tfvars
├── modules/                     # Reusable Terraform modules
│   ├── k8s/                     # Kind cluster module
│   ├── argocd/                  # ArgoCD installation module
│   └── istio/                   # Istio + Gateway API module
└── smoke-tests/                 # Smoke test framework
    ├── run-smoke-tests.sh       # Test runner
    ├── lib/                     # Helper libraries
    │   ├── assertions.sh        # Test assertions
    │   └── k8s-helpers.sh       # Kubernetes utilities
    └── tests/                   # Test scripts
        ├── 01-cluster-health.sh
        ├── 02-argocd-health.sh
        ├── 03-istio-health.sh
        └── 04-app-deployment.sh
```

## Deployment Tool Options

### Command Line Flags

| Flag | Description | Example |
|------|-------------|---------|
| `--clusters <list>` | Deploy specific clusters (comma-separated) | `--clusters dev,prod` |
| `--exclude <list>` | Exclude clusters from deployment | `--exclude mgmt` |
| `--mode <mode>` | ArgoCD mode: `multi` or `single` | `--mode single` |
| `--skip-apps` | Skip application deployment | `--skip-apps` |
| `--infra-only` | Same as --skip-apps | `--infra-only` |
| `--help`, `-h` | Show help message | `--help` |

### Deployment Modes

**Multi-Cluster Mode (Default):**
- Management cluster (mgmt) deploys apps to dev and prod
- Uses ApplicationSet pattern
- GitOps hub-spoke architecture
- Best for production environments

**Single-Cluster Mode:**
- Apps deployed directly to each cluster's ArgoCD
- Each cluster is independent
- Simpler setup for development

## Smoke Tests

### Manual Test Execution

```bash
# Test specific cluster
cd smoke-tests
./run-smoke-tests.sh kind-dev

# Test all clusters
./run-smoke-tests.sh all

# Test with specific deployment mode
DEPLOYMENT_MODE=single ./run-smoke-tests.sh kind-dev
```

### Test Coverage

**Test 01: Cluster Health**
- kubectl connectivity
- Node status
- kube-system pods
- CoreDNS

**Test 02: ArgoCD Health**
- ArgoCD namespace and pods
- ArgoCD server accessibility
- Admin credentials

**Test 03: Istio Health** (dev/prod only)
- Istio components
- Gateway API CRDs
- Gateway resource status

**Test 04: Application Deployment**
- ArgoCD application sync status
- Backend deployment and API endpoints
- Frontend deployment and accessibility
- End-to-end connectivity

## Cluster Information

### Dev Cluster (kind-dev)

- **Kubeconfig:** `~/.kube/kind-kind-dev`
- **ArgoCD UI:** http://localhost:30080
- **Frontend:** http://dev.cuddly-disco.ai.localhost:3000
- **Gateway Port:** 3000 (NodePort 30001 → host 3000)
- **Resources:** 1 control-plane node

```bash
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl get pods -A
```

### Prod Cluster (kind-prod)

- **Kubeconfig:** `~/.kube/kind-kind-prod`
- **ArgoCD UI:** http://localhost:30081
- **Frontend:** http://cuddly-disco.ai.localhost:3001
- **Gateway Port:** 3001 (NodePort 30001 → host 3001)
- **Resources:** 1 control-plane node

```bash
export KUBECONFIG=~/.kube/kind-kind-prod
kubectl get pods -A
```

### Management Cluster (kind-mgmt)

- **Kubeconfig:** `~/.kube/kind-kind-mgmt`
- **ArgoCD UI:** http://localhost:30082
- **Resources:** 1 control-plane node
- **Registers:** Dev and prod clusters

```bash
export KUBECONFIG=~/.kube/kind-kind-mgmt
kubectl get applications -n argocd
```

## How It Works

### Cluster Creation Order

The deployment tool respects dependencies:

1. **Phase 1:** Dev and prod clusters (parallel)
   - Independent of each other
   - Can be created simultaneously
   - Include ArgoCD + Istio + Gateway API

2. **Phase 2:** Infrastructure smoke tests
   - Validates cluster health
   - Checks ArgoCD installation
   - Verifies Istio and Gateway

3. **Phase 3:** Management cluster (sequential)
   - Depends on dev/prod terraform state files
   - Registers dev/prod as remote clusters
   - Includes ArgoCD only (no Istio)

4. **Phase 4:** Application deployment
   - Multi-mode: ApplicationSet to mgmt
   - Single-mode: Apps to each cluster
   - Backend deployed before frontend

5. **Phase 5:** Application smoke tests
   - Validates ArgoCD sync status
   - Tests API endpoints
   - Verifies frontend accessibility

### Existing Cluster Detection

The tool automatically detects existing clusters:

```bash
# If cluster container exists:
#   - Skips terraform apply
#   - Runs smoke tests only
#   - Continues to next phase

# If cluster container doesn't exist:
#   - Runs terraform init + apply
#   - Creates fresh cluster
#   - Runs smoke tests
```

This makes the tool idempotent - you can run it multiple times safely.

## Troubleshooting

### Get ArgoCD Admin Password

```bash
# Dev cluster
cd dev && eval $(terraform output -raw argocd_admin_password_command)

# Prod cluster
cd prod && eval $(terraform output -raw argocd_admin_password_command)

# Management cluster
cd mgmt && eval $(terraform output -raw argocd_admin_password_command)
```

### Check Cluster Status

```bash
# List running clusters
docker ps | grep kind

# Check kubeconfig files
ls -la ~/.kube/kind-*

# Test cluster connectivity
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl cluster-info
```

### View ArgoCD Applications

```bash
# Single-cluster mode
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl get applications -n argocd

# Multi-cluster mode
export KUBECONFIG=~/.kube/kind-kind-mgmt
kubectl get applications -n argocd
kubectl get applicationset -n argocd
```

### Check Application Pods

```bash
export KUBECONFIG=~/.kube/kind-kind-dev

# Backend
kubectl get pods -n cuddly-disco-backend
kubectl logs -n cuddly-disco-backend -l app=backend

# Frontend
kubectl get pods -n cuddly-disco-frontend
kubectl logs -n cuddly-disco-frontend -l app=frontend
```

### Test Endpoints

```bash
# Frontend via Gateway (dev)
curl -H "Host: dev.cuddly-disco.ai.localhost" http://localhost:3000

# Frontend via Gateway (prod)
curl -H "Host: cuddly-disco.ai.localhost" http://localhost:3001

# Backend (via port-forward)
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl port-forward -n cuddly-disco-backend svc/backend-service 5000:5000
curl http://localhost:5000/health
curl http://localhost:5000/api/message
```

### Force Cluster Recreate

```bash
# Destroy specific cluster
cd dev && terraform destroy -auto-approve

# Or use kind directly
kind delete cluster --name kind-dev

# Then re-run deployment
cd .. && ./deploy-clusters.sh --clusters dev
```

### View Deployment Logs

```bash
# Run with verbose output
cd dev && terraform apply

# Check smoke test output
cd smoke-tests && ./run-smoke-tests.sh kind-dev
```

## Manual Terraform Commands

If you prefer manual control:

```bash
# Create dev cluster
cd dev
terraform init
terraform apply
eval $(terraform output -raw argocd_admin_password_command)

# Create prod cluster
cd ../prod
terraform init
terraform apply

# Create mgmt cluster (after dev/prod)
cd ../mgmt
terraform init -upgrade  # Upgrades ArgoCD provider
terraform apply

# Destroy clusters (reverse order)
cd ../mgmt && terraform destroy
cd ../prod && terraform destroy
cd ../dev && terraform destroy
```

## Common Workflows

### Fresh Deployment

```bash
# Deploy everything from scratch
./deploy-clusters.sh
```

### Update Only Applications

```bash
# Infrastructure exists, just update apps
./deploy-clusters.sh  # Detects existing clusters, deploys apps
```

### Test Without Apps

```bash
# Validate infrastructure only
./deploy-clusters.sh --skip-apps
```

### Dev Environment Only

```bash
# Just dev cluster for local testing
./deploy-clusters.sh --clusters dev --mode single
```

### Progressive Deployment

```bash
# Step 1: Deploy infrastructure
./deploy-clusters.sh --exclude mgmt --infra-only

# Step 2: Verify infrastructure
cd smoke-tests && ./run-smoke-tests.sh kind-dev
cd smoke-tests && ./run-smoke-tests.sh kind-prod

# Step 3: Deploy mgmt and apps
./deploy-clusters.sh --clusters mgmt
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DEPLOYMENT_MODE` | ArgoCD mode (multi/single) | `multi` |
| `KUBECONFIG` | Path to kubeconfig | Auto-set per cluster |

## Requirements

- Docker
- kubectl
- Terraform
- bash 4.0+

## Additional Resources

- [CLAUDE.md](../CLAUDE.md) - Full project documentation
- [k8s/](../k8s/) - Helm charts and ArgoCD apps
- [smoke-tests/](smoke-tests/) - Test framework details
