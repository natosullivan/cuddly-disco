# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cuddly-disco is a simple two-tier application that displays encouraging messages. The frontend shows "For all the SREs out there, here are some kind words from [location]: [message]", where the location comes from an environment variable and the message is fetched from a Python backend API.

**Tech Stack:**
- Frontend: React 18 + TypeScript + Next.js 14 (port 3000)
- Backend: Python 3.11+ + Flask (port 5000)
- Both services run in Docker containers

## Development Commands

### Frontend (apps/frontend)

```bash
# Install dependencies
npm install

# Run development server (http://localhost:3000)
npm run dev

# Build for production
npm run build

# Run all tests
npm test

# Docker build and run
docker build -t kind-words-frontend .
docker run -p 3000:3000 \
  -e LOCATION="San Francisco" \
  -e BACKEND_URL="http://localhost:5000" \
  kind-words-frontend
```

### Backend (apps/backend)

```bash
# Install dependencies
pip install -r requirements.txt

# Run development server (http://localhost:5000)
python app.py

# Run all tests
pytest test_app.py

# Run specific test
pytest test_app.py::test_health_endpoint

# Run tests with verbose output
pytest -v test_app.py

# Docker build and run
docker build -t kind-words-backend .
docker run -p 5000:5000 kind-words-backend
```

## Architecture

### Frontend Architecture
- **Framework:** Next.js 14 with App Router (Server-Side Rendering)
- **Entry Point:** `app/layout.tsx` defines the root layout with metadata
- **Main Page:** `app/page.tsx` Server Component that handles application logic
  - Fetches location from `LOCATION` environment variable
  - Makes server-side API call to backend `/api/message` endpoint before page render
  - **Fetch Timeout:** 2-second timeout using AbortController prevents server hanging
  - Displays fallback message if backend is unavailable or times out
  - Uses CSS classes for error/success states
  - No client-side loading state - content is pre-rendered on server
- **Health Endpoint:** `app/api/health/route.ts` provides `/api/health` for Kubernetes probes
- **Testing:** Uses Vitest with React Testing Library for Server Component testing
- **Build System:** Next.js standalone mode for optimized Docker images (~100MB)
- **Server-Side Rendering:** Eliminates nginx dependency, Next.js server handles all requests
  - Backend API calls happen on the Next.js server (not in browser)
  - Direct server-to-server communication with backend service
  - Backend remains internal (ClusterIP) and not accessible to users
  - Configuration: `next.config.mjs` and environment variables

### Backend Architecture
- **Single File Application:** `app.py` contains all routes and logic
- **Routes:**
  - `GET /api/message` - Returns random encouraging message from MESSAGES list
  - `GET /health` - Health check endpoint
- **CORS:** Enabled for all origins to allow frontend communication
- **Testing:** Pytest with Flask test client, includes probabilistic test for randomness
- **Service Type:** ClusterIP service in Kubernetes - only accessible within the cluster

### Environment Variables

**Frontend Environment Variables (Next.js):**
The frontend uses server-side environment variables read at runtime:

**Environment Variables:**
- `LOCATION` - Location string to display (default: "Unknown")
  - Accessed in Server Component via `process.env.LOCATION`
  - Set via Docker `-e` flag or Kubernetes ConfigMap
- `BACKEND_URL` - Backend API URL for server-side API calls
  - Default: `http://localhost:5000` (local development)
  - Kubernetes: `http://backend-service.cuddly-disco-backend.svc.cluster.local:5000`
  - Accessed in Server Component via `process.env.BACKEND_URL`
  - Server-to-server communication (not exposed to browser)

**Local Development:**
Set environment variables when running Docker:
```bash
docker run -p 3000:3000 \
  -e LOCATION="San Francisco" \
  -e BACKEND_URL="http://localhost:5000" \
  kind-words-frontend
```

**Kubernetes Deployment:**
Environment variables are injected via ConfigMap at container startup:
- ConfigMap defines `LOCATION` and `BACKEND_URL`
- Next.js server reads variables from `process.env`
- No runtime injection needed - Next.js handles environment variables natively
- Same Docker image works across environments by changing ConfigMap values

**Implementation:**
- `app/page.tsx` - Reads `process.env.LOCATION` and `process.env.BACKEND_URL`
- `next.config.mjs` - Configures Next.js environment variable handling
- `k8s/frontend/templates/configmap.yaml` - Kubernetes ConfigMap with env vars
- `k8s/frontend/templates/deployment.yaml` - Injects ConfigMap into pod environment

