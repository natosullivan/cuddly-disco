#!/bin/bash

# Test 04: Application Deployment Health
# Validates that ArgoCD applications are deployed and accessible
# Tests backend and frontend deployment across different modes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assertions.sh"
source "$SCRIPT_DIR/../lib/k8s-helpers.sh"

# Test parameters
CLUSTER_NAME=${1:-""}
DEPLOYMENT_MODE=${2:-"multi"}  # multi or single
GATEWAY_PORT=${3:-"3000"}       # Port for Gateway access (3000 for dev, 3001 for prod)
HOSTNAME=${4:-""}               # Hostname for curl Host header

echo "=========================================="
echo "Test 04: Application Deployment Check"
echo "Cluster: $CLUSTER_NAME"
echo "Mode: $DEPLOYMENT_MODE"
echo "Gateway Port: $GATEWAY_PORT"
echo "Hostname: $HOSTNAME"
echo "=========================================="
echo ""

# Determine which applications to check based on cluster and mode
if [ "$CLUSTER_NAME" = "kind-mgmt" ]; then
    if [ "$DEPLOYMENT_MODE" = "multi" ]; then
        # Multi-cluster mode: check ApplicationSet and generated apps
        APPS_TO_CHECK=("backend-dev" "backend-prod" "frontend-dev" "frontend-prod")
        CHECK_APPLICATIONSET=true
        CHECK_LOCAL_APPS=false
    else
        # Mgmt cluster in single mode - no apps deployed here
        echo "SKIP: No applications deployed to mgmt cluster in single-cluster mode"
        exit 0
    fi
else
    # Dev or prod cluster
    if [ "$DEPLOYMENT_MODE" = "multi" ]; then
        # Multi-cluster mode: apps deployed by mgmt cluster to target clusters
        # We don't check ArgoCD apps here, just the actual deployed resources
        CHECK_APPLICATIONSET=false
        CHECK_LOCAL_APPS=false
        CHECK_DEPLOYED_RESOURCES=true
    else
        # Single-cluster mode: apps deployed directly to this cluster
        APPS_TO_CHECK=("backend" "frontend")
        CHECK_APPLICATIONSET=false
        CHECK_LOCAL_APPS=true
        CHECK_DEPLOYED_RESOURCES=true
    fi
fi

# Test 1: Check for ApplicationSet (mgmt cluster, multi mode)
if [ "$CHECK_APPLICATIONSET" = true ]; then
    echo "Checking ApplicationSet..."
    if kubectl get applicationset team-apps -n argocd &>/dev/null; then
        print_test_result "PASS" "ApplicationSet 'team-apps' exists"

        # Show generated applications
        echo ""
        echo "Generated applications:"
        kubectl get applications -n argocd -l app.kubernetes.io/instance=team-apps --no-headers 2>/dev/null | awk '{print "  - " $1 " (sync: " $2 ", health: " $3 ")"}'
    else
        print_test_result "FAIL" "ApplicationSet 'team-apps' not found"
    fi
    echo ""
fi

# Test 2: Check ArgoCD Applications (mgmt or single mode)
if [ "$CHECK_APPLICATIONSET" = true ] || [ "$CHECK_LOCAL_APPS" = true ]; then
    for app in "${APPS_TO_CHECK[@]}"; do
        echo "Checking ArgoCD application: $app"

        # Check if application exists
        if ! kubectl get application "$app" -n argocd &>/dev/null; then
            print_test_result "FAIL" "Application '$app' not found"
            continue
        fi
        print_test_result "PASS" "Application '$app' exists"

        # Wait for sync (with reasonable timeout)
        echo "  Waiting for sync..."
        if wait_for_argocd_sync "$app" 180 "argocd"; then
            print_test_result "PASS" "  Application '$app' is Synced"
        else
            print_test_result "FAIL" "  Application '$app' failed to sync"
        fi

        # Check health
        echo "  Checking health..."
        if check_application_health "$app" "argocd"; then
            print_test_result "PASS" "  Application '$app' is Healthy"
        else
            print_test_result "WARN" "  Application '$app' is not yet Healthy (may still be starting)"
        fi

        echo ""
    done
fi

