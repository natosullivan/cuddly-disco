#!/bin/bash

# Main smoke test runner for Kubernetes clusters
# Usage: ./run-smoke-tests.sh [cluster-name|all]
# Examples:
#   ./run-smoke-tests.sh kind-dev
#   ./run-smoke-tests.sh kind-prod
#   ./run-smoke-tests.sh kind-mgmt
#   ./run-smoke-tests.sh all

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assertions.sh"
source "$SCRIPT_DIR/lib/k8s-helpers.sh"

# Color codes
BLUE='\033[0;34m'
NC='\033[0m'

# Cluster configurations
declare -A CLUSTER_PORTS
CLUSTER_PORTS["kind-dev"]="30080"
CLUSTER_PORTS["kind-prod"]="30081"
CLUSTER_PORTS["kind-mgmt"]="30082"

declare -A CLUSTER_HAS_ISTIO
CLUSTER_HAS_ISTIO["kind-dev"]="true"
CLUSTER_HAS_ISTIO["kind-prod"]="true"
CLUSTER_HAS_ISTIO["kind-mgmt"]="false"

# Function to print usage
print_usage() {
    echo "Usage: $0 [cluster-name|all]"
    echo ""
    echo "Cluster names:"
    echo "  kind-dev   - Development cluster"
    echo "  kind-prod  - Production cluster"
    echo "  kind-mgmt  - Management cluster"
    echo "  all        - Test all clusters"
    echo ""
    echo "Examples:"
    echo "  $0 kind-dev"
    echo "  $0 all"
}

# Function to run tests for a specific cluster
run_cluster_tests() {
    local cluster_name=$1
    local argocd_port=${CLUSTER_PORTS[$cluster_name]:-"30080"}
    local has_istio=${CLUSTER_HAS_ISTIO[$cluster_name]:-"false"}

    echo ""
    echo -e "${BLUE}=========================================="
    echo "Starting smoke tests for: $cluster_name"
    echo -e "==========================================${NC}"
    echo ""

    # Switch to cluster context
    echo "Switching to cluster context..."
    if ! switch_cluster_context "$cluster_name"; then
        echo -e "${RED}ERROR: Failed to switch to cluster context for $cluster_name${NC}"
        echo "Available contexts:"
        kubectl config get-contexts
        return 1
    fi

    echo "Current context: $(kubectl config current-context)"
    echo ""

    # Track overall test results
    local all_tests_passed=true

    # Run test 01: Cluster Health
    echo "Running Test 01: Cluster Health..."
    if bash "$SCRIPT_DIR/tests/01-cluster-health.sh" "$cluster_name"; then
        echo -e "${GREEN}Test 01 passed${NC}"
    else
        echo -e "${RED}Test 01 failed${NC}"
        all_tests_passed=false
    fi

    # Run test 02: ArgoCD Health
    echo ""
    echo "Running Test 02: ArgoCD Health..."
    if bash "$SCRIPT_DIR/tests/02-argocd-health.sh" "$cluster_name" "$argocd_port"; then
        echo -e "${GREEN}Test 02 passed${NC}"
    else
        echo -e "${RED}Test 02 failed${NC}"
        all_tests_passed=false
    fi

    # Run test 03: Istio Health (only if cluster has Istio)
    if [ "$has_istio" = "true" ]; then
        echo ""
        echo "Running Test 03: Istio Health..."
        if bash "$SCRIPT_DIR/tests/03-istio-health.sh" "$cluster_name"; then
            echo -e "${GREEN}Test 03 passed${NC}"
        else
            echo -e "${RED}Test 03 failed${NC}"
            all_tests_passed=false
        fi
    else
        echo ""
        echo "Skipping Test 03: Istio Health (cluster does not have Istio)"
    fi

    # Print final result for cluster
    echo ""
    echo -e "${BLUE}=========================================="
    echo "Smoke tests completed for: $cluster_name"
    if [ "$all_tests_passed" = true ]; then
        echo -e "${GREEN}Status: PASSED${NC}"
        echo -e "==========================================${NC}"
        return 0
    else
        echo -e "${RED}Status: FAILED${NC}"
        echo -e "==========================================${NC}"
        return 1
    fi
}

# Main script logic
main() {
    local cluster_name=${1:-""}

    if [ -z "$cluster_name" ]; then
        echo "ERROR: No cluster name provided"
        echo ""
        print_usage
        exit 1
    fi

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo "ERROR: kubectl not found. Please install kubectl."
        exit 1
    fi

    if [ "$cluster_name" = "all" ]; then
        # Run tests for all clusters
        echo "Running smoke tests for all clusters..."
        local overall_result=0

        for cluster in "kind-dev" "kind-prod" "kind-mgmt"; do
            # Check if kubeconfig file exists for cluster
            local kubeconfig_file="$HOME/.kube/kind-${cluster}"
            if [ -f "$kubeconfig_file" ]; then
                # Check if cluster is accessible
                if KUBECONFIG="$kubeconfig_file" kubectl cluster-info &>/dev/null; then
                    if ! run_cluster_tests "$cluster"; then
                        overall_result=1
                    fi
                else
                    echo ""
                    echo -e "${YELLOW}Skipping $cluster: cluster not running${NC}"
                fi
            else
                echo ""
                echo -e "${YELLOW}Skipping $cluster: kubeconfig not found${NC}"
            fi
        done

        echo ""
        echo "=========================================="
        if [ $overall_result -eq 0 ]; then
            echo -e "${GREEN}All cluster tests PASSED${NC}"
        else
            echo -e "${RED}Some cluster tests FAILED${NC}"
        fi
        echo "=========================================="
        exit $overall_result

    elif [ "$cluster_name" = "--help" ] || [ "$cluster_name" = "-h" ]; then
        print_usage
        exit 0

    else
        # Run tests for specific cluster
        if run_cluster_tests "$cluster_name"; then
            exit 0
        else
            exit 1
        fi
    fi
}

# Run main function
main "$@"
