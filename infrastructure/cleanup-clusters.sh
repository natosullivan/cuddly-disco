#!/bin/bash

# cleanup-clusters.sh - Delete all Kind clusters and Terraform state files
# Usage: ./cleanup-clusters.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Print header
print_header() {
    echo ""
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo ""
}

# Array of clusters to clean up
CLUSTERS=("dev" "prod" "mgmt" "localdev")

print_header "Cluster Cleanup Tool"

# Ask for confirmation
print_msg "$YELLOW" "This will delete the following Kind clusters and their Terraform state:"
for cluster in "${CLUSTERS[@]}"; do
    print_msg "$CYAN" "  - kind-$cluster"
done
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_msg "$YELLOW" "Cleanup cancelled."
    exit 0
fi

print_header "Deleting Kind Clusters"

# Delete Kind clusters
for cluster in "${CLUSTERS[@]}"; do
    if kind get clusters 2>/dev/null | grep -q "^kind-$cluster$"; then
        print_msg "$CYAN" "→ Deleting cluster: kind-$cluster"
        kind delete cluster --name "kind-$cluster"
        print_msg "$GREEN" "✓ Cluster kind-$cluster deleted"
    else
        print_msg "$YELLOW" "⊘ Cluster kind-$cluster does not exist"
    fi
done

print_header "Cleaning Up Terraform State"

# Clean up Terraform state files for each cluster
for cluster in "${CLUSTERS[@]}"; do
    cluster_dir="$SCRIPT_DIR/$cluster"

    if [ -d "$cluster_dir" ]; then
        print_msg "$CYAN" "→ Cleaning up $cluster directory"

        # Remove Terraform state files
        rm -f "$cluster_dir/terraform.tfstate"
        rm -f "$cluster_dir/terraform.tfstate.backup"
        rm -f "$cluster_dir/.terraform.lock.hcl"
        rm -rf "$cluster_dir/.terraform"

        # Remove generated gateway manifest files
        rm -f "$cluster_dir/gateway-*.yaml"

        print_msg "$GREEN" "✓ Cleaned up $cluster directory"
    else
        print_msg "$YELLOW" "⊘ Directory $cluster_dir does not exist"
    fi
done

print_header "Cleaning Up Kubeconfig Files"

# Clean up kubeconfig files
for cluster in "${CLUSTERS[@]}"; do
    kubeconfig_file="$HOME/.kube/kind-kind-$cluster"

    if [ -f "$kubeconfig_file" ]; then
        print_msg "$CYAN" "→ Removing kubeconfig: $kubeconfig_file"
        rm -f "$kubeconfig_file"
        print_msg "$GREEN" "✓ Removed $kubeconfig_file"
    else
        print_msg "$YELLOW" "⊘ Kubeconfig $kubeconfig_file does not exist"
    fi
done

print_header "Cleanup Summary"

print_msg "$GREEN" "✓ All clusters and Terraform state files have been cleaned up"
print_msg "$CYAN" ""
print_msg "$CYAN" "Next steps:"
print_msg "$CYAN" "  - Run ./deploy-clusters.sh to redeploy clusters"
print_msg "$CYAN" "  - Or run individual cluster deployments with specific flags"
echo ""
