#!/bin/bash

# Get the repo root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLOG_PROMPTS_DIR="$REPO_ROOT/blog-prompts"

# Find all feature files (exclude .current-feature.json)
FEATURE_FILES=$(find "$BLOG_PROMPTS_DIR" -name "*.json" ! -name ".current-feature.json" | sort -r)

if [ -z "$FEATURE_FILES" ]; then
  echo "No features have been tracked yet."
  echo ""
  echo "Start tracking with: start-feature.sh <feature name>"
  exit 0
fi

echo "Tracked features:"
echo ""

# Loop through each feature file and display info
while IFS= read -r file; do
  if [ -f "$file" ]; then
    FEATURE_NAME=$(sed -n 's/.*"feature": "\([^"]*\)".*/\1/p' "$file")
    SLUG=$(sed -n 's/.*"slug": "\([^"]*\)".*/\1/p' "$file")
    STATUS=$(sed -n 's/.*"status": "\([^"]*\)".*/\1/p' "$file")
    START_TIME=$(sed -n 's/.*"startTime": "\([^"]*\)".*/\1/p' "$file")
    PROMPT_COUNT=$(grep -c '"prompt":' "$file" 2>/dev/null)

    # Show status indicator
    if [ "$STATUS" = "active" ]; then
      STATUS_ICON="🟢"
    else
      STATUS_ICON="✓"
    fi

    echo "  $STATUS_ICON $FEATURE_NAME"
    echo "     Slug: $SLUG"
    echo "     Started: $START_TIME"
    echo "     Prompts: $PROMPT_COUNT"
    echo "     Status: $STATUS"
    echo ""
  fi
done <<< "$FEATURE_FILES"

echo "Total features tracked: $(echo "$FEATURE_FILES" | wc -l)"