### Key Design Patterns
- **Frontend Resilience:**
  - 2-second fetch timeout prevents server hanging when backend unavailable
  - Displays fallback message if backend is down or times out
  - Kubernetes startup probe (60s grace period) prevents premature pod termination
  - Health probes at `/api/health` enable automatic recovery
- Backend message pool is defined in `MESSAGES` constant in `app.py:8-14`
- Tests verify both happy path and error states (including timeout scenarios)
- Frontend uses TypeScript interfaces for type safety (`ApiResponse` in `app/page.tsx`)
- Server-Side Rendering eliminates loading states and improves SEO
- Direct server-to-server communication keeps backend internal and secure

## Testing Philosophy

### Frontend Tests (apps/frontend/__tests__/page.test.tsx)
- Tests cover Server Component rendering: success and error states
- Mocks `fetch` API globally for server-side testing
- Verifies environment variable handling (`LOCATION` and `BACKEND_URL`)
- Checks CSS class application for styling states
- Tests server-side rendering output (no loading state)
- **Timeout tests:** Verifies AbortController timeout (2s), fetch abortion handling, and signal passing
- Health endpoint tests in `__tests__/health.test.ts`
- Total: 18 tests (15 page tests + 3 health tests)

### Backend Tests (apps/backend/test_app.py)
- Uses pytest fixtures for test client
- Tests include probabilistic randomness verification
- Validates JSON response structure
- Checks that messages come from expected pool

## CI/CD Pipeline

The project uses GitHub Actions for continuous integration and deployment:
- **Workflow File:** `.github/workflows/ci.yml`
- **Triggers:** Push and pull requests to `main` branch
- **Jobs (in dependency order):**
  1. `frontend-tests`: Runs Vitest unit tests with Node.js 20 (parallel)
  2. `backend-tests`: Runs pytest unit tests with Python 3.11 (parallel)
  3. `build-containers`: Builds Docker images and saves as artifacts (parallel)
  4. `container-tests`: Loads images and runs integration tests (depends on all tests + build)
  5. `semantic-release`: Creates version tags and releases (main branch only, depends on all tests)
  6. `publish-images`: Publishes to GitHub Container Registry (depends on semantic-release)
  7. `update-helm-charts`: Updates Helm chart versions in Git (depends on semantic-release + publish-images)

### Job Dependencies
The pipeline ensures quality gates:
- `container-tests` depends on `frontend-tests`, `backend-tests`, and `build-containers`
- **If any test fails, the pipeline stops and no images are published**
- `semantic-release` runs only on main branch after all tests pass
- `publish-images` runs only if a new release was created
- `update-helm-charts` runs only if images were successfully published

### Container Build Job
The `build-containers` job creates reusable Docker images:
1. Builds both backend and frontend Docker images
2. Saves images as tar files using `docker save`
3. Uploads images as GitHub Actions artifacts (retained for 1 day)
4. These artifacts can be reused by multiple downstream jobs (testing, publishing, etc.)

### Container Integration Tests
The `container-tests` job validates the full Docker deployment:
1. Downloads backend and frontend image artifacts
2. Loads images using `docker load`
3. Starts backend container and waits for health check
4. Runs backend integration tests (`.github/scripts/test-backend-container.sh`)
   - Validates `/health` endpoint returns healthy status
   - Validates `/api/message` endpoint returns 200 with valid JSON
   - Verifies message content matches expected values
5. Starts frontend container with environment variables on **port 3001** (avoids conflicts with local k8s)
6. Runs frontend integration tests (`.github/scripts/test-frontend-container.sh`)
   - Uses configurable PORT (defaults to 3001)
   - Validates frontend is accessible and returns 200
   - Verifies HTML contains app title
   - Verifies Next.js bundle is loaded (`_next/static`)
   - Validates server-side rendering (pre-rendered content)
   - **Tests backend unavailability handling** (graceful degradation with timeout)
   - Tests health endpoint at `/api/health`
7. Shows container logs on failure for debugging
8. Always cleans up containers after tests

### Semantic Release
The `semantic-release` job automates versioning (main branch only):
- **Configuration:** `.releaserc.json` and `package.json` at repository root
- **Commit Convention:** Uses conventional commits (Angular style)
  - `fix:` commits → patch version bump (1.0.x)
  - `feat:` commits → minor version bump (1.x.0)
  - `BREAKING CHANGE:` in body → major version bump (x.0.0)
- **Outputs:**
  - `version`: The new semantic version (e.g., "1.2.3")
  - `released`: Boolean indicating if a release was created
