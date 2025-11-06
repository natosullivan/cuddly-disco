#!/bin/bash
set -e

# Get the repo root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLOG_PROMPTS_DIR="$REPO_ROOT/blog-prompts"
STATE_FILE="$BLOG_PROMPTS_DIR/.current-feature.json"

# Check if there's an active feature
if [ ! -f "$STATE_FILE" ]; then
  echo "Error: No active feature to end"
  echo "Use 'start-feature.sh <name>' to start tracking a feature first"
  exit 1
fi

# Read current feature details using sed
FEATURE_NAME=$(sed -n 's/.*"feature": "\([^"]*\)".*/\1/p' "$STATE_FILE")
FEATURE_FILE=$(sed -n 's/.*"filePath": "\([^"]*\)".*/\1/p' "$STATE_FILE")

if [ ! -f "$FEATURE_FILE" ]; then
  echo "Error: Feature file not found: $FEATURE_FILE"
  exit 1
fi

# Update the feature file - mark as completed and set endTime
# Use a temp file for the update
TEMP_FILE=$(mktemp)
cat "$FEATURE_FILE" | sed 's/"endTime": null/"endTime": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"/' | sed 's/"status": "active"/"status": "completed"/' > "$TEMP_FILE"
mv "$TEMP_FILE" "$FEATURE_FILE"

# Count the prompts
PROMPT_COUNT=$(grep -c '"prompt":' "$FEATURE_FILE" 2>/dev/null)

# Remove the state file
rm "$STATE_FILE"

echo "✓ Ended feature tracking: $FEATURE_NAME"
echo "  File: $FEATURE_FILE"
echo "  Total prompts captured: $PROMPT_COUNT"
echo ""
echo "Feature tracking is now inactive."
echo "Start a new feature with 'start-feature.sh <name>'"
