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
  - Displays fallback message if backend is unavailable
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
- Frontend is resilient - displays fallback message if backend is down
- Backend message pool is defined in `MESSAGES` constant in `app.py:8-14`
- Tests verify both happy path and error states
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
- Health endpoint tests in `__tests__/health.test.ts`

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

### Job Dependencies
The pipeline ensures quality gates:
- `container-tests` depends on `frontend-tests`, `backend-tests`, and `build-containers`
- **If any test fails, the pipeline stops and no images are published**
- `semantic-release` runs only on main branch after all tests pass
- `publish-images` runs only if a new release was created

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
5. Starts frontend container with environment variables
6. Runs frontend integration tests (`.github/scripts/test-frontend-container.sh`)
   - Validates frontend is accessible and returns 200
   - Verifies HTML contains app title
   - Verifies Next.js bundle is loaded (`_next/static`)
   - Validates server-side rendering (pre-rendered content)
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

This architecture ensures:
- Docker containers are tested before deployment
- Version numbers are consistent across Git tags and Docker images
- Images are only published after all tests pass
- No manual version management required

## Kubernetes and GitOps Deployment

The project supports deployment to Kubernetes using ArgoCD for GitOps-based continuous delivery.

### Infrastructure as Code

**Terraform Modules** (`infrastructure/modules/`):
- `k8s/` - Creates Kind (Kubernetes in Docker) clusters locally
  - Configurable node count, Kubernetes version, port mappings
  - Auto-generates kubeconfig at `~/.kube/kind-{cluster-name}`
  - Default port mappings: 30080 (ArgoCD UI), configurable application ports
- `argocd/` - Installs ArgoCD via Helm chart
  - NodePort service for local access
  - Insecure mode for development (no TLS)
  - ApplicationSet controller enabled

**Dev Environment** (`infrastructure/dev/`):
- Creates single-node Kind cluster (control-plane only)
- Installs ArgoCD automatically (insecure mode)
- Port mappings: 30080 (ArgoCD), 30001 (frontend via NodePort → host 3000)

**Prod Environment** (`infrastructure/prod/`):
- Creates multi-node Kind cluster (1 control-plane + 2 workers)
- Installs ArgoCD automatically (TLS enabled)
- Port mappings: 30080 (ArgoCD), 30001 (frontend via NodePort → host 3000)
- Production-ready configuration for local testing

**Terraform Commands:**
```bash
cd infrastructure/dev
terraform init
terraform plan
terraform apply

# Get ArgoCD admin password
eval $(terraform output -raw argocd_admin_password_command)

# Access ArgoCD UI
open http://localhost:30080  # Login: admin/<password>
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
  - `service.type: NodePort` - Service type with nodePort 30001
  - `service.port: 3000` - Next.js server port
  - Resource limits and requests
  - Health probe configurations
- `templates/` - Kubernetes resource templates
  - `_helpers.tpl` - Template helper functions
  - `namespace.yaml` - Creates cuddly-disco-frontend namespace
  - `configmap.yaml` - Environment variables ConfigMap (LOCATION, BACKEND_URL)
  - `deployment.yaml` - Deployment with 2 replicas, health probes at `/api/health`
  - `service.yaml` - NodePort service on port 30001 → container port 3000

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
The architecture uses Next.js Server-Side Rendering for direct server-to-server communication:
1. User's browser requests a page from frontend pod (NodePort 30001)
2. Next.js Server Component executes on the server before rendering
3. Server Component makes direct API call to `http://backend-service.cuddly-disco-backend.svc.cluster.local:5000/api/message`
4. Backend responds to Next.js server (server-to-server, not exposed to browser)
5. Next.js server renders the page with backend data and sends complete HTML to browser
6. Backend service remains ClusterIP - inaccessible from outside the cluster
7. No client-side API calls or loading states - everything is pre-rendered

**ArgoCD Applications** (`k8s/argocd-apps/`):
- `frontend-app.yaml` - Frontend ArgoCD Application
  - Source: GitHub repository, main branch, path: k8s/frontend
  - Helm: Uses values.yaml from chart, supports value overrides
  - Destination: cuddly-disco-frontend namespace
  - Sync policy: Automated with prune and selfHeal enabled
- `backend-app.yaml` - Backend ArgoCD Application
  - Source: GitHub repository, main branch, path: k8s/backend
  - Helm: Uses values.yaml from chart, supports value overrides
  - Destination: cuddly-disco-backend namespace
  - Sync policy: Automated with prune and selfHeal enabled

### GitOps Workflow

**Initial Setup:**
```bash
# 1. Create cluster and install ArgoCD
cd infrastructure/dev && terraform apply

# 2. Configure kubectl
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl get nodes

# 3. Deploy both frontend and backend applications via ArgoCD
kubectl apply -f k8s/argocd-apps/backend-app.yaml
kubectl apply -f k8s/argocd-apps/frontend-app.yaml

# 4. Watch ArgoCD sync
kubectl get applications -n argocd
# Or use ArgoCD UI: http://localhost:30080

# 5. Verify deployments
kubectl get pods -n cuddly-disco-backend
kubectl get pods -n cuddly-disco-frontend

# 6. Access frontend
open http://localhost:3000
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
- **Local:** http://localhost:3000 (NodePort 30001 → host 3000)
- **In-cluster:** `http://frontend-service.cuddly-disco-frontend.svc.cluster.local`

**Backend:**
- **Local:** Not exposed (ClusterIP only)
- **In-cluster:** `http://backend-service.cuddly-disco-backend.svc.cluster.local:5000`
- **Testing:** Use `kubectl port-forward` for local testing
  ```bash
  kubectl port-forward -n cuddly-disco-backend svc/backend-service 5000:5000
  curl http://localhost:5000/health
  ```

**ArgoCD:**
- **UI:** http://localhost:30080 (NodePort)
- **Username:** `admin`
- **Password:** `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`

**Troubleshooting:**
```bash
# Check pod status
kubectl get pods -n cuddly-disco-frontend
kubectl get pods -n cuddly-disco-backend

# View pod logs
kubectl logs -n cuddly-disco-frontend -l app=frontend
kubectl logs -n cuddly-disco-backend -l app=backend

# Describe pod for events
kubectl describe pod -n cuddly-disco-frontend <pod-name>
kubectl describe pod -n cuddly-disco-backend <pod-name>

# Check ArgoCD app status
kubectl get application frontend -n argocd -o yaml
kubectl get application backend -n argocd -o yaml

# Force sync
argocd app sync frontend --force
argocd app sync backend --force

# Test backend connectivity from frontend pod
kubectl exec -it -n cuddly-disco-frontend <frontend-pod> -- sh
# Inside pod: curl http://backend-service.cuddly-disco-backend.svc.cluster.local:5000/health
```

### Key Kubernetes Concepts

**Namespaces:**
- `argocd` - ArgoCD installation
- `cuddly-disco-frontend` - Frontend application
- `cuddly-disco-backend` - Backend API

**Service Types:**
- **NodePort:** Exposes service on static port on each node (30000-32767 range)
  - Frontend uses NodePort 30001
  - Kind maps NodePort to host via extra_port_mappings
  - Accessible from outside the cluster
- **ClusterIP:** Internal-only service (default)
  - Backend uses ClusterIP on port 5000
  - Only accessible from within the cluster
  - Not exposed to external traffic

**GitOps Benefits:**
- **Declarative:** Desired state in Git
- **Auditable:** Git history = deployment history
- **Automated:** Changes trigger deployments
- **Rollback-friendly:** Git revert = application rollback
- **Consistent:** Same process across environments
