#!/bin/bash

# Sanitize branch name for use in version strings and Kubernetes resource names
# Input: Full branch name (e.g., "feature/add-user-auth", "PROJ-123/implement-feature")
# Output: Sanitized name (e.g., "add-user-auth", "proj-123-implement-feature")
#
# Rules:
# - Convert to lowercase
# - Remove common prefixes (feature/, bugfix/, hotfix/, etc.)
# - Replace slashes, underscores, and periods with hyphens
# - Remove any other special characters
# - Collapse multiple consecutive hyphens into one
# - Trim leading/trailing hyphens
# - Truncate to 50 characters max (Kubernetes name limit consideration)

sanitize_branch_name() {
    local branch_name="$1"

    # Convert to lowercase
    local sanitized=$(echo "$branch_name" | tr '[:upper:]' '[:lower:]')

    # Remove common branch prefixes
    sanitized=$(echo "$sanitized" | sed -E 's#^(feature|bugfix|hotfix|release|feat|fix|chore|docs|test|refactor)/?##')

    # Handle user/ prefix specially - keep only the part after user/
    sanitized=$(echo "$sanitized" | sed -E 's#^[^/]+/user/([^/]+)/.*#\1-experimental#')
    sanitized=$(echo "$sanitized" | sed -E 's#^user/([^/]+)/.*#\1-experimental#')

    # For deeply nested paths, keep only the last 2-3 meaningful parts
    # e.g., "very/long/nested/branch/name" -> "nested-branch-name"
    local slash_count=$(echo "$sanitized" | tr -cd '/' | wc -c)
    if [ "$slash_count" -gt 2 ]; then
        # Keep last 3 parts
        sanitized=$(echo "$sanitized" | rev | cut -d'/' -f1-3 | rev)
    fi

    # Replace slashes, underscores, and periods with hyphens
    sanitized=$(echo "$sanitized" | tr '/._' '-')

    # Remove any remaining special characters (keep only alphanumeric and hyphens)
    sanitized=$(echo "$sanitized" | sed 's/[^a-z0-9-]//g')

    # Collapse multiple consecutive hyphens into one
    sanitized=$(echo "$sanitized" | sed 's/-\+/-/g')

    # Trim leading and trailing hyphens
    sanitized=$(echo "$sanitized" | sed 's/^-\+//;s/-\+$//')

    # Truncate to 50 characters
    sanitized=$(echo "$sanitized" | cut -c1-50)

    # Trim trailing hyphens again (in case truncation created one)
    sanitized=$(echo "$sanitized" | sed 's/-\+$//')

    echo "$sanitized"
}

# If script is executed directly (not sourced), run the function
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    if [ -z "$1" ]; then
        echo "Usage: $0 <branch-name>" >&2
        echo "Example: $0 feature/add-user-auth" >&2
        exit 1
    fi

    sanitize_branch_name "$1"
fi