- **Actions Performed:**
  - Analyzes commits since last release
  - Determines version bump type
  - Creates Git tag with new version
  - Generates release notes
  - Creates GitHub release

### Container Publishing
The `publish-images` job publishes to GitHub Container Registry:
- **Registry:** `ghcr.io` (GitHub Container Registry)
- **Runs Only If:** `semantic-release` created a new release
- **Process:**
  1. Downloads built container artifacts
  2. Loads Docker images
  3. Tags images with semantic version and `latest`
  4. Pushes to `ghcr.io/natosullivan/cuddly-disco/backend:VERSION`
  5. Pushes to `ghcr.io/natosullivan/cuddly-disco/frontend:VERSION`
- **Permissions:** Requires `packages: write` permission
- **Version Sync:** Image versions exactly match Git tags created by semantic-release

### Helm Chart Version Updates
The `update-helm-charts` job automatically updates Helm chart version tags in Git:
- **Runs Only If:** Images were successfully published to registry
- **Process:**
  1. Uses `sed` to update `k8s/frontend/values.yaml` → `image.tag` with new version
  2. Uses `sed` to update `k8s/backend/values.yaml` → `image.tag` with new version
  3. Commits changes with message: `chore: Update Helm chart versions to VERSION [skip ci]`
  4. Pushes commit to main branch
- **Bot Token:** Uses `BOT_GITHUB_TOKEN` secret (PAT) instead of `GITHUB_TOKEN`
  - This allows the commit to trigger ArgoCD webhooks
  - `GITHUB_TOKEN` won't trigger webhooks (GitHub prevents recursive workflows)
- **Skip CI:** Commit message includes `[skip ci]` to prevent infinite loops
- **GitOps Integration:** ArgoCD detects the Git change and automatically syncs new versions to Kubernetes

**Setting up the Bot Token:**
1. Create a GitHub Personal Access Token (PAT) with `repo` scope
2. Add it as a repository secret named `BOT_GITHUB_TOKEN`
3. The token enables the version bump commit to trigger ArgoCD's Git polling/webhooks

This architecture ensures:
- Docker containers are tested before deployment
- Version numbers are consistent across Git tags, Docker images, and Helm charts
- Images are only published after all tests pass
- Helm charts are automatically updated when new versions are released
- ArgoCD can automatically deploy new versions via GitOps
- No manual version management required

## Kubernetes and GitOps Deployment

The project supports deployment to Kubernetes using ArgoCD for GitOps-based continuous delivery.

### Infrastructure as Code

**Terraform Modules** (`infrastructure/modules/`):
- `k8s/` - Creates Kind (Kubernetes in Docker) clusters locally
  - Configurable node count, Kubernetes version, port mappings
  - Auto-generates kubeconfig at `~/.kube/kind-{cluster-name}`
  - Default port mappings: 30080 (ArgoCD UI), 30001 (Gateway API → host 3000)
- `argocd/` - Installs ArgoCD via Helm chart
  - NodePort service for local access
  - Insecure mode for development (no TLS)
  - ApplicationSet controller enabled
- `istio/` - Installs Istio and Gateway API for ingress
  - Installs Gateway API CRDs
  - Installs Istio base, istiod, and gateway charts
  - Creates Gateway resource with configurable hostname
  - Gateway-only mode (no service mesh/sidecar injection)
  - Gateway API automatically provisions infrastructure on NodePort 30001

**Dev Environment** (`infrastructure/dev/`):
- Creates single-node Kind cluster (control-plane only)
- Installs ArgoCD automatically (insecure mode)
- Installs Istio with Gateway hostname: `dev.cuddly-disco.ai.localhost`
- Port mappings:
  - ArgoCD UI: NodePort 30080 → host 30080
  - Gateway API: NodePort 30001 → host 3000

**Prod Environment** (`infrastructure/prod/`):
- Creates multi-node Kind cluster (1 control-plane + 2 workers)
- Installs ArgoCD automatically (TLS enabled)
- Installs Istio with Gateway hostname: `cuddly-disco.ai.localhost`
- Port mappings (different from dev to avoid conflicts):
  - ArgoCD UI: NodePort 30080 → host 30081
  - Gateway API: NodePort 30001 → host 3001
- Production-ready configuration for local testing

