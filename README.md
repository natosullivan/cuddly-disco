# cuddly-disco.ai

![CI](https://github.com/natosullivan/cuddly-disco/workflows/CI/badge.svg)

A simple two-tier application that displays encouraging messages. The frontend shows text like "For all the SREs out there, here are some kind words from [location]: [encouraging message]", where the location comes from a local environment variable and the message is fetched from a Python backend API.

## Architecture

- **Frontend**: React + TypeScript + Vite (port 3000)
- **Backend**: Python + Flask (port 5000)
- Both services run in separate Docker containers

## Project Structure

```
.
├── apps/
│   ├── backend/          # Python Flask API
│   │   ├── app.py
│   │   ├── test_app.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   └── frontend/         # React TypeScript app
│       ├── src/
│       ├── tests/
│       ├── package.json
│       ├── vite.config.ts
│       └── Dockerfile
├── .env.example
└── README.md
```

## Prerequisites

- Docker
- Node.js 20+ (for local development)
- Python 3.11+ (for local development)

## Quick Start

### 1. Set up environment variables

Copy the example environment file and customize it:

```bash
cp .env.example .env
```

Edit `.env` and set your preferred values:
- `VITE_LOCATION`: Your location (e.g., "San Francisco")
- `VITE_BACKEND_URL`: Backend API URL (default: http://localhost:5000)

### 2. Run the Backend

```bash
cd apps/backend

# Build the Docker image
docker build -t kind-words-backend .

# Run the container
docker run -p 5000:5000 kind-words-backend
```

The backend API will be available at http://localhost:5000

### 3. Run the Frontend

In a new terminal:

```bash
cd apps/frontend

# Build the Docker image
docker build -t kind-words-frontend .

# Run the container with environment variables
docker run -p 3000:3000 \
  -e VITE_LOCATION="San Francisco" \
  -e VITE_BACKEND_URL="http://localhost:5000" \
  kind-words-frontend
```

The frontend will be available at http://localhost:3000

## Running Tests

### Backend Tests

```bash
cd apps/backend

# Install dependencies
pip install -r requirements.txt

# Run tests
pytest test_app.py
```

### Frontend Tests

```bash
cd apps/frontend

# Install dependencies
npm install

# Run tests
npm test
```

## Continuous Integration & Deployment

This project uses GitHub Actions for automated testing, versioning, and deployment. The CI/CD pipeline includes:

### Unit Tests (Parallel)
- ✅ **Frontend Tests**: Runs Vitest tests for React components
- ✅ **Backend Tests**: Runs pytest tests for Flask API
- **Pipeline fails if either test suite fails**

### Container Build & Test
- ✅ **Build Docker Images**: Builds both backend and frontend containers and saves them as artifacts
- ✅ **Container Integration Tests**: Loads built images and runs integration tests
  - Depends on all unit tests passing
  - Runs containers and verifies they start correctly
  - Tests backend API endpoints (health check, message endpoint)
  - Tests frontend accessibility and content
  - Validates container networking and communication
  - Shows container logs on failure for debugging

### Semantic Versioning (Main Branch Only)
- ✅ **Automatic Version Management**: Uses [semantic-release](https://github.com/semantic-release/semantic-release) to automatically determine version numbers
- ✅ **Git Tags**: Creates version tags based on conventional commits
- ✅ **Release Notes**: Automatically generates GitHub releases with changelog
- **Commit Convention**:
  - `fix:` commits trigger patch releases (1.0.x)
  - `feat:` commits trigger minor releases (1.x.0)
  - `BREAKING CHANGE:` in commit body triggers major releases (x.0.0)

### Container Publishing (After Release)
- ✅ **GitHub Container Registry**: Publishes Docker images to `ghcr.io`
- ✅ **Version Tagging**: Images are tagged with both semantic version and `latest`
- ✅ **Image Names**:
  - `ghcr.io/natosullivan/cuddly-disco/backend:VERSION`
  - `ghcr.io/natosullivan/cuddly-disco/frontend:VERSION`

The build job creates reusable Docker image artifacts (retained for 1 day) that can be used by multiple downstream jobs. This approach saves time by building images once and enables both testing and publishing from the same artifacts.

The workflow is defined in `.github/workflows/ci.yml`, test scripts are in `.github/scripts/`, and semantic-release configuration is in `.releaserc.json`.

## API Endpoints

### Backend

- `GET /api/message` - Returns a random encouraging message
  ```json
  {
    "message": "Your pipeline is green"
  }
  ```

- `GET /health` - Health check endpoint
  ```json
  {
    "status": "healthy"
  }
  ```

## Features

- ✅ Frontend runs independently even if backend is unavailable
- ✅ Displays fallback message if API call fails
- ✅ Environment variable configuration for location
- ✅ Random encouraging messages from backend
- ✅ Comprehensive test coverage for both services
- ✅ Containerized deployment with Docker

## Development

### Backend Development

```bash
cd apps/backend
pip install -r requirements.txt
python app.py
```

### Frontend Development

```bash
cd apps/frontend
npm install
npm run dev
```

Set environment variables in `apps/frontend/.env.local`:
```
VITE_LOCATION=San Francisco
VITE_BACKEND_URL=http://localhost:5000
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VITE_LOCATION` | Location displayed in the message | "Unknown" |
| `VITE_BACKEND_URL` | Backend API URL | "http://localhost:5000" |

## Encouraging Messages

The backend randomly selects from the following messages:

- Your pipeline is green
- Your tests are well-written and stable
- Your friends and family understand what you do
- Your friends and family appreciate your humerous work stories
- That joke you told in your meeting was funny. If your coworkers weren't on mute, you would have heard them laughing
