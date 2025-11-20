# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Documentation Index

- **[CI/CD Pipeline](./docs/CI-CD.md)** - GitHub Actions workflow, semantic release, container publishing
- **[Kubernetes Deployment](./docs/KUBERNETES-DEPLOYMENT.md)** - Infrastructure setup, single/multi-cluster deployment, troubleshooting

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

## Deployment

For deployment to Kubernetes and CI/CD pipeline details, see:

- **[CI/CD Pipeline](./docs/CI-CD.md)** - GitHub Actions workflow, testing, semantic release, container publishing
- **[Kubernetes Deployment](./docs/KUBERNETES-DEPLOYMENT.md)** - Infrastructure setup, single-cluster and multi-cluster deployment, GitOps workflow, troubleshooting