# Test 3: Check deployed resources (dev/prod clusters)
if [ "$CHECK_DEPLOYED_RESOURCES" = true ]; then
    echo "=========================================="
    echo "Checking Deployed Resources"
    echo "=========================================="
    echo ""

    # Test 3a: Backend namespace and pods
    echo "Checking backend deployment..."
    if check_namespace "backend"; then
        print_test_result "PASS" "Backend namespace exists"

        # Wait for backend pods
        if wait_for_pods "backend" 120; then
            print_test_result "PASS" "Backend pods are ready"
        else
            print_test_result "FAIL" "Backend pods failed to become ready"
        fi

        # Check backend service (any service in the namespace)
        if kubectl get svc -n backend --no-headers 2>/dev/null | grep -q .; then
            BACKEND_SVC=$(kubectl get svc -n backend --no-headers 2>/dev/null | head -1 | awk '{print $1}')
            print_test_result "PASS" "Backend service exists ($BACKEND_SVC)"
        else
            print_test_result "FAIL" "Backend service not found"
        fi
    else
        print_test_result "FAIL" "Backend namespace not found"
    fi
    echo ""

    # Test 3b: Frontend namespace and pods
    echo "Checking frontend deployment..."
    if check_namespace "frontend"; then
        print_test_result "PASS" "Frontend namespace exists"

        # Wait for frontend pods
        if wait_for_pods "frontend" 120; then
            print_test_result "PASS" "Frontend pods are ready"
        else
            print_test_result "FAIL" "Frontend pods failed to become ready"
        fi

        # Check frontend service (any service in the namespace)
        if kubectl get svc -n frontend --no-headers 2>/dev/null | grep -q .; then
            FRONTEND_SVC=$(kubectl get svc -n frontend --no-headers 2>/dev/null | head -1 | awk '{print $1}')
            print_test_result "PASS" "Frontend service exists ($FRONTEND_SVC)"
        else
            print_test_result "FAIL" "Frontend service not found"
        fi

        # Check HTTPRoute (any HTTPRoute in the namespace)
        if kubectl get httproute -n frontend &>/dev/null && [ "$(kubectl get httproute -n frontend --no-headers 2>/dev/null | wc -l)" -gt 0 ]; then
            print_test_result "PASS" "Frontend HTTPRoute exists"
        else
            print_test_result "FAIL" "Frontend HTTPRoute not found"
        fi
    else
        print_test_result "FAIL" "Frontend namespace not found"
    fi
    echo ""

    # Test 4: Test backend API endpoints (via port-forward)
    echo "=========================================="
    echo "Testing Backend API Endpoints"
    echo "=========================================="
    echo ""

    # Start port-forward in background
    echo "Starting port-forward to backend service..."
    # Get the first backend service
    BACKEND_SVC=$(kubectl get svc -n backend --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    if [ -z "$BACKEND_SVC" ]; then
        print_test_result "FAIL" "No backend service found for port-forward"
        echo ""
    else
        kubectl port-forward -n backend svc/$BACKEND_SVC 5000:5000 >/dev/null 2>&1 &
        PORT_FORWARD_PID=$!

        # Wait for port-forward to be ready
        sleep 3

        # Test health endpoint
        echo "Testing backend /health endpoint..."
        if test_http_endpoint "http://localhost:5000/health" 200; then
            print_test_result "PASS" "Backend /health endpoint returns 200"
        else
            print_test_result "FAIL" "Backend /health endpoint failed"
        fi

        # Test message endpoint
        echo "Testing backend /api/message endpoint..."
        if test_http_endpoint "http://localhost:5000/api/message" 200; then
            print_test_result "PASS" "Backend /api/message endpoint returns 200"

            # Verify response is valid JSON with message field
            MESSAGE=$(curl -s http://localhost:5000/api/message 2>/dev/null | grep -o '"message"' || echo "")
            if [ -n "$MESSAGE" ]; then
                print_test_result "PASS" "Backend response contains 'message' field"
            else
                print_test_result "FAIL" "Backend response doesn't contain expected 'message' field"
            fi
        else
            print_test_result "FAIL" "Backend /api/message endpoint failed"
        fi

        # Kill port-forward
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
    echo ""

    # Test 5: Test frontend via Gateway
    echo "=========================================="
    echo "Testing Frontend via Gateway"
    echo "=========================================="
    echo ""

    # Only test if we have a Gateway (dev/prod, not mgmt)
    if check_namespace "istio-system" && kubectl get gateway cuddly-disco-gateway -n istio-system &>/dev/null; then
        echo "Testing frontend accessibility..."

        FRONTEND_URL="http://localhost:${GATEWAY_PORT}"

        if [ -n "$HOSTNAME" ]; then
            echo "Testing frontend at $FRONTEND_URL with Host header: $HOSTNAME"
            if test_http_endpoint "$FRONTEND_URL" 200 "$HOSTNAME"; then
                print_test_result "PASS" "Frontend accessible via Gateway"

                # Check that response contains expected content
                CONTENT=$(curl -s -H "Host:$HOSTNAME" "$FRONTEND_URL" 2>/dev/null)
                if echo "$CONTENT" | grep -q "cuddly-disco"; then
                    print_test_result "PASS" "Frontend returns expected content"
                else
                    print_test_result "WARN" "Frontend content doesn't contain 'cuddly-disco'"
                fi

                # Check that frontend could reach backend (look for message or fallback)
                if echo "$CONTENT" | grep -q "Unable to connect to backend"; then
                    print_test_result "WARN" "Frontend showing backend unavailable message"
                else
                    print_test_result "PASS" "Frontend successfully communicating with backend"
                fi
            else
                print_test_result "FAIL" "Frontend not accessible via Gateway"
            fi
        else
            echo "SKIP: No hostname provided for Gateway testing"
        fi
    else
        echo "SKIP: No Gateway found (expected for mgmt cluster)"
    fi
    echo ""
fi

# Print deployed resources summary
if [ "$CHECK_DEPLOYED_RESOURCES" = true ]; then
    echo "=========================================="
    echo "Deployed Resources Summary"
    echo "=========================================="

    if check_namespace "backend"; then
        echo ""
        echo "Backend Pods:"
        kubectl get pods -n backend 2>/dev/null || echo "  No pods found"
    fi

    if check_namespace "frontend"; then
        echo ""
        echo "Frontend Pods:"
        kubectl get pods -n frontend 2>/dev/null || echo "  No pods found"

        echo ""
        echo "HTTPRoute:"
        kubectl get httproute -n frontend 2>/dev/null || echo "  No HTTPRoute found"
    fi
fi

# Print test summary
print_test_summary "04-app-deployment.sh"
