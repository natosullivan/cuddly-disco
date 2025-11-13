#!/bin/bash

# Test 03: Istio Health
# Validates that Istio and Gateway API are properly installed
# Note: This test is only applicable to dev and prod clusters (not mgmt)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assertions.sh"
source "$SCRIPT_DIR/../lib/k8s-helpers.sh"

# Test parameters
CLUSTER_NAME=${1:-""}

echo "=========================================="
echo "Test 03: Istio Health Check"
echo "Cluster: $CLUSTER_NAME"
echo "=========================================="
echo ""

# Test 1: Check if istio-system namespace exists
echo "Checking Istio namespace..."
if ! check_namespace "istio-system"; then
    echo "SKIP: istio-system namespace not found (likely mgmt cluster)"
    exit 0
fi
print_test_result "PASS" "istio-system namespace exists"

# Test 2: Check Istio pods exist
echo ""
echo "Checking Istio pods..."
ISTIO_POD_COUNT=$(get_pod_count "istio-system")
assert_gte "$ISTIO_POD_COUNT" 1 "At least one Istio pod exists"

# Test 3: Wait for Istio pods to be ready
echo ""
echo "Waiting for Istio pods to be ready..."
if wait_for_pods "istio-system" 90; then
    print_test_result "PASS" "Istio pods are ready"
else
    print_test_result "FAIL" "Istio pods failed to become ready within timeout"
fi

# Test 4: Check that all Istio pods are running
ISTIO_RUNNING=$(get_pod_count_by_status "istio-system" "Running")
assert_gte "$ISTIO_RUNNING" 1 "At least one Istio pod is Running"

# Test 5: Check for istiod deployment
echo ""
echo "Checking Istio components..."
assert_success "istiod deployment exists" check_resource_exists "deployment" "istiod" "istio-system"

# Test 6: Check for Gateway-managed deployment
# Note: With Gateway API deployment controller, Istio automatically creates
# a deployment named <gateway-name>-istio when a Gateway resource is created
GATEWAY_DEPLOYMENT=$(kubectl get deployment -n istio-system -l gateway.networking.k8s.io/gateway-name=cuddly-disco-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$GATEWAY_DEPLOYMENT" ]; then
    print_test_result "PASS" "Gateway deployment exists ($GATEWAY_DEPLOYMENT)"
else
    print_test_result "FAIL" "Gateway deployment not found for cuddly-disco-gateway"
fi

# Test 7: Check for Gateway API CRDs
echo ""
echo "Checking Gateway API CRDs..."
assert_success "Gateway CRD exists" kubectl get crd gateways.gateway.networking.k8s.io &>/dev/null
assert_success "HTTPRoute CRD exists" kubectl get crd httproutes.gateway.networking.k8s.io &>/dev/null
assert_success "GatewayClass CRD exists" kubectl get crd gatewayclasses.gateway.networking.k8s.io &>/dev/null

# Test 8: Check for Istio GatewayClass
echo ""
echo "Checking GatewayClass..."
assert_success "istio GatewayClass exists" kubectl get gatewayclass istio &>/dev/null

# Test 9: Check for cuddly-disco Gateway
echo ""
echo "Checking cuddly-disco Gateway..."
if kubectl get gateway cuddly-disco-gateway -n istio-system &>/dev/null; then
    print_test_result "PASS" "cuddly-disco-gateway exists"

    # Test 10: Check Gateway status
    echo ""
    echo "Checking Gateway status..."

    # Wait a bit for Gateway to be programmed
    sleep 3

    GATEWAY_PROGRAMMED=$(kubectl get gateway cuddly-disco-gateway -n istio-system -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "Unknown")

    if [ "$GATEWAY_PROGRAMMED" = "True" ]; then
        print_test_result "PASS" "Gateway is Programmed"
    else
        print_test_result "FAIL" "Gateway is not Programmed (status: $GATEWAY_PROGRAMMED)"
    fi
else
    print_test_result "FAIL" "cuddly-disco-gateway not found"
fi

# Test 11: Check Gateway service type
echo ""
echo "Checking Gateway service..."
# The service name is <gateway-name>-istio (e.g., cuddly-disco-gateway-istio)
GATEWAY_SERVICE_NAME=$(kubectl get svc -n istio-system -l gateway.networking.k8s.io/gateway-name=cuddly-disco-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "NotFound")
GATEWAY_SERVICE_TYPE=$(kubectl get svc "$GATEWAY_SERVICE_NAME" -n istio-system -o jsonpath='{.spec.type}' 2>/dev/null || echo "NotFound")

if [ "$GATEWAY_SERVICE_TYPE" = "NodePort" ] || [ "$GATEWAY_SERVICE_TYPE" = "LoadBalancer" ]; then
    print_test_result "PASS" "Gateway service has type: $GATEWAY_SERVICE_TYPE ($GATEWAY_SERVICE_NAME)"
else
    print_test_result "FAIL" "Gateway service type is not NodePort or LoadBalancer (got: $GATEWAY_SERVICE_TYPE for $GATEWAY_SERVICE_NAME)"
fi

# Print Istio info summary
echo ""
echo "=========================================="
echo "Istio Information Summary"
echo "=========================================="
echo "Istio Pods:"
kubectl get pods -n istio-system 2>/dev/null || echo "Failed to get Istio pods"
echo ""
echo "Gateway:"
kubectl get gateway -n istio-system 2>/dev/null || echo "No Gateway found"
echo ""
echo "Gateway Services:"
kubectl get svc -n istio-system -l gateway.networking.k8s.io/gateway-name 2>/dev/null || echo "No gateway services found"

# Print test summary
print_test_summary "03-istio-health.sh"
