#!/bin/bash
set -e

# Get the feature name from arguments
FEATURE_NAME="$*"

if [ -z "$FEATURE_NAME" ]; then
  echo "Error: Please provide a feature name"
  echo "Usage: start-feature.sh <feature name>"
  exit 1
fi

# Get the repo root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLOG_PROMPTS_DIR="$REPO_ROOT/blog-prompts"
STATE_FILE="$BLOG_PROMPTS_DIR/.current-feature.json"

# Create slug: lowercase, replace spaces with hyphens, add date
SLUG=$(echo "$FEATURE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
DATE=$(date +%Y%m%d)
FEATURE_SLUG="${SLUG}-${DATE}"
FEATURE_FILE="$BLOG_PROMPTS_DIR/${FEATURE_SLUG}.json"

# Check if there's already an active feature
if [ -f "$STATE_FILE" ]; then
  CURRENT_FEATURE=$(cat "$STATE_FILE" | grep -o '"feature":"[^"]*"' | cut -d'"' -f4 || echo "")
  if [ -n "$CURRENT_FEATURE" ]; then
    echo "Warning: There is already an active feature: $CURRENT_FEATURE"
    echo "Please run 'end-feature.sh' first or the new feature will override it."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
    fi
  fi
fi

# Create the feature file
cat > "$FEATURE_FILE" <<EOF
{
  "feature": "$FEATURE_NAME",
  "slug": "$FEATURE_SLUG",
  "startTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "endTime": null,
  "status": "active",
  "prompts": []
}
EOF

# Update the state file
cat > "$STATE_FILE" <<EOF
{
  "feature": "$FEATURE_NAME",
  "slug": "$FEATURE_SLUG",
  "filePath": "$FEATURE_FILE"
}
EOF

echo "✓ Started tracking feature: $FEATURE_NAME"
echo "  File: $FEATURE_FILE"
echo "  Slug: $FEATURE_SLUG"
echo ""
echo "All prompts will now be automatically recorded to this feature."
echo "Run 'end-feature.sh' when you're done with this feature."
