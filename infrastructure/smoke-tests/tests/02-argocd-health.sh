#!/bin/bash

# Test 02: ArgoCD Health
# Validates that ArgoCD is properly installed and accessible

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assertions.sh"
source "$SCRIPT_DIR/../lib/k8s-helpers.sh"

# Test parameters
CLUSTER_NAME=${1:-""}
ARGOCD_PORT=${2:-"30080"}  # Default port, can be overridden

echo "=========================================="
echo "Test 02: ArgoCD Health Check"
echo "Cluster: $CLUSTER_NAME"
echo "ArgoCD Port: $ARGOCD_PORT"
echo "=========================================="
echo ""

# Test 1: Check if argocd namespace exists
echo "Checking ArgoCD namespace..."
assert_success "argocd namespace exists" check_namespace "argocd"

# Test 2: Check ArgoCD pods exist
echo ""
echo "Checking ArgoCD pods..."
ARGOCD_POD_COUNT=$(get_pod_count "argocd")
assert_gte "$ARGOCD_POD_COUNT" 1 "At least one ArgoCD pod exists"

# Test 3: Wait for ArgoCD pods to be ready
echo ""
echo "Waiting for ArgoCD pods to be ready..."
if wait_for_pods "argocd" 60; then
    print_test_result "PASS" "ArgoCD pods are ready"
else
    print_test_result "FAIL" "ArgoCD pods failed to become ready within timeout"
fi

# Test 4: Check that all ArgoCD pods are running
ARGOCD_RUNNING=$(get_pod_count_by_status "argocd" "Running")
assert_gte "$ARGOCD_RUNNING" 1 "At least one ArgoCD pod is Running"

# Test 5: Check for ArgoCD server deployment
echo ""
echo "Checking ArgoCD components..."
assert_success "argocd-server deployment exists" check_resource_exists "deployment" "argocd-server" "argocd"

# Test 6: Check ArgoCD server service
assert_success "argocd-server service exists" check_resource_exists "service" "argocd-server" "argocd"

# Test 7: Check if ArgoCD UI is accessible on NodePort
echo ""
echo "Checking ArgoCD UI accessibility..."
ARGOCD_URL="http://localhost:$ARGOCD_PORT"

# Give it a few seconds if pods just became ready
sleep 2

# Try to connect to ArgoCD UI (should return 200 or redirect)
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$ARGOCD_URL" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "302" ] || [ "$HTTP_STATUS" = "307" ]; then
    print_test_result "PASS" "ArgoCD UI is accessible at $ARGOCD_URL (HTTP $HTTP_STATUS)"
else
    print_test_result "FAIL" "ArgoCD UI is not accessible at $ARGOCD_URL (HTTP $HTTP_STATUS)"
fi

# Test 8: Check if admin password secret exists
echo ""
echo "Checking ArgoCD credentials..."
assert_success "argocd-initial-admin-secret exists" check_resource_exists "secret" "argocd-initial-admin-secret" "argocd"

# Test 9: Verify we can retrieve admin password
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
assert_not_empty "$ADMIN_PASSWORD" "Can retrieve ArgoCD admin password"

# Print ArgoCD info summary
echo ""
echo "=========================================="
echo "ArgoCD Information Summary"
echo "=========================================="
echo "ArgoCD UI: $ARGOCD_URL"
echo "Username: admin"
if [ -n "$ADMIN_PASSWORD" ]; then
    echo "Password: $ADMIN_PASSWORD"
fi
echo ""
echo "ArgoCD Pods:"
kubectl get pods -n argocd 2>/dev/null || echo "Failed to get ArgoCD pods"

# Print test summary
print_test_summary "02-argocd-health.sh"
