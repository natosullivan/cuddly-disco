#!/bin/bash

# This script is called by the user-prompt-submit hook
# It captures the user's prompt and appends it to the current feature's JSON file

# Get the prompt text from the first argument
PROMPT_TEXT="$1"

if [ -z "$PROMPT_TEXT" ]; then
  # No prompt provided, exit silently
  exit 0
fi

# Get the repo root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLOG_PROMPTS_DIR="$REPO_ROOT/blog-prompts"
STATE_FILE="$BLOG_PROMPTS_DIR/.current-feature.json"

# Check if there's an active feature
if [ ! -f "$STATE_FILE" ]; then
  # No active feature, exit silently (don't error, just don't record)
  exit 0
fi

# Read current feature file path using sed
FEATURE_FILE=$(sed -n 's/.*"filePath": "\([^"]*\)".*/\1/p' "$STATE_FILE")

if [ ! -f "$FEATURE_FILE" ]; then
  # Feature file doesn't exist, exit silently
  exit 0
fi

# Get timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Export variables for Python script
export FEATURE_FILE
export PROMPT_TEXT
export TIMESTAMP

# Use Python to add the prompt to the JSON file (handles escaping properly)
python3 <<'PYTHON_SCRIPT'
import json
import sys
import os

feature_file = os.environ.get('FEATURE_FILE')
prompt_text = os.environ.get('PROMPT_TEXT')
timestamp = os.environ.get('TIMESTAMP')

try:
    # Read the current feature file
    with open(feature_file, "r") as f:
        data = json.load(f)

    # Calculate next prompt ID
    prompt_id = len(data.get("prompts", [])) + 1

    # Add the new prompt
    new_prompt = {
        "id": prompt_id,
        "timestamp": timestamp,
        "prompt": prompt_text
    }

    data["prompts"].append(new_prompt)

    # Write back to file
    with open(feature_file, "w") as f:
        json.dump(data, f, indent=2)

    sys.exit(0)
except Exception as e:
    # If Python fails, exit silently to avoid breaking the hook
    sys.exit(0)
PYTHON_SCRIPT

exit 0
