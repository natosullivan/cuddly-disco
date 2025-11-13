#!/bin/bash

# Test 01: Cluster Health
# Validates that the Kubernetes cluster is healthy and all nodes are ready

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assertions.sh"
source "$SCRIPT_DIR/../lib/k8s-helpers.sh"

# Test parameters
CLUSTER_NAME=${1:-""}

echo "=========================================="
echo "Test 01: Cluster Health Check"
echo "Cluster: $CLUSTER_NAME"
echo "=========================================="
echo ""

# Test 1: Check if kubectl is configured and can connect
echo "Testing kubectl connectivity..."
assert_success "kubectl can connect to cluster" kubectl cluster-info &>/dev/null

# Test 2: Check that at least one node exists
echo ""
echo "Checking nodes..."
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
assert_gte "$NODE_COUNT" 1 "At least one node exists in cluster"

# Test 3: Check that all nodes are Ready
if [ "$NODE_COUNT" -gt 0 ]; then
    NOT_READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" | wc -l)
    assert_equals "0" "$NOT_READY_COUNT" "All nodes are in Ready state"
fi

# Test 4: Check kube-system namespace exists
echo ""
echo "Checking kube-system namespace..."
assert_success "kube-system namespace exists" check_namespace "kube-system"

# Test 5: Check that kube-system pods are running
KUBE_SYSTEM_RUNNING=$(get_pod_count_by_status "kube-system" "Running")
assert_gte "$KUBE_SYSTEM_RUNNING" 1 "At least one kube-system pod is Running"

# Test 6: Check for pods in error states
echo ""
echo "Checking for pods in error states..."
CRASHLOOP_COUNT=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep "CrashLoopBackOff" | wc -l)
ERROR_COUNT=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep "Error" | wc -l)

assert_equals "0" "$CRASHLOOP_COUNT" "No pods in CrashLoopBackOff state"
assert_equals "0" "$ERROR_COUNT" "No pods in Error state"

# Test 7: Check core components (coredns, etc.)
echo ""
echo "Checking core components..."
COREDNS_COUNT=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l)
if [ "$COREDNS_COUNT" -gt 0 ]; then
    COREDNS_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running")
    assert_gte "$COREDNS_RUNNING" 1 "CoreDNS pods are Running"
fi

# Print cluster info summary
echo ""
echo "=========================================="
echo "Cluster Information Summary"
echo "=========================================="
kubectl get nodes 2>/dev/null || echo "Failed to get nodes"
echo ""
echo "Namespaces:"
kubectl get namespaces 2>/dev/null | head -10 || echo "Failed to get namespaces"

# Print test summary
print_test_summary "01-cluster-health.sh"
