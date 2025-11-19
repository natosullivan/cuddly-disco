#!/bin/bash

# Cluster Deployment Automation Tool
# Automates creation, validation, and application deployment across all Kubernetes clusters
#
# Usage:
#   ./deploy-clusters.sh                          # Deploy all clusters (multi-cluster mode)
#   ./deploy-clusters.sh --exclude mgmt           # Skip mgmt cluster
#   ./deploy-clusters.sh --clusters dev           # Deploy only dev cluster
#   ./deploy-clusters.sh --mode single            # Use single-cluster ArgoCD mode
#   ./deploy-clusters.sh --skip-apps              # Only deploy infrastructure, skip apps
#   ./deploy-clusters.sh --infra-only             # Same as --skip-apps
#   ./deploy-clusters.sh --help                   # Show help

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMOKE_TESTS_DIR="$SCRIPT_DIR/smoke-tests"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default configuration
CLUSTERS_TO_DEPLOY=("dev" "prod" "mgmt")
EXCLUDED_CLUSTERS=()
DEPLOYMENT_MODE="multi"  # "multi" or "single"
SKIP_APPS=false
START_TIME=$(date +%s)

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Print section header
print_header() {
    echo ""
    print_msg "$BLUE" "=========================================="
    print_msg "$BLUE" "$1"
    print_msg "$BLUE" "=========================================="
    echo ""
}

