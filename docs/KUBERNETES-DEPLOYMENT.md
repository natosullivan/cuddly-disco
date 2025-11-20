# Kubernetes Deployment Guide

This document describes how to deploy cuddly-disco to Kubernetes using ArgoCD for GitOps-based continuous delivery.

## Table of Contents

- [Infrastructure as Code](#infrastructure-as-code)
- [Kubernetes Manifests](#kubernetes-manifests)
- [Single-Cluster Deployment](#single-cluster-deployment)
- [Multi-Cluster Deployment](#multi-cluster-deployment)
- [Multi-Version Deployment](#multi-version-deployment)
- [Accessing Services](#accessing-services)
- [Troubleshooting](#troubleshooting)
- [Key Kubernetes Concepts](#key-kubernetes-concepts)

---

## Infrastructure as Code

### Terraform Modules (`infrastructure/modules/`)

**k8s Module:**
- Creates Kind (Kubernetes in Docker) clusters locally
- Configurable node count, Kubernetes version, port mappings
- Auto-generates kubeconfig at `~/.kube/kind-{cluster-name}`
- Default port mappings: 30080 (ArgoCD UI), 30001 (Gateway API → host 3000)

**argocd Module:**
- Installs ArgoCD via Helm chart
- NodePort service for local access
- Insecure mode for development (no TLS)
- ApplicationSet controller enabled

**istio Module:**
- Installs Istio and Gateway API for ingress
- Installs Gateway API CRDs
- Installs Istio base, istiod, and gateway charts
- Creates Gateway resource with configurable hostname
- Gateway-only mode (no service mesh/sidecar injection)
- Gateway API automatically provisions infrastructure on NodePort 30001

### Environment Configurations

**Dev Environment (`infrastructure/dev/`):**
- Creates single-node Kind cluster (control-plane only)
- Installs ArgoCD automatically (insecure mode)
- Installs Istio with Gateway hostname: `dev.cuddly-disco.ai.localhost`
- Port mappings:
  - ArgoCD UI: NodePort 30080 → host 30080
  - Gateway API: NodePort 30001 → host 3000

**Prod Environment (`infrastructure/prod/`):**
- Creates multi-node Kind cluster (1 control-plane + 2 workers)
- Installs ArgoCD automatically (TLS enabled)
- Installs Istio with Gateway hostname: `cuddly-disco.ai.localhost`
- Port mappings (different from dev to avoid conflicts):
  - ArgoCD UI: NodePort 30080 → host 30081
  - Gateway API: NodePort 30001 → host 3001
- Production-ready configuration for local testing

**LocalDev Environment (`infrastructure/localdev/`):**
- Creates single-node Kind cluster (control-plane only)
- **No ArgoCD** - Optimized for direct kubectl/helm deployment
- Installs Istio with Gateway hostname: `localdev.cuddly-disco.ai.localhost`
- Port mappings (avoids conflicts with other clusters):
  - Gateway API: NodePort 30001 → host 8080
- Personal development sandbox for direct deployment testing
- Use for local experimentation without GitOps automation

### Terraform Commands

```bash
# Dev environment
cd infrastructure/dev
terraform init
terraform plan
terraform apply

# Get ArgoCD admin password
eval $(terraform output -raw argocd_admin_password_command)

# Access ArgoCD UI
open http://localhost:30080  # Login: admin/<password>

# Prod environment
cd infrastructure/prod
terraform init
terraform plan
terraform apply

# Access ArgoCD UI (prod)
open http://localhost:30081  # Login: admin/<password>

# LocalDev environment (no ArgoCD)
cd infrastructure/localdev
terraform init
terraform plan
terraform apply

# Configure kubectl for localdev
export KUBECONFIG=~/.kube/kind-kind-localdev

# Deploy directly with kubectl or helm
kubectl apply -f your-manifest.yaml
helm install myapp path/to/chart
```

---

## Kubernetes Manifests

### Frontend Helm Chart (`k8s/frontend/`)

The frontend is deployed using a Helm chart for better configurability and reusability.

**Chart Structure:**
- `Chart.yaml` - Chart metadata (version 0.1.0, appVersion 1.0.0)
- `values.yaml` - Default configuration values
  - `replicaCount: 2` - Number of pod replicas
  - `image.repository` - Container image location
  - `image.tag: v1.0.0` - Semantic version tag
  - `config.location` - Location displayed in app
  - `config.backendUrl` - Backend service URL (internal Kubernetes DNS)
  - `service.type: ClusterIP` - Internal service (accessed via Gateway)
  - `service.port: 3000` - Next.js server port
  - `gateway.hostname` - Hostname for HTTPRoute (environment-specific)
  - `gateway.name` - Gateway resource name in istio-system
  - Resource limits and requests
  - **Health probe configurations:**
    - `startupProbe` - 60s grace period for initial startup (prevents CrashLoopBackOff)
    - `livenessProbe` - Restarts unhealthy pods
    - `readinessProbe` - Routes traffic only to ready pods
- `templates/` - Kubernetes resource templates
  - `_helpers.tpl` - Template helper functions
  - `namespace.yaml` - Creates cuddly-disco-frontend namespace
  - `configmap.yaml` - Environment variables ConfigMap (LOCATION, BACKEND_URL)
  - `deployment.yaml` - Deployment with 2 replicas, health probes at `/api/health`
  - `service.yaml` - ClusterIP service on port 3000
  - `httproute.yaml` - Gateway API HTTPRoute for external access

**Key Helm Features:**
- Configurable via `values.yaml` or command-line overrides
- Template helpers for consistent naming and labels
- ConfigMap checksum triggers pod restarts on config changes
- Automatic namespace creation
- Support for different environments (dev, staging, prod)
- **Next.js SSR** for server-side rendering and direct backend communication

### Backend Helm Chart (`k8s/backend/`)

The backend API is deployed using a Helm chart with internal-only access.

**Chart Structure:**
- `Chart.yaml` - Chart metadata (version 0.1.0, appVersion 1.0.0)
- `values.yaml` - Default configuration values
  - `replicaCount: 2` - Number of pod replicas
  - `image.repository` - Container image location
  - `image.tag: v1.0.0` - Semantic version tag
  - `service.type: ClusterIP` - Internal-only service (not exposed externally)
  - `service.port: 5000` - Internal service port
  - Resource limits and requests
  - Health probe configurations
- `templates/` - Kubernetes resource templates
  - `_helpers.tpl` - Template helper functions
  - `namespace.yaml` - Creates cuddly-disco-backend namespace
  - `deployment.yaml` - Deployment with 2 replicas, health probes
  - `service.yaml` - ClusterIP service (internal only)

**Key Backend Features:**
- **ClusterIP service** - Not accessible from outside the cluster
- Only accessible via Kubernetes DNS: `backend-service.cuddly-disco-backend.svc.cluster.local:5000`
- Next.js frontend makes server-side calls to backend using internal DNS name
- No external exposure for security - users cannot directly access the backend API

### Frontend-Backend Connectivity

The architecture uses Kubernetes Gateway API for external access and Next.js SSR for backend communication:

1. User's browser requests `http://dev.cuddly-disco.ai.localhost:3000` (dev) or `http://cuddly-disco.ai.localhost:3001` (prod)
2. Request hits Gateway API gateway (NodePort 30001 mapped to host port 3000 for dev, 3001 for prod)
3. HTTPRoute routes request to frontend ClusterIP service on port 3000
4. Next.js Server Component executes on the server before rendering
5. Server Component makes direct API call to `http://backend-service.cuddly-disco-backend.svc.cluster.local:5000/api/message`
6. Backend responds to Next.js server (server-to-server, not exposed to browser)
7. Next.js server renders the page with backend data and sends complete HTML to browser
8. Backend service remains ClusterIP - inaccessible from outside the cluster
9. No client-side API calls or loading states - everything is pre-rendered

### ArgoCD Applications (`k8s/argocd-apps/`)

**frontend-app.yaml** - Frontend ArgoCD Application for **prod** environment:
- Source: GitHub repository, main branch, path: k8s/frontend
- Helm: Uses values.yaml from chart (hostname: cuddly-disco.ai.localhost)
- Destination: cuddly-disco-frontend namespace
- Sync policy: Automated with prune and selfHeal enabled

**frontend-app-dev.yaml** - Frontend ArgoCD Application for **dev** environment:
- Source: GitHub repository, main branch, path: k8s/frontend
- Helm: Overrides gateway.hostname to dev.cuddly-disco.ai.localhost
- Destination: cuddly-disco-frontend namespace
- Sync policy: Automated with prune and selfHeal enabled

**backend-app.yaml** - Backend ArgoCD Application (same for all environments):
- Source: GitHub repository, main branch, path: k8s/backend
- Helm: Uses values.yaml from chart, supports value overrides
- Destination: cuddly-disco-backend namespace
- Sync policy: Automated with prune and selfHeal enabled

---

## Single-Cluster Deployment

### GitOps Workflow

**Initial Setup (Dev Environment):**

```bash
# 1. Create cluster, install ArgoCD and Istio
cd infrastructure/dev && terraform apply

# 2. Configure kubectl
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl get nodes

# 3. Verify Gateway is ready
kubectl get gateway -n istio-system
kubectl get pods -n istio-system

# 4. Deploy both frontend and backend applications via ArgoCD
kubectl apply -f k8s/argocd-apps/backend-app.yaml
kubectl apply -f k8s/argocd-apps/frontend-app-dev.yaml  # Use dev-specific file

# 5. Watch ArgoCD sync
kubectl get applications -n argocd
# Or use ArgoCD UI: http://localhost:30080

# 6. Verify deployments
kubectl get pods -n cuddly-disco-backend
kubectl get pods -n cuddly-disco-frontend
kubectl get httproute -n cuddly-disco-frontend

# 7. Access frontend via Gateway
curl -H "Host: dev.cuddly-disco.ai.localhost" http://localhost:3000
# Or configure /etc/hosts and use: http://dev.cuddly-disco.ai.localhost:3000
```

**Initial Setup (Prod Environment):**

```bash
# Use infrastructure/prod instead and frontend-app.yaml (without -dev suffix)
cd infrastructure/prod && terraform apply
export KUBECONFIG=~/.kube/kind-kind-prod
kubectl apply -f k8s/argocd-apps/backend-app.yaml
kubectl apply -f k8s/argocd-apps/frontend-app.yaml  # Prod version
curl -H "Host: cuddly-disco.ai.localhost" http://localhost:3001  # Note: port 3001 for prod
```

### Development Workflow

1. Make changes to Helm chart in `k8s/frontend/` (templates or values.yaml)
2. Commit and push to Git
3. ArgoCD automatically detects changes and syncs (if automated sync enabled)
4. Verify deployment: `kubectl get pods -n cuddly-disco-frontend`

### Local Helm Testing

```bash
# Validate chart
helm lint k8s/frontend

# Preview rendered templates
helm template frontend k8s/frontend

# Test with custom values
helm template frontend k8s/frontend --set image.tag=v1.2.0
```

### Deploying New Versions

1. CI/CD builds and tags new image (e.g., `frontend:v1.2.3`)
2. Update `k8s/frontend/values.yaml` with new image tag
3. Commit and push
4. ArgoCD syncs automatically

### Override Values in ArgoCD

Modify `k8s/argocd-apps/frontend-app.yaml`:

```yaml
source:
  helm:
    values: |
      replicaCount: 3
      image:
        tag: v1.2.0
```

### Manual Sync

```bash
# Using ArgoCD CLI
argocd app sync frontend

# Or via kubectl
kubectl patch application frontend -n argocd \
  -p '{"operation":{"initiatedBy":{"automated":false}}}' \
  --type merge
```

---

## Multi-Cluster Deployment

The project uses a **hub-spoke architecture** where a management cluster deploys applications to both dev and prod clusters using ArgoCD ApplicationSets.

### Architecture Overview

```
Management Cluster (kind-mgmt)
├── ArgoCD (central control plane)
├── Cluster Secrets (credentials for dev/prod)
└── ApplicationSets (define deployment patterns)
    ├── Team Apps ApplicationSet
    └── Auto-generates Applications for each team × environment
        ├── team-a-dev → kind-dev cluster
        ├── team-a-prod → kind-prod cluster
        ├── team-b-dev → kind-dev cluster
        └── team-b-prod → kind-prod cluster
```

### Key Components

**1. Management Cluster (`kind-mgmt`):**
- Runs ArgoCD with ApplicationSet controller
- Registers dev and prod clusters via Terraform
- Hosts ApplicationSet definitions
- UI: http://localhost:30082

**2. Dev Cluster (`kind-dev`):**
- Hosts dev environments for all teams
- Gateway: `dev.cuddly-disco.ai.localhost:3000`
- Lower resource limits, 1 replica per app

**3. Prod Cluster (`kind-prod`):**
- Hosts production environments for all teams
- Gateway: `cuddly-disco.ai.localhost:3001`
- Higher resource limits, 3 replicas per app

### Cluster Registration

The management cluster uses the official ArgoCD Terraform provider to register dev and prod clusters.

**Provider Configuration (`infrastructure/mgmt/versions.tf` and `provider.tf`):**

```hcl
# versions.tf
terraform {
  required_providers {
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "~> 7.0"
    }
  }
}

# provider.tf
provider "argocd" {
  username = "admin"
  password = data.kubernetes_secret.argocd_admin.data["password"]

  port_forward_with_namespace = "argocd"
  insecure                   = true
  plain_text                  = true
  grpc_web                    = true

  kubernetes {
    host                   = module.k8s.cluster_endpoint
    cluster_ca_certificate = module.k8s.cluster_ca_certificate
    client_certificate     = module.k8s.client_certificate
    client_key             = module.k8s.client_key
  }
}
```

**Cluster Registration (`infrastructure/mgmt/clusters.tf`):**

```hcl
resource "argocd_cluster" "dev" {
  server = data.terraform_remote_state.dev.outputs.cluster_endpoint_internal
  name   = data.terraform_remote_state.dev.outputs.cluster_name

  config {
    tls_client_config {
      ca_data   = data.terraform_remote_state.dev.outputs.cluster_ca_certificate
      cert_data = data.terraform_remote_state.dev.outputs.client_certificate
      key_data  = data.terraform_remote_state.dev.outputs.client_key
    }
  }

  depends_on = [module.argocd]
}
```

**Key Points:**
- **Internal Endpoints**: Uses Docker network hostnames (`https://kind-dev-control-plane:6443`) instead of localhost addresses, allowing ArgoCD pods to reach target clusters
- **Port Forwarding**: Provider uses `port_forward_with_namespace` to connect to ArgoCD API running in the cluster
- **Automatic Authentication**: Provider authenticates using admin credentials from Kubernetes secret
- **Proper Secret Format**: Provider creates cluster secrets in the correct ArgoCD format automatically

**Cluster Endpoint Outputs** (added to `infrastructure/dev/outputs.tf` and `infrastructure/prod/outputs.tf`):

```hcl
output "cluster_endpoint" {
  description = "Kubernetes API server endpoint (external/localhost)"
  value       = module.k8s.cluster_endpoint
}

output "cluster_endpoint_internal" {
  description = "Kubernetes API server endpoint (internal/Docker network)"
  value       = "https://${module.k8s.cluster_name}-control-plane:6443"
}
```

**Setup:**

```bash
# 1. Create all clusters
cd infrastructure/dev && terraform apply
cd ../prod && terraform apply
cd ../mgmt && terraform init -upgrade  # Install ArgoCD provider
cd ../mgmt && KUBECONFIG=~/.kube/kind-kind-mgmt terraform apply

# 2. Verify cluster registration
export KUBECONFIG=~/.kube/kind-kind-mgmt
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster
# Expected output:
# cluster-kind-dev-control-plane-...
# cluster-kind-prod-control-plane-...

# 3. View registered clusters in ArgoCD UI
open http://localhost:30082
# Login: admin/<password from terraform output>
# Navigate to Settings → Clusters
```

**Why This Approach:**
- **Official Provider**: Uses the maintained `argoproj-labs/argocd` provider
- **Correct Format**: Automatically creates properly formatted cluster secrets
- **Type Safety**: Terraform validates configuration at plan time
- **Idempotent**: Can be re-applied safely without manual cleanup
- **GitOps-Ready**: Cluster registration is declarative and version-controlled

### Team Applications with ApplicationSets

**Directory:** `k8s/team-apps/`

Teams are deployed using the **Git directory generator** pattern, which automatically discovers team apps from Git directories.

**ApplicationSet Definition:** `k8s/argocd-appsets/team-apps.yaml`

```yaml
generators:
- matrix:
    generators:
    # Discover teams from Git directories
    - git:
        repoURL: https://github.com/natosullivan/cuddly-disco.git
        revision: HEAD
        directories:
        - path: k8s/team-apps/*

    # Define target environments
    - list:
        elements:
        - cluster: kind-dev
          environment: dev
          server: https://kind-dev-control-plane:6443
          valuesFile: values-dev.yaml
        - cluster: kind-prod
          environment: prod
          server: https://kind-prod-control-plane:6443
          valuesFile: values-prod.yaml
```

**How It Works:**
1. ApplicationSet scans `k8s/team-apps/*` for team directories
2. For each team directory, generates Applications for dev + prod environments
3. Applications use environment-specific values files (`values-dev.yaml`, `values-prod.yaml`)
4. Management ArgoCD deploys to remote clusters via cluster secrets

### Adding a New Team

**1. Copy Template:**

```bash
cp -r k8s/team-apps/team-a k8s/team-apps/team-c
```

**2. Update Configuration:**

`k8s/team-apps/team-c/config.yaml`:

```yaml
team:
  name: team-c
  namespace: team-c
  routePath: /team-c
  owner: "charlie@example.com"
  slackChannel: "#team-c-alerts"
  version:
    dev: main      # Latest from main branch
    prod: v1.0.0   # Specific Git tag
```

`k8s/team-apps/team-c/Chart.yaml`:

```yaml
name: team-c-app
description: Team C application deployment
```

`k8s/team-apps/team-c/values.yaml`:

```yaml
teamName: team-c
routePath: /team-c
namespace:
  name: team-c
config:
  location: "Team C Office"
```

**3. Commit and Push:**

```bash
git add k8s/team-apps/team-c
git commit -m "feat: Add team-c application"
git push
```

**4. Verify Auto-Creation:**

```bash
# ApplicationSet automatically creates Applications
export KUBECONFIG=~/.kube/kind-kind-mgmt
kubectl get applications -n argocd -l team=team-c

# Expected output:
# team-c-dev
# team-c-prod
```

**5. Access Team Application:**
- **Dev:** `http://dev.cuddly-disco.ai.localhost:3000/team-c`
- **Prod:** `http://cuddly-disco.ai.localhost:3001/team-c`

### Team App Structure

Each team directory contains:

```
team-name/
├── config.yaml          # Team metadata
├── Chart.yaml           # Helm chart definition
├── values.yaml          # Base Helm values
├── values-dev.yaml      # Dev environment overrides
├── values-prod.yaml     # Prod environment overrides
└── templates/           # Helm templates
    ├── _helpers.tpl     # Template helpers
    ├── namespace.yaml   # Creates team namespace
    ├── configmap.yaml   # Environment variables
    ├── deployment.yaml  # Pod deployment with health probes
    ├── service.yaml     # ClusterIP service
    └── httproute.yaml   # Path-based routing
```

**Key Features:**
- **Namespace per team:** Each team gets `team-name` namespace in both dev and prod
- **Path-based routing:** Teams share Gateway, routed by path prefix (`/team-a`, `/team-b`)
- **Environment-specific values:** Different replicas, resources, hostnames per environment
- **Health probes:** Startup, liveness, and readiness probes for resilience
- **ConfigMap with checksum:** Auto-restart pods when config changes

### Deployment Workflow

**Dev to Prod Promotion:**

**1. Develop in Dev:**

```bash
# Make changes to team-a app
git add k8s/team-apps/team-a
git commit -m "feat: Add new feature to team-a"
git push

# ApplicationSet auto-syncs to dev cluster
# Test: http://dev.cuddly-disco.ai.localhost:3000/team-a
```

**2. Create Release Tag:**

```bash
# When ready for prod, create Git tag
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

**3. Update Prod Version:**

```bash
# Update config.yaml to use new tag
# (Future enhancement - currently uses HEAD)
git commit -m "chore: Promote team-a to v1.2.0 in prod"
git push
```

### Monitoring Multi-Cluster Deployments

**From Management Cluster:**

```bash
export KUBECONFIG=~/.kube/kind-kind-mgmt

# List all team applications
kubectl get applications -n argocd

# View specific team across environments
kubectl get applications -n argocd -l team=team-a

# Check sync status
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.sync.status}{"\n"}{end}'

# View ApplicationSet status
kubectl get applicationset team-apps -n argocd -o yaml
```

**From Target Clusters:**

```bash
# Dev cluster
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl get pods -n team-a
kubectl get httproute -n team-a

# Prod cluster
export KUBECONFIG=~/.kube/kind-kind-prod
kubectl get pods -n team-a
kubectl get httproute -n team-a
```

**ArgoCD UI:**
- Management: http://localhost:30082
- View all Applications in grid view
- Filter by team label
- See sync status, health, and errors

### Best Practices

**Team Onboarding:**
1. Copy existing team directory as template
2. Update all team-specific values (name, namespace, routePath)
3. Test Helm chart locally: `helm lint k8s/team-apps/team-name`
4. Preview templates: `helm template team-name k8s/team-apps/team-name`
5. Commit and push - ApplicationSet auto-creates Applications
6. Monitor sync in ArgoCD UI
7. Test endpoints in both dev and prod

**Version Management:**
- **Dev:** Always uses `main` branch (continuous deployment)
- **Prod:** Use Git tags for stability (`v1.0.0`, `v1.1.0`)
- Update `config.yaml` version field when promoting to prod (planned feature)

**Resource Management:**
- Dev: Lower limits (cpu: 100m, memory: 128Mi)
- Prod: Higher limits (cpu: 300m, memory: 512Mi)
- Adjust per team in values files based on actual usage

**Security:**
- Each team has isolated namespace
- Network policies can be added per team
- RBAC can restrict team access to their namespace only
- Secrets managed via Kubernetes Secrets (not in Git)

### Future Enhancements

Planned improvements:
- **Version pinning:** Use `config.yaml` version field to set `targetRevision` per environment
- **Helm chart registry:** Publish charts to OCI registry instead of Git
- **Progressive delivery:** Canary deployments with Argo Rollouts
- **Auto-scaling:** HPA based on CPU/memory metrics
- **Resource quotas:** Per-team resource limits
- **Subdomain routing:** Option for `team-a.dev.example.com` instead of path-based

---

## Multi-Version Deployment

The cuddly-disco application supports deploying multiple versions of the frontend and backend in the same namespace using header-based routing. This enables testing multiple versions simultaneously without requiring separate namespaces.

### Overview

**Architecture:**
- Multiple versions (e.g., v1, v2, v3) deployed in the same namespace
- Each version has unique service names (e.g., `frontend-dev-v1-frontend-app`, `frontend-dev-v2-frontend-app`)
- **Default version** (typically v1): Accessible without any special headers
- **Non-default versions**: Require `X-Version` header to route traffic

**Use Cases:**
- A/B testing different versions simultaneously
- Testing new features before promoting to default
- Gradual rollout with version selection via headers
- Multi-tenant scenarios where different users access different versions

### How It Works

**Single ApplicationSet Configuration:**

The ApplicationSet (`k8s/argocd-appsets/team-apps.yaml`) generates multiple Applications per environment:

```yaml
generators:
- matrix:
    generators:
    - git:
        directories:
        - path: k8s/team-apps/*

    - list:
        elements:
        # Dev cluster - v1 (default version)
        - cluster: kind-dev
          environment: dev
          version: v1
          valuesFile: values-dev-v1.yaml

        # Dev cluster - v2 (header-based routing)
        - cluster: kind-dev
          environment: dev
          version: v2
          valuesFile: values-dev-v2.yaml
```

This generates Applications:
- `frontend-dev-v1` - Default version, no header required
- `frontend-dev-v2` - Requires `X-Version: v2` header
- `backend-dev-v1` - Default backend version
- `backend-dev-v2` - Backend v2

**HTTPRoute Configuration:**

The frontend HTTPRoute uses conditional header matching:

```yaml
# For v2 (non-default):
rules:
- matches:
  - path:
      type: PathPrefix
      value: /
    headers:
    - name: X-Version
      value: v2
  backendRefs:
  - name: frontend-dev-v2-frontend-app
    port: 3000

# For v1 (default, no header match):
rules:
- matches:
  - path:
      type: PathPrefix
      value: /
  backendRefs:
  - name: frontend-dev-v1-frontend-app
    port: 3000
```

**Gateway API routes requests based on the `X-Version` header:**
1. Request with `X-Version: v2` → Routes to v2 service
2. Request with `X-Version: v3` → Routes to v3 service
3. Request with no header → Routes to default version (v1)

### Configuration Files

**Version-Specific Values Files:**

Each version has its own values file that configures:
- Version identifier (`version.name`)
- Whether it's the default version (`version.isDefault`)
- Namespace creation (`namespace.create` - only v1 creates, others reuse)
- Image tag (can be different per version)
- Configuration overrides (e.g., location string)

**Example: `values-dev-v1.yaml` (Default Version)**

```yaml
version:
  name: "v1"
  isDefault: true  # No header required

namespace:
  create: true  # v1 creates the namespace

image:
  tag: "v1.3.0"

config:
  location: "Development"
```

**Example: `values-dev-v2.yaml` (Header-Based Version)**

```yaml
version:
  name: "v2"
  isDefault: false  # Requires X-Version: v2 header

namespace:
  create: false  # Reuses namespace created by v1

image:
  tag: "v1.3.0"  # Can use different tag when needed

config:
  location: "Development V2"
```

### Deploying Multiple Versions

**Setup:**

The ApplicationSet automatically deploys all configured versions when applied to ArgoCD:

```bash
# Apply ApplicationSet (creates all version Applications)
export KUBECONFIG=~/.kube/kind-kind-mgmt
kubectl apply -f k8s/argocd-appsets/team-apps.yaml

# Verify Applications created
kubectl get applications -n argocd -l team=frontend
# Expected output:
# frontend-dev-v1
# frontend-dev-v2
# frontend-prod-v1

# Check sync status
kubectl get applications -n argocd -l environment=dev
```

**Verify Deployments:**

```bash
# Switch to dev cluster
export KUBECONFIG=~/.kube/kind-kind-dev

# Check all pods in frontend namespace
kubectl get pods -n frontend
# Expected output:
# frontend-dev-v1-frontend-app-xxx
# frontend-dev-v2-frontend-app-xxx

# Check services
kubectl get svc -n frontend
# Expected output:
# frontend-dev-v1-frontend-app
# frontend-dev-v2-frontend-app

# Check HTTPRoutes
kubectl get httproute -n frontend
# Both versions should have HTTPRoutes with different header matching
```

### Accessing Different Versions

**Default Version (No Header Required):**

```bash
# Access v1 without any special headers
curl http://dev.cuddly-disco.ai.localhost:3000

# Or via browser: http://dev.cuddly-disco.ai.localhost:3000
# (Add to /etc/hosts: 127.0.0.1 dev.cuddly-disco.ai.localhost)
```

**Version-Specific Access (Header-Based Routing):**

```bash
# Access v2 with X-Version header
curl -H "X-Version: v2" http://dev.cuddly-disco.ai.localhost:3000

# Access v3 (if deployed)
curl -H "X-Version: v3" http://dev.cuddly-disco.ai.localhost:3000

# Browser access with header (using browser extension or dev tools):
# 1. Install "ModHeader" extension or similar
# 2. Add header: X-Version = v2
# 3. Visit: http://dev.cuddly-disco.ai.localhost:3000
```

**Testing Header Routing:**

```bash
# Test default (should show "Development")
curl http://dev.cuddly-disco.ai.localhost:3000 | grep "Development"

# Test v2 (should show "Development V2")
curl -H "X-Version: v2" http://dev.cuddly-disco.ai.localhost:3000 | grep "Development V2"

# Verify different services are handling requests
# Check logs for v1
kubectl logs -n frontend -l app.kubernetes.io/instance=frontend-dev-v1 --tail=10

# Check logs for v2
kubectl logs -n frontend -l app.kubernetes.io/instance=frontend-dev-v2 --tail=10
```

### Adding a New Version

**1. Create Values File:**

```bash
# Copy existing version values as template
cp k8s/team-apps/frontend/values-dev-v2.yaml k8s/team-apps/frontend/values-dev-v3.yaml
cp k8s/team-apps/backend/values-dev-v2.yaml k8s/team-apps/backend/values-dev-v3.yaml
```

**2. Update Values:**

Edit `k8s/team-apps/frontend/values-dev-v3.yaml`:

```yaml
version:
  name: "v3"
  isDefault: false

namespace:
  create: false

image:
  tag: "v1.4.0"  # New version image

config:
  location: "Development V3"
```

**3. Add to ApplicationSet:**

Edit `k8s/argocd-appsets/team-apps.yaml`:

```yaml
- list:
    elements:
    # ... existing v1 and v2 entries ...

    # Dev cluster - v3 (header-based routing)
    - cluster: kind-dev
      environment: dev
      version: v3
      valuesFile: values-dev-v3.yaml
```

**4. Commit and Deploy:**

```bash
git add k8s/team-apps/*/values-dev-v3.yaml k8s/argocd-appsets/team-apps.yaml
git commit -m "feat: Add v3 deployment to dev environment"
git push

# ApplicationSet auto-creates v3 Applications
export KUBECONFIG=~/.kube/kind-kind-mgmt
kubectl get applications -n argocd -l version=v3
```

**5. Test New Version:**

```bash
curl -H "X-Version: v3" http://dev.cuddly-disco.ai.localhost:3000
```

### Changing the Default Version

To make v2 the default version instead of v1:

**1. Update Values Files:**

Edit `values-dev-v1.yaml`:
```yaml
version:
  isDefault: false  # Changed from true
```

Edit `values-dev-v2.yaml`:
```yaml
version:
  isDefault: true  # Changed from false
```

**2. Commit and Sync:**

```bash
git add k8s/team-apps/*/values-dev-*.yaml
git commit -m "chore: Switch default version from v1 to v2"
git push

# ArgoCD auto-syncs the change
# After sync, requests without headers will route to v2
curl http://dev.cuddly-disco.ai.localhost:3000  # Now routes to v2
```

### Removing a Version

**1. Remove from ApplicationSet:**

Edit `k8s/argocd-appsets/team-apps.yaml` and remove the version entry from the list.

**2. Commit and Push:**

```bash
git commit -m "chore: Remove v2 from dev environment"
git push

# ArgoCD automatically prunes the removed Application
# This deletes the Deployment, Service, HTTPRoute, etc.
```

**Note:** The namespace is only deleted when the last version is removed (when `namespace.create: true` version is removed).

### Best Practices

**Version Management:**
- Keep v1 as stable production-like version
- Use v2, v3 for testing new features
- Always have one default version (isDefault: true)
- Only the first version should create namespace (namespace.create: true)

**Image Tags:**
- Use semantic versioning for image tags (v1.0.0, v1.1.0)
- Default version should use stable/released images
- Non-default versions can use development or canary images
- Update image tags per version independently

**Configuration:**
- Use different location strings to identify versions visually
- Ensure backend versions match frontend versions if needed
- Test header routing before promoting to default

**Resource Management:**
- All versions in same namespace share resource quotas
- Monitor total resource usage across versions
- Consider lower replica counts for non-default versions
- Clean up unused versions to free resources

**Testing Workflow:**
1. Deploy new version as non-default (e.g., v2)
2. Test with `X-Version: v2` header
3. Verify functionality and performance
4. When ready, switch to default by updating `isDefault`
5. Monitor for issues
6. If problems occur, quickly switch default back to v1

### Troubleshooting Multi-Version Deployments

**Version Not Accessible:**

```bash
# Check if Application exists
kubectl get application frontend-dev-v2 -n argocd

# Check if pods are running
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl get pods -n frontend -l app.kubernetes.io/instance=frontend-dev-v2

# Check HTTPRoute configuration
kubectl get httproute -n frontend -o yaml
# Verify header matching is configured correctly
```

**Header Routing Not Working:**

```bash
# Test with verbose curl to see routing
curl -v -H "X-Version: v2" http://dev.cuddly-disco.ai.localhost:3000

# Check Gateway API status
kubectl describe httproute -n frontend

# Verify Gateway is routing correctly
kubectl get gateway -n istio-system cuddly-disco-gateway -o yaml
```

**Namespace Already Exists Error:**

If you see errors about namespace already existing:

```bash
# Ensure only v1 has namespace.create: true
grep -r "create: true" k8s/team-apps/*/values-dev-*.yaml
# Should only show v1 values file

# Update v2, v3 to namespace.create: false
```

**Service Name Conflicts:**

If services conflict, verify the service templates use `include "frontend-app.fullname" .` instead of hardcoded names.

```bash
# Check service names are unique
kubectl get svc -n frontend
# Should see frontend-dev-v1-frontend-app, frontend-dev-v2-frontend-app, etc.
```

---

## Accessing Services

### Frontend

- **Local (Dev):** http://localhost:3000 with Host header `dev.cuddly-disco.ai.localhost`
  - Via curl: `curl -H "Host: dev.cuddly-disco.ai.localhost" http://localhost:3000`
  - Via browser: Add `127.0.0.1 dev.cuddly-disco.ai.localhost` to `/etc/hosts`, then visit `http://dev.cuddly-disco.ai.localhost:3000`
- **Local (Prod):** http://localhost:3001 with Host header `cuddly-disco.ai.localhost`
  - Via curl: `curl -H "Host: cuddly-disco.ai.localhost" http://localhost:3001`
  - Via browser: Add `127.0.0.1 cuddly-disco.ai.localhost` to `/etc/hosts`, then visit `http://cuddly-disco.ai.localhost:3001`
- **Local (LocalDev):** http://localhost:8080 with Host header `localdev.cuddly-disco.ai.localhost`
  - Via curl: `curl -H "Host: localdev.cuddly-disco.ai.localhost" http://localhost:8080`
  - Via browser: Add `127.0.0.1 localdev.cuddly-disco.ai.localhost` to `/etc/hosts`, then visit `http://localdev.cuddly-disco.ai.localhost:8080`
- **In-cluster:** `http://frontend-service.cuddly-disco-frontend.svc.cluster.local:3000`
- **Architecture:**
  - Dev: Gateway API (NodePort 30001 → host 3000) → HTTPRoute → ClusterIP Service
  - Prod: Gateway API (NodePort 30001 → host 3001) → HTTPRoute → ClusterIP Service
  - LocalDev: Gateway API (NodePort 30001 → host 8080) → HTTPRoute → ClusterIP Service

### Backend

- **Local:** Not exposed (ClusterIP only)
- **In-cluster:** `http://backend-service.cuddly-disco-backend.svc.cluster.local:5000`
- **Testing:** Use `kubectl port-forward` for local testing
  ```bash
  kubectl port-forward -n cuddly-disco-backend svc/backend-service 5000:5000
  curl http://localhost:5000/health
  ```

### ArgoCD

- **UI (Dev):** http://localhost:30080 (NodePort)
- **UI (Prod):** http://localhost:30081 (NodePort)
- **UI (LocalDev):** Not available (LocalDev cluster has no ArgoCD)
- **Username:** `admin`
- **Password:** `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`

### Istio Gateway

- **Service:** `kubectl get svc -n istio-system istio-ingressgateway`
- **Gateway Resource:** `kubectl get gateway -n istio-system cuddly-disco-gateway`
- **Status:** `kubectl describe gateway -n istio-system cuddly-disco-gateway`

---

## Troubleshooting

### Basic Diagnostics

```bash
# Check pod status
kubectl get pods -n cuddly-disco-frontend
kubectl get pods -n cuddly-disco-backend
kubectl get pods -n istio-system

# View pod logs
kubectl logs -n cuddly-disco-frontend -l app=frontend
kubectl logs -n cuddly-disco-backend -l app=backend
kubectl logs -n istio-system -l app=istio-ingressgateway

# Describe pod for events
kubectl describe pod -n cuddly-disco-frontend <pod-name>
kubectl describe pod -n cuddly-disco-backend <pod-name>
```

### Gateway API Resources

```bash
# Check Gateway API resources
kubectl get gateway -n istio-system
kubectl get httproute -n cuddly-disco-frontend
kubectl describe gateway -n istio-system cuddly-disco-gateway
kubectl describe httproute -n cuddly-disco-frontend

# Check Gateway status (Accepted, Programmed, Ready)
kubectl get gateway -n istio-system cuddly-disco-gateway -o jsonpath='{.status.conditions[*].type}'

# Check Istio gateway service
kubectl get svc -n istio-system istio-ingressgateway
kubectl describe svc -n istio-system istio-ingressgateway
```

### ArgoCD Troubleshooting

```bash
# Check ArgoCD app status (dev/prod only, not localdev)
kubectl get application frontend -n argocd -o yaml
kubectl get application backend -n argocd -o yaml

# Force sync (dev/prod only, not localdev)
argocd app sync frontend --force
argocd app sync backend --force
```

### Connectivity Testing

```bash
# Test Gateway directly
curl -v -H "Host: dev.cuddly-disco.ai.localhost" http://localhost:3000      # Dev
curl -v -H "Host: cuddly-disco.ai.localhost" http://localhost:3001          # Prod
curl -v -H "Host: localdev.cuddly-disco.ai.localhost" http://localhost:8080 # LocalDev

# Test backend connectivity from frontend pod
kubectl exec -it -n cuddly-disco-frontend <frontend-pod> -- sh
# Inside pod: curl http://backend-service.cuddly-disco-backend.svc.cluster.local:5000/health
```

### Multi-Cluster Troubleshooting

**ApplicationSet Not Generating Applications:**

```bash
export KUBECONFIG=~/.kube/kind-kind-mgmt

# Check ApplicationSet status
kubectl get applicationset team-apps -n argocd -o yaml

# View ApplicationSet controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller

# Verify Git directory exists
ls k8s/team-apps/
```

**Cluster Not Registered:**

```bash
# List cluster secrets
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster

# Verify cluster connectivity
kubectl exec -it -n argocd deployment/argocd-server -- argocd cluster list

# Re-run Terraform to register
cd infrastructure/mgmt && terraform apply
```

**Application Sync Failed:**

```bash
# View application details
kubectl get application team-a-dev -n argocd -o yaml

# Check sync errors
kubectl describe application team-a-dev -n argocd

# Force sync
kubectl patch application team-a-dev -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
```

**HTTPRoute Not Working:**

```bash
# Check Gateway on target cluster
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl get gateway -n istio-system cuddly-disco-gateway
kubectl get httproute -n team-a

# Test routing
curl -v -H "Host: dev.cuddly-disco.ai.localhost" http://localhost:3000/team-a
```

---

## Key Kubernetes Concepts

### Namespaces

- `argocd` - ArgoCD installation
- `istio-system` - Istio control plane and Gateway resources
- `cuddly-disco-frontend` - Frontend application
- `cuddly-disco-backend` - Backend API

### Service Types

**ClusterIP:** Internal-only service (default)
- Frontend service: ClusterIP on port 3000 (accessed via Gateway)
- Backend service: ClusterIP on port 5000 (internal only)
- Not accessible from outside the cluster

**NodePort:** Exposes service on static port on each node (30000-32767 range)
- Istio Gateway uses NodePort 30001 for external access
- Kind maps NodePort to host via extra_port_mappings (dev: 3000, prod: 3001)
- ArgoCD uses NodePort 30080 mapped to host (dev: 30080, prod: 30081)

### Gateway API Concepts

**Gateway:** Infrastructure-level ingress resource in istio-system namespace
- Defines listeners (protocol, port, hostname)
- Managed by Istio gateway controller
- Status conditions: Accepted, Programmed, Ready

**HTTPRoute:** Application-level routing resource in frontend namespace
- References Gateway via parentRefs (cross-namespace)
- Defines hostname matching rules
- Routes traffic to ClusterIP services
- More expressive than Ingress API

**GatewayClass:** Cluster-level resource defining controller
- `istio` GatewayClass created by Istio installation
- Multiple Gateway instances can reference same GatewayClass

### GitOps Benefits

- **Declarative:** Desired state in Git
- **Auditable:** Git history = deployment history
- **Automated:** Changes trigger deployments
- **Rollback-friendly:** Git revert = application rollback
- **Consistent:** Same process across environments

---

## See Also

- [Development Guide](../CLAUDE.md) - Local development and testing
- [CI/CD Pipeline](./CI-CD.md) - How containers are built and published
