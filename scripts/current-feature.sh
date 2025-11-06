#!/bin/bash

# Get the repo root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLOG_PROMPTS_DIR="$REPO_ROOT/blog-prompts"
STATE_FILE="$BLOG_PROMPTS_DIR/.current-feature.json"

# Check if there's an active feature
if [ ! -f "$STATE_FILE" ]; then
  echo "No feature is currently being tracked."
  echo ""
  echo "Start tracking with: start-feature.sh <feature name>"
  exit 0
fi

# Parse JSON using sed (more portable)
FEATURE_NAME=$(sed -n 's/.*"feature": "\([^"]*\)".*/\1/p' "$STATE_FILE")
FEATURE_SLUG=$(sed -n 's/.*"slug": "\([^"]*\)".*/\1/p' "$STATE_FILE")
FEATURE_FILE=$(sed -n 's/.*"filePath": "\([^"]*\)".*/\1/p' "$STATE_FILE")

# Count prompts if file exists
if [ -f "$FEATURE_FILE" ]; then
  PROMPT_COUNT=$(grep -c '"prompt":' "$FEATURE_FILE" 2>/dev/null)
  START_TIME=$(sed -n 's/.*"startTime": "\([^"]*\)".*/\1/p' "$FEATURE_FILE")
else
  PROMPT_COUNT=0
  START_TIME="unknown"
fi

echo "Currently tracking:"
echo "  Feature: $FEATURE_NAME"
echo "  Slug: $FEATURE_SLUG"
echo "  Started: $START_TIME"
echo "  Prompts captured: $PROMPT_COUNT"
echo "  File: $FEATURE_FILE"
