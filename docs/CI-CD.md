# CI/CD Pipeline

This document describes the GitHub Actions continuous integration and deployment pipeline for cuddly-disco.

## Overview

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

## Job Dependencies

The pipeline ensures quality gates:
- `container-tests` depends on `frontend-tests`, `backend-tests`, and `build-containers`
- **If any test fails, the pipeline stops and no images are published**
- `semantic-release` runs only on main branch after all tests pass
- `publish-images` runs only if a new release was created
- `update-helm-charts` runs only if images were successfully published

## Container Build Job

The `build-containers` job creates reusable Docker images:
1. Builds both backend and frontend Docker images
2. Saves images as tar files using `docker save`
3. Uploads images as GitHub Actions artifacts (retained for 1 day)
4. These artifacts can be reused by multiple downstream jobs (testing, publishing, etc.)

## Container Integration Tests

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

## Semantic Release

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

## Container Publishing

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

## Helm Chart Version Updates

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

### Setting up the Bot Token

1. Create a GitHub Personal Access Token (PAT) with `repo` scope
2. Add it as a repository secret named `BOT_GITHUB_TOKEN`
3. The token enables the version bump commit to trigger ArgoCD's Git polling/webhooks

## Pipeline Architecture Benefits

This architecture ensures:
- Docker containers are tested before deployment
- Version numbers are consistent across Git tags, Docker images, and Helm charts
- Images are only published after all tests pass
- Helm charts are automatically updated when new versions are released
- ArgoCD can automatically deploy new versions via GitOps
- No manual version management required

## See Also

- [Development Guide](../CLAUDE.md) - Local development and testing
- [Kubernetes Deployment](./KUBERNETES-DEPLOYMENT.md) - How deployed containers run in K8s