**Terraform Commands:**
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
```

### Kubernetes Manifests

**Frontend Helm Chart** (`k8s/frontend/`):
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

**Backend Helm Chart** (`k8s/backend/`):
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

**Frontend-Backend Connectivity:**
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

**ArgoCD Applications** (`k8s/argocd-apps/`):
- `frontend-app.yaml` - Frontend ArgoCD Application for **prod** environment
  - Source: GitHub repository, main branch, path: k8s/frontend
  - Helm: Uses values.yaml from chart (hostname: cuddly-disco.ai.localhost)
  - Destination: cuddly-disco-frontend namespace
  - Sync policy: Automated with prune and selfHeal enabled
- `frontend-app-dev.yaml` - Frontend ArgoCD Application for **dev** environment
  - Source: GitHub repository, main branch, path: k8s/frontend
  - Helm: Overrides gateway.hostname to dev.cuddly-disco.ai.localhost
  - Destination: cuddly-disco-frontend namespace
  - Sync policy: Automated with prune and selfHeal enabled
- `backend-app.yaml` - Backend ArgoCD Application (same for all environments)
  - Source: GitHub repository, main branch, path: k8s/backend
  - Helm: Uses values.yaml from chart, supports value overrides
  - Destination: cuddly-disco-backend namespace
  - Sync policy: Automated with prune and selfHeal enabled

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

**Development Workflow:**
1. Make changes to Helm chart in `k8s/frontend/` (templates or values.yaml)
2. Commit and push to Git
3. ArgoCD automatically detects changes and syncs (if automated sync enabled)
4. Verify deployment: `kubectl get pods -n cuddly-disco-frontend`

**Local Helm Testing:**
```bash
# Validate chart
helm lint k8s/frontend

# Preview rendered templates
helm template frontend k8s/frontend

# Test with custom values
helm template frontend k8s/frontend --set image.tag=v1.2.0
```

**Deploying New Versions:**
1. CI/CD builds and tags new image (e.g., `frontend:v1.2.3`)
2. Update `k8s/frontend/values.yaml` with new image tag
3. Commit and push
4. ArgoCD syncs automatically

**Override Values in ArgoCD:**
Modify `k8s/argocd-apps/frontend-app.yaml`:
```yaml
source:
  helm:
    values: |
      replicaCount: 3
      image:
        tag: v1.2.0
```

**Manual Sync:**
```bash
# Using ArgoCD CLI
argocd app sync frontend

# Or via kubectl
kubectl patch application frontend -n argocd \
  -p '{"operation":{"initiatedBy":{"automated":false}}}' \
  --type merge
```

### Accessing Services

**Frontend:**
- **Local (Dev):** http://localhost:3000 with Host header `dev.cuddly-disco.ai.localhost`
  - Via curl: `curl -H "Host: dev.cuddly-disco.ai.localhost" http://localhost:3000`
  - Via browser: Add `127.0.0.1 dev.cuddly-disco.ai.localhost` to `/etc/hosts`, then visit `http://dev.cuddly-disco.ai.localhost:3000`
- **Local (Prod):** http://localhost:3001 with Host header `cuddly-disco.ai.localhost`
  - Via curl: `curl -H "Host: cuddly-disco.ai.localhost" http://localhost:3001`
  - Via browser: Add `127.0.0.1 cuddly-disco.ai.localhost` to `/etc/hosts`, then visit `http://cuddly-disco.ai.localhost:3001`
- **In-cluster:** `http://frontend-service.cuddly-disco-frontend.svc.cluster.local:3000`
- **Architecture:**
  - Dev: Gateway API (NodePort 30001 → host 3000) → HTTPRoute → ClusterIP Service
  - Prod: Gateway API (NodePort 30001 → host 3001) → HTTPRoute → ClusterIP Service

**Backend:**
- **Local:** Not exposed (ClusterIP only)
- **In-cluster:** `http://backend-service.cuddly-disco-backend.svc.cluster.local:5000`
- **Testing:** Use `kubectl port-forward` for local testing
  ```bash
  kubectl port-forward -n cuddly-disco-backend svc/backend-service 5000:5000
  curl http://localhost:5000/health
  ```

**ArgoCD:**
- **UI (Dev):** http://localhost:30080 (NodePort)
- **UI (Prod):** http://localhost:30081 (NodePort)
- **Username:** `admin`
- **Password:** `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`

**Istio Gateway:**
- **Service:** `kubectl get svc -n istio-system istio-ingressgateway`
- **Gateway Resource:** `kubectl get gateway -n istio-system cuddly-disco-gateway`
- **Status:** `kubectl describe gateway -n istio-system cuddly-disco-gateway`

**Troubleshooting:**
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

# Check Gateway API resources
kubectl get gateway -n istio-system
kubectl get httproute -n cuddly-disco-frontend
kubectl describe gateway -n istio-system cuddly-disco-gateway
kubectl describe httproute -n cuddly-disco-frontend