# Print usage
print_usage() {
    cat << EOF
Cluster Deployment Automation Tool

Usage:
  $0 [options]

Options:
  --clusters <list>     Comma-separated list of clusters to deploy (dev,prod,mgmt)
                        Example: --clusters dev,prod

  --exclude <list>      Comma-separated list of clusters to exclude
                        Example: --exclude mgmt

  --mode <mode>         ArgoCD deployment mode: "multi" (default) or "single"
                        multi  = ApplicationSet deployed to mgmt cluster
                        single = Applications deployed directly to each cluster

  --skip-apps           Skip application deployment (infrastructure only)
  --infra-only          Same as --skip-apps

  --help, -h            Show this help message

Examples:
  # Deploy all clusters with multi-cluster mode (default)
  $0

  # Deploy only dev and prod (skip mgmt)
  $0 --exclude mgmt

  # Deploy only dev cluster
  $0 --clusters dev

  # Deploy with single-cluster mode
  $0 --mode single

  # Deploy infrastructure only, no apps
  $0 --skip-apps

  # Deploy dev/prod infrastructure, then deploy apps via mgmt
  $0 --exclude mgmt --infra-only   # First run
  $0 --clusters mgmt               # Second run

Environment Variables:
  DEPLOYMENT_MODE       Override deployment mode (multi or single)

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clusters)
                IFS=',' read -ra CLUSTERS_TO_DEPLOY <<< "$2"
                shift 2
                ;;
            --exclude)
                IFS=',' read -ra EXCLUDED_CLUSTERS <<< "$2"
                shift 2
                ;;
            --mode)
                DEPLOYMENT_MODE="$2"
                if [[ "$DEPLOYMENT_MODE" != "multi" && "$DEPLOYMENT_MODE" != "single" ]]; then
                    print_msg "$RED" "ERROR: Invalid mode '$DEPLOYMENT_MODE'. Must be 'multi' or 'single'"
                    exit 1
                fi
                shift 2
                ;;
            --skip-apps|--infra-only)
                SKIP_APPS=true
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                print_msg "$RED" "ERROR: Unknown option: $1"
                echo ""
                print_usage
                exit 1
                ;;
        esac
    done

    # Apply exclusions
    if [ ${#EXCLUDED_CLUSTERS[@]} -gt 0 ]; then
        for exclude in "${EXCLUDED_CLUSTERS[@]}"; do
            CLUSTERS_TO_DEPLOY=("${CLUSTERS_TO_DEPLOY[@]/$exclude}")
        done
        # Remove empty elements
        CLUSTERS_TO_DEPLOY=("${CLUSTERS_TO_DEPLOY[@]}")
    fi
}

# Check if cluster exists (Docker container running)
cluster_exists() {
    local cluster_name=$1
    docker ps --format '{{.Names}}' | grep -q "kind-${cluster_name}-control-plane"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing_tools=()

    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi

    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_msg "$RED" "ERROR: Missing required tools: ${missing_tools[*]}"
        print_msg "$YELLOW" "Please install the missing tools and try again."
        exit 1
    fi

    print_msg "$GREEN" "✓ All prerequisites met (docker, kubectl, terraform)"
}

# Deploy a single cluster
deploy_cluster() {
    local cluster_name=$1
    local cluster_dir="$SCRIPT_DIR/$cluster_name"

    print_header "Deploying Cluster: kind-$cluster_name"

    # Check if cluster already exists
    if cluster_exists "$cluster_name"; then
        print_msg "$YELLOW" "⚠ Cluster kind-$cluster_name already exists"
        print_msg "$CYAN" "Skipping terraform apply, will run validation only"
        echo ""
        return 0
    fi

    # Check if directory exists
    if [ ! -d "$cluster_dir" ]; then
        print_msg "$RED" "ERROR: Cluster directory not found: $cluster_dir"
        return 1
    fi

    print_msg "$CYAN" "→ Running terraform init..."
    cd "$cluster_dir"
    if [ "$cluster_name" = "mgmt" ]; then
        # Mgmt cluster needs -upgrade for ArgoCD provider
        terraform init -upgrade
    else
        terraform init
    fi

    print_msg "$CYAN" "→ Running terraform apply..."
    terraform apply -auto-approve

    print_msg "$GREEN" "✓ Cluster kind-$cluster_name created successfully"
    echo ""

    # Return to script directory
    cd "$SCRIPT_DIR"
}

# Run smoke tests for a cluster
run_smoke_tests() {
    local cluster_name=$1
    local skip_app_tests=${2:-false}

    print_header "Running Smoke Tests: kind-$cluster_name"

    # Export deployment mode for smoke tests
    export DEPLOYMENT_MODE="$DEPLOYMENT_MODE"

    cd "$SMOKE_TESTS_DIR"
    if [ "$skip_app_tests" = "true" ]; then
        # Run infrastructure tests only (tests 01-03)
        # We'll manually run them instead of using run-smoke-tests.sh
        print_msg "$CYAN" "→ Running infrastructure tests only (skipping app tests)"

        # Switch to cluster context
        export KUBECONFIG="$HOME/.kube/kind-kind-${cluster_name}"

        # Run tests 01-03
        bash tests/01-cluster-health.sh "kind-$cluster_name" || true
        bash tests/02-argocd-health.sh "kind-$cluster_name" || true

        # Only run Istio test for dev/prod
        if [[ "$cluster_name" = "dev" || "$cluster_name" = "prod" ]]; then
            bash tests/03-istio-health.sh "kind-$cluster_name" || true
        fi
    else
        # Run all tests including app tests
        bash run-smoke-tests.sh "kind-$cluster_name"
    fi

    cd "$SCRIPT_DIR"
    print_msg "$GREEN" "✓ Smoke tests completed for kind-$cluster_name"
    echo ""
}

# Wait for ArgoCD Application to sync
# Usage: wait_for_argocd_sync <app-name> <namespace> <timeout-seconds>
wait_for_argocd_sync() {
    local app_name=$1
    local namespace=$2
    local timeout=${3:-300}
    local elapsed=0
    local interval=5

    while [ $elapsed -lt $timeout ]; do
        local sync_status=$(kubectl get application "$app_name" -n "$namespace" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
        local health_status=$(kubectl get application "$app_name" -n "$namespace" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "")

        if [ "$sync_status" = "Synced" ]; then
            print_msg "$GREEN" "  ✓ $app_name synced (health: $health_status)"
            return 0
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    print_msg "$YELLOW" "  ⚠ Timeout waiting for $app_name to sync (status: $sync_status)"
    return 1
}

# Deploy ArgoCD applications in single-cluster mode
deploy_apps_single_mode() {
    local cluster_name=$1

    print_header "Deploying Applications: kind-$cluster_name (Single-Cluster Mode)"

    export KUBECONFIG="$HOME/.kube/kind-kind-${cluster_name}"

    print_msg "$CYAN" "→ Deploying backend application..."
    kubectl apply -f "$SCRIPT_DIR/../k8s/argocd-apps/backend-app.yaml"

    print_msg "$CYAN" "→ Waiting for backend to sync..."
    wait_for_argocd_sync "backend" "argocd" 300 || true

    print_msg "$CYAN" "→ Deploying frontend application..."
    if [ "$cluster_name" = "dev" ]; then
        kubectl apply -f "$SCRIPT_DIR/../k8s/argocd-apps/frontend-app-dev.yaml"
    else
        kubectl apply -f "$SCRIPT_DIR/../k8s/argocd-apps/frontend-app.yaml"
    fi

    print_msg "$CYAN" "→ Waiting for frontend to sync..."
    wait_for_argocd_sync "frontend" "argocd" 300 || true

    print_msg "$GREEN" "✓ Applications deployed to kind-$cluster_name"
    echo ""
}

# Deploy ArgoCD ApplicationSet in multi-cluster mode
deploy_apps_multi_mode() {
    print_header "Deploying Applications: kind-mgmt (Multi-Cluster Mode)"

    export KUBECONFIG="$HOME/.kube/kind-kind-mgmt"

    print_msg "$CYAN" "→ Deploying team-apps ApplicationSet..."
    kubectl apply -f "$SCRIPT_DIR/../k8s/argocd-appsets/team-apps.yaml"

    print_msg "$CYAN" "→ Waiting for ApplicationSet to generate applications..."
    sleep 10

    print_msg "$CYAN" "→ Checking generated applications..."
    kubectl get applications -n argocd

    print_msg "$CYAN" "→ Waiting for applications to sync..."
    for app in backend-dev backend-prod frontend-dev frontend-prod; do
        print_msg "$CYAN" "  Waiting for $app..."
        wait_for_argocd_sync "$app" "argocd" 300 || true
    done

    print_msg "$GREEN" "✓ ApplicationSet deployed and applications synced"
    echo ""
}

# Print deployment summary
print_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    print_header "Deployment Summary"

    print_msg "$CYAN" "Clusters Deployed:"
    for cluster in "${CLUSTERS_TO_DEPLOY[@]}"; do
        if cluster_exists "$cluster"; then
            print_msg "$GREEN" "  ✓ kind-$cluster"
        else
            print_msg "$RED" "  ✗ kind-$cluster (failed or skipped)"
        fi
    done

    echo ""
    print_msg "$CYAN" "Deployment Mode: $DEPLOYMENT_MODE"
    print_msg "$CYAN" "Applications Deployed: $([ "$SKIP_APPS" = "true" ] && echo "No" || echo "Yes")"
    echo ""

    print_msg "$CYAN" "Access Information:"

    if cluster_exists "dev"; then
        echo ""
        print_msg "$YELLOW" "Dev Cluster (kind-dev):"
        print_msg "$NC" "  Kubeconfig: $HOME/.kube/kind-kind-dev"
        print_msg "$NC" "  ArgoCD UI: http://localhost:30080"
        print_msg "$NC" "  Frontend: http://dev.cuddly-disco.ai.localhost:3000"
        print_msg "$NC" "  Command: export KUBECONFIG=~/.kube/kind-kind-dev"

        if [ -f "$SCRIPT_DIR/dev/terraform.tfstate" ]; then
            print_msg "$NC" "  ArgoCD Password Command:"
            print_msg "$CYAN" "    cd $SCRIPT_DIR/dev && eval \$(terraform output -raw argocd_admin_password_command)"
        fi
    fi

    if cluster_exists "prod"; then
        echo ""
        print_msg "$YELLOW" "Prod Cluster (kind-prod):"
        print_msg "$NC" "  Kubeconfig: $HOME/.kube/kind-kind-prod"
        print_msg "$NC" "  ArgoCD UI: http://localhost:30081"
        print_msg "$NC" "  Frontend: http://cuddly-disco.ai.localhost:3001"
        print_msg "$NC" "  Command: export KUBECONFIG=~/.kube/kind-kind-prod"

        if [ -f "$SCRIPT_DIR/prod/terraform.tfstate" ]; then
            print_msg "$NC" "  ArgoCD Password Command:"
            print_msg "$CYAN" "    cd $SCRIPT_DIR/prod && eval \$(terraform output -raw argocd_admin_password_command)"
        fi
    fi

    if cluster_exists "mgmt"; then
        echo ""
        print_msg "$YELLOW" "Management Cluster (kind-mgmt):"
        print_msg "$NC" "  Kubeconfig: $HOME/.kube/kind-kind-mgmt"
        print_msg "$NC" "  ArgoCD UI: http://localhost:30082"
        print_msg "$NC" "  Command: export KUBECONFIG=~/.kube/kind-kind-mgmt"

        if [ -f "$SCRIPT_DIR/mgmt/terraform.tfstate" ]; then
            print_msg "$NC" "  ArgoCD Password Command:"
            print_msg "$CYAN" "    cd $SCRIPT_DIR/mgmt && eval \$(terraform output -raw argocd_admin_password_command)"
        fi

        print_msg "$NC" "  Registered Clusters:"
        export KUBECONFIG="$HOME/.kube/kind-kind-mgmt"
        kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster --no-headers 2>/dev/null | awk '{print "    - " $1}' || print_msg "$NC" "    (none)"
    fi

    echo ""
    print_msg "$CYAN" "Total Duration: ${minutes}m ${seconds}s"
    echo ""
    print_msg "$GREEN" "=========================================="
    print_msg "$GREEN" "Deployment Complete!"
    print_msg "$GREEN" "=========================================="
    echo ""
}

# Main deployment workflow
main() {
    parse_args "$@"

    print_header "Cluster Deployment Tool"
    print_msg "$CYAN" "Mode: $DEPLOYMENT_MODE"
    print_msg "$CYAN" "Clusters: ${CLUSTERS_TO_DEPLOY[*]}"
    print_msg "$CYAN" "Skip Apps: $SKIP_APPS"
    echo ""

    check_prerequisites

    # Determine which clusters need to be deployed
    local deploy_dev=false
    local deploy_prod=false
    local deploy_mgmt=false

    for cluster in "${CLUSTERS_TO_DEPLOY[@]}"; do
        case $cluster in
            dev) deploy_dev=true ;;
            prod) deploy_prod=true ;;
            mgmt) deploy_mgmt=true ;;
        esac
    done

    # Phase 1: Deploy dev and prod clusters in parallel
    print_header "Phase 1: Deploying Dev and Prod Clusters"

    local dev_pid=""
    local prod_pid=""

    if [ "$deploy_dev" = true ]; then
        print_msg "$CYAN" "→ Starting dev cluster deployment in background..."
        (deploy_cluster "dev") &
        dev_pid=$!
    fi

    if [ "$deploy_prod" = true ]; then
        print_msg "$CYAN" "→ Starting prod cluster deployment in background..."
        (deploy_cluster "prod") &
        prod_pid=$!
    fi

    # Wait for both to complete
    if [ -n "$dev_pid" ]; then
        print_msg "$CYAN" "→ Waiting for dev cluster..."
        wait $dev_pid || print_msg "$RED" "⚠ Dev cluster deployment had errors"
    fi

    if [ -n "$prod_pid" ]; then
        print_msg "$CYAN" "→ Waiting for prod cluster..."
        wait $prod_pid || print_msg "$RED" "⚠ Prod cluster deployment had errors"
    fi

    if [ "$deploy_dev" = true ] || [ "$deploy_prod" = true ]; then
        print_msg "$GREEN" "✓ Phase 1 complete"
    else
        print_msg "$YELLOW" "Phase 1 skipped (no dev/prod clusters selected)"
    fi

    # Phase 2: Run smoke tests on dev/prod (infrastructure only if apps will be deployed later)
    if [ "$deploy_dev" = true ]; then
        run_smoke_tests "dev" true  # Infrastructure tests only for now
    fi

    if [ "$deploy_prod" = true ]; then
        run_smoke_tests "prod" true  # Infrastructure tests only for now
    fi

    # Phase 3: Deploy management cluster (requires dev/prod to exist for multi-cluster mode)
    if [ "$deploy_mgmt" = true ]; then
        if [ "$DEPLOYMENT_MODE" = "multi" ]; then
            # Check that dev and prod state files exist
            if [ ! -f "$SCRIPT_DIR/dev/terraform.tfstate" ] || [ ! -f "$SCRIPT_DIR/prod/terraform.tfstate" ]; then
                print_msg "$YELLOW" "⚠ Warning: dev or prod terraform state not found"
                print_msg "$YELLOW" "  Mgmt cluster may not be able to register remote clusters"
                print_msg "$YELLOW" "  Continuing anyway..."
            fi
        fi

        deploy_cluster "mgmt"
        run_smoke_tests "mgmt" true  # Infrastructure tests only for now
    fi

    # Phase 4: Deploy applications (if not skipped)
    if [ "$SKIP_APPS" = false ]; then
        print_header "Phase 4: Deploying Applications"

        if [ "$DEPLOYMENT_MODE" = "multi" ]; then
            # Multi-cluster mode: deploy ApplicationSet to mgmt
            if [ "$deploy_mgmt" = true ]; then
                deploy_apps_multi_mode
            else
                print_msg "$YELLOW" "⚠ Skipping multi-cluster app deployment (mgmt cluster not deployed)"
            fi
        else
            # Single-cluster mode: deploy apps to each cluster
            if [ "$deploy_dev" = true ]; then
                deploy_apps_single_mode "dev"
            fi

            if [ "$deploy_prod" = true ]; then
                deploy_apps_single_mode "prod"
            fi
        fi

        # Phase 5: Run application smoke tests
        print_header "Phase 5: Running Application Tests"

        if [ "$deploy_dev" = true ]; then
            run_smoke_tests "dev" false
        fi

        if [ "$deploy_prod" = true ]; then
            run_smoke_tests "prod" false
        fi

        if [ "$deploy_mgmt" = true ] && [ "$DEPLOYMENT_MODE" = "multi" ]; then
            run_smoke_tests "mgmt" false
        fi
    else
        print_msg "$YELLOW" "Skipping application deployment (--skip-apps enabled)"
    fi

    # Print summary
    print_summary
}

# Run main function
main "$@"
