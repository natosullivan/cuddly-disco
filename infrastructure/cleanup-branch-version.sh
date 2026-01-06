#!/bin/bash

# cleanup-branch-version.sh - Cleanup branch deployment
# Usage: ./cleanup-branch-version.sh <branch-name> [--dry-run] [-v]
#
# This script removes Helm values files for a branch deployment, triggering
# ArgoCD to automatically prune the associated Kubernetes resources.
#
# Examples:
#   ./cleanup-branch-version.sh feature/add-user-auth
#   ./cleanup-branch-version.sh test/cleanup-verification --dry-run
#   ./cleanup-branch-version.sh bugfix/timeout-issue -v

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Flags
DRY_RUN=false
VERBOSE=false
BRANCH_NAME=""

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

# Print error and exit
print_error() {
    print_msg "$RED" "❌ Error: $@"
}

# Print verbose message
print_verbose() {
    if [ "$VERBOSE" = true ]; then
        print_msg "$CYAN" "🔍 $@"
    fi
}

# Usage information
usage() {
    cat <<EOF
Usage: $0 <branch-name> [OPTIONS]

Cleanup branch deployment by removing Helm values files.
ArgoCD will automatically prune Kubernetes resources.

Arguments:
  branch-name      Name of the branch to cleanup (e.g., feature/add-user-auth)

Options:
  --dry-run        Show what would be deleted without making changes
  -v, --verbose    Enable verbose output
  -h, --help       Show this help message

Examples:
  $0 feature/add-user-auth
  $0 test/cleanup-verification --dry-run
  $0 bugfix/timeout-issue -v

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [ -z "$BRANCH_NAME" ]; then
                BRANCH_NAME="$1"
            else
                print_error "Multiple branch names provided: $BRANCH_NAME and $1"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate branch name provided
if [ -z "$BRANCH_NAME" ]; then
    print_error "Branch name is required"
    echo ""
    usage
    exit 1
fi

# Safety check: never cleanup main
if [ "$BRANCH_NAME" = "main" ]; then
    print_error "Cannot cleanup main branch"
    exit 1
fi

print_header "Branch Deployment Cleanup"

print_msg "$CYAN" "Branch: $BRANCH_NAME"
if [ "$DRY_RUN" = true ]; then
    print_msg "$YELLOW" "Mode: DRY-RUN (no changes will be made)"
fi

# Source sanitization script
print_verbose "Sourcing sanitization script: $SCRIPT_DIR/sanitize-branch-name.sh"
if [ ! -f "$SCRIPT_DIR/sanitize-branch-name.sh" ]; then
    print_error "Sanitization script not found: $SCRIPT_DIR/sanitize-branch-name.sh"
    exit 1
fi

source "$SCRIPT_DIR/sanitize-branch-name.sh"

# Sanitize branch name
print_verbose "Sanitizing branch name..."
SANITIZED_BRANCH=$(sanitize_branch_name "$BRANCH_NAME")

if [ -z "$SANITIZED_BRANCH" ]; then
    print_error "Sanitized branch name is empty"
    exit 1
fi

print_msg "$GREEN" "✓ Sanitized branch: $SANITIZED_BRANCH"

# Define file paths
FRONTEND_FILE="$REPO_ROOT/k8s/team-apps/frontend/branches/dev-${SANITIZED_BRANCH}.yaml"
BACKEND_FILE="$REPO_ROOT/k8s/team-apps/backend/branches/dev-${SANITIZED_BRANCH}.yaml"

print_verbose "Frontend values file: ${FRONTEND_FILE#$REPO_ROOT/}"
print_verbose "Backend values file: ${BACKEND_FILE#$REPO_ROOT/}"

FILES_TO_DELETE=()

# Check which files exist
print_header "Checking for Values Files"

if [ -f "$FRONTEND_FILE" ]; then
    print_msg "$GREEN" "✓ Found: frontend values file"
    FILES_TO_DELETE+=("$FRONTEND_FILE")
else
    print_msg "$YELLOW" "⊘ Not found: frontend values file"
fi

if [ -f "$BACKEND_FILE" ]; then
    print_msg "$GREEN" "✓ Found: backend values file"
    FILES_TO_DELETE+=("$BACKEND_FILE")
else
    print_msg "$YELLOW" "⊘ Not found: backend values file"
fi

# Exit if no files to delete
if [ ${#FILES_TO_DELETE[@]} -eq 0 ]; then
    print_header "Cleanup Result"
    print_msg "$YELLOW" "⊘ No values files found for branch: $BRANCH_NAME"
    print_msg "$CYAN" "Branch was never deployed or already cleaned up"
    exit 0
fi

# Show files to delete
print_header "Files to Delete"
for file in "${FILES_TO_DELETE[@]}"; do
    echo -e "  ${RED}→ ${file#$REPO_ROOT/}${NC}"
done

# Dry-run mode - exit here
if [ "$DRY_RUN" = true ]; then
    print_header "Dry-Run Summary"
    print_msg "$YELLOW" "Would delete ${#FILES_TO_DELETE[@]} file(s)"
    print_msg "$CYAN" "Run without --dry-run to perform actual cleanup"
    exit 0
fi

# Confirm deletion
echo ""
read -p "Delete these files and commit to Git? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_msg "$YELLOW" "Cleanup cancelled"
    exit 0
fi

# Change to repo root
print_verbose "Changing to repository root: $REPO_ROOT"
cd "$REPO_ROOT"

# Verify we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not in a Git repository"
    exit 1
fi

print_header "Deleting Files"

# Delete files with git rm
for file in "${FILES_TO_DELETE[@]}"; do
    relative_path="${file#$REPO_ROOT/}"
    print_verbose "Running: git rm $relative_path"
    git rm "$relative_path"
    print_msg "$GREEN" "✓ Deleted: $relative_path"
done

print_header "Committing Changes"

# Configure Git (in case not already configured)
print_verbose "Configuring Git user..."
git config user.name "github-actions[bot]" 2>/dev/null || true
git config user.email "github-actions[bot]@users.noreply.github.com" 2>/dev/null || true

# Check current Git user (for verbose mode)
if [ "$VERBOSE" = true ]; then
    GIT_USER=$(git config user.name 2>/dev/null || echo "not set")
    GIT_EMAIL=$(git config user.email 2>/dev/null || echo "not set")
    print_verbose "Git user: $GIT_USER <$GIT_EMAIL>"
fi

# Create commit message
COMMIT_MSG="chore(helm): Cleanup branch deployment for ${SANITIZED_BRANCH} [skip ci]

Removed branch deployment values files for: ${BRANCH_NAME}

Files removed:
"

for file in "${FILES_TO_DELETE[@]}"; do
    COMMIT_MSG+="- ${file#$REPO_ROOT/}
"
done

COMMIT_MSG+="
This cleanup was performed manually using cleanup-branch-version.sh script.
ArgoCD will prune associated Kubernetes resources automatically."

# Commit changes
print_verbose "Committing changes..."
git commit -m "$COMMIT_MSG"
print_msg "$GREEN" "✓ Changes committed"

print_header "Pushing to Remote"

# Determine current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
print_verbose "Current branch: $CURRENT_BRANCH"

# Push changes
print_msg "$CYAN" "→ Pushing to origin/$CURRENT_BRANCH..."
git push origin HEAD

print_msg "$GREEN" "✓ Changes pushed successfully"

print_header "Cleanup Complete"

print_msg "$GREEN" "✓ Cleanup complete!"
print_msg "$CYAN" "📋 Summary:"
echo -e "   Branch: ${YELLOW}${BRANCH_NAME}${NC}"
echo -e "   Sanitized: ${YELLOW}${SANITIZED_BRANCH}${NC}"
echo -e "   Files deleted: ${YELLOW}${#FILES_TO_DELETE[@]}${NC}"
echo ""
print_msg "$CYAN" "🔄 ArgoCD will prune Kubernetes resources within ~2 minutes"
print_msg "$CYAN" "📊 Check ArgoCD UI to verify cleanup"
echo ""