# Check Gateway status (Accepted, Programmed, Ready)
kubectl get gateway -n istio-system cuddly-disco-gateway -o jsonpath='{.status.conditions[*].type}'

# Check ArgoCD app status
kubectl get application frontend -n argocd -o yaml
kubectl get application backend -n argocd -o yaml

# Force sync
argocd app sync frontend --force
argocd app sync backend --force

# Test Gateway directly
curl -v -H "Host: dev.cuddly-disco.ai.localhost" http://localhost:3000      # Dev
curl -v -H "Host: cuddly-disco.ai.localhost" http://localhost:3001          # Prod

# Test backend connectivity from frontend pod
kubectl exec -it -n cuddly-disco-frontend <frontend-pod> -- sh
# Inside pod: curl http://backend-service.cuddly-disco-backend.svc.cluster.local:5000/health

# Check Istio gateway service
kubectl get svc -n istio-system istio-ingressgateway
kubectl describe svc -n istio-system istio-ingressgateway
```

### Key Kubernetes Concepts

**Namespaces:**
- `argocd` - ArgoCD installation
- `istio-system` - Istio control plane and Gateway resources
- `cuddly-disco-frontend` - Frontend application
- `cuddly-disco-backend` - Backend API

**Service Types:**
- **ClusterIP:** Internal-only service (default)
  - Frontend service: ClusterIP on port 3000 (accessed via Gateway)
  - Backend service: ClusterIP on port 5000 (internal only)
  - Not accessible from outside the cluster
- **NodePort:** Exposes service on static port on each node (30000-32767 range)
  - Istio Gateway uses NodePort 30001 for external access
  - Kind maps NodePort to host via extra_port_mappings (dev: 3000, prod: 3001)
  - ArgoCD uses NodePort 30080 mapped to host (dev: 30080, prod: 30081)

**Gateway API Concepts:**
- **Gateway:** Infrastructure-level ingress resource in istio-system namespace
  - Defines listeners (protocol, port, hostname)
  - Managed by Istio gateway controller
  - Status conditions: Accepted, Programmed, Ready
- **HTTPRoute:** Application-level routing resource in frontend namespace
  - References Gateway via parentRefs (cross-namespace)
  - Defines hostname matching rules
  - Routes traffic to ClusterIP services
  - More expressive than Ingress API
- **GatewayClass:** Cluster-level resource defining controller
  - `istio` GatewayClass created by Istio installation
  - Multiple Gateway instances can reference same GatewayClass

**GitOps Benefits:**
- **Declarative:** Desired state in Git
- **Auditable:** Git history = deployment history
- **Automated:** Changes trigger deployments
- **Rollback-friendly:** Git revert = application rollback
- **Consistent:** Same process across environments

## Multi-Cluster Deployment with ApplicationSets

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

**Key Components:**

1. **Management Cluster (`kind-mgmt`):**
   - Runs ArgoCD with ApplicationSet controller
   - Registers dev and prod clusters via Terraform
   - Hosts ApplicationSet definitions
   - UI: http://localhost:30082

2. **Dev Cluster (`kind-dev`):**
   - Hosts dev environments for all teams
   - Gateway: `dev.cuddly-disco.ai.localhost:3000`
   - Lower resource limits, 1 replica per app

3. **Prod Cluster (`kind-prod`):**
   - Hosts production environments for all teams
   - Gateway: `cuddly-disco.ai.localhost:3001`
   - Higher resource limits, 3 replicas per app

### Cluster Registration

**ArgoCD Terraform Provider** (`infrastructure/mgmt/`)

The management cluster uses the official ArgoCD Terraform provider to register dev and prod clusters. This approach uses the provider's native `argocd_cluster` resource for proper cluster registration.

**Provider Configuration** (`infrastructure/mgmt/versions.tf` and `provider.tf`):
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

**Cluster Registration** (`infrastructure/mgmt/clusters.tf`):
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

1. **Develop in Dev:**
   ```bash
   # Make changes to team-a app
   git add k8s/team-apps/team-a
   git commit -m "feat: Add new feature to team-a"
   git push

   # ApplicationSet auto-syncs to dev cluster
   # Test: http://dev.cuddly-disco.ai.localhost:3000/team-a
   ```

2. **Create Release Tag:**
   ```bash
   # When ready for prod, create Git tag
   git tag -a v1.2.0 -m "Release v1.2.0"
   git push origin v1.2.0
   ```

3. **Update Prod Version:**
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

### Troubleshooting Multi-Cluster

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
