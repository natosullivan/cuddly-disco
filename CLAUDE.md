# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cuddly-disco is a simple two-tier application that displays encouraging messages. The frontend shows "For all the SREs out there, here are some kind words from [location]: [message]", where the location comes from an environment variable and the message is fetched from a Python backend API.

**Tech Stack:**
- Frontend: React 18 + TypeScript + Vite (port 3000)
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

# Preview production build
npm preview

# Docker build and run
docker build -t kind-words-frontend .
docker run -p 3000:3000 \
  -e VITE_LOCATION="San Francisco" \
  -e VITE_BACKEND_URL="http://localhost:5000" \
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
- **Entry Point:** `src/main.tsx` renders the root `App` component
- **Main Component:** `src/App.tsx` handles all application logic
  - Fetches location from `VITE_LOCATION` environment variable
  - Makes API call to backend `/api/message` endpoint on mount
  - Displays fallback message if backend is unavailable
  - Uses CSS classes for error/success states
- **Testing:** Uses Vitest with React Testing Library, mocks fetch globally
- **Build System:** Vite configured to serve on 0.0.0.0:3000 for Docker compatibility

### Backend Architecture
- **Single File Application:** `app.py` contains all routes and logic
- **Routes:**
  - `GET /api/message` - Returns random encouraging message from MESSAGES list
  - `GET /health` - Health check endpoint
- **CORS:** Enabled for all origins to allow frontend communication
- **Testing:** Pytest with Flask test client, includes probabilistic test for randomness

### Environment Variables
Frontend requires two environment variables (set in `.env` or `.env.local`):
- `VITE_LOCATION` - Location string to display (default: "Unknown")
- `VITE_BACKEND_URL` - Backend API URL (default: "http://localhost:5000")

Copy `.env.example` to `.env` and customize values before running locally.

### Key Design Patterns
- Frontend is resilient - displays fallback message if backend is down
- Backend message pool is defined in `MESSAGES` constant in `app.py:8-14`
- Tests verify both happy path and error states
- Frontend uses TypeScript interfaces for type safety (`ApiResponse` in App.tsx:4-6)

## Testing Philosophy

### Frontend Tests (apps/frontend/tests/App.test.tsx)
- Tests cover all component states: loading, success, error
- Mocks `fetch` API globally using Vitest
- Verifies environment variable handling
- Checks CSS class application for styling states

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
   - Verifies React app loads correctly
   - Checks React app structure is correct
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
