# Blog Prompt Tracking

This directory contains automatically captured prompts organized by feature, used for creating blog posts about the development process.

## Overview

The prompt tracking system automatically records every prompt you send to Claude Code and organizes them by feature. This makes it easy to review the conversation history for each feature when writing blog posts.

## How It Works

**Automatic Recording:** The system uses a Claude Code hook (`user-prompt-submit`) that automatically captures every prompt you submit.

**Manual Delimiting:** You manually control which feature is being tracked using slash commands.

**JSON Storage:** Each feature's prompts are stored in a separate JSON file with metadata like timestamps and IDs.

## Usage

### Slash Commands

**Start tracking a new feature:**
```
/start-feature Add dark mode support
```

**Show the currently tracked feature:**
```
/current-feature
```

**List all tracked features:**
```
/list-features
```

**End tracking the current feature:**
```
/end-feature
```

### Direct Script Usage

You can also run the scripts directly:

```bash
# Start a new feature
bash scripts/start-feature.sh "Feature name"

# Check current feature
bash scripts/current-feature.sh

# List all features
bash scripts/list-features.sh

# End current feature
bash scripts/end-feature.sh
```

## File Structure

```
blog-prompts/
├── README.md (this file)
├── .current-feature.json (state file - tracks active feature)
├── feature-name-20251106.json (feature prompt history)
└── another-feature-20251107.json
```

## Feature File Format

Each feature file is a JSON document with the following structure:

```json
{
  "feature": "Feature Name",
  "slug": "feature-name-20251106",
  "startTime": "2025-11-06T10:00:00Z",
  "endTime": "2025-11-06T11:30:00Z",
  "status": "completed",
  "prompts": [
    {
      "id": 1,
      "timestamp": "2025-11-06T10:05:23Z",
      "prompt": "The actual prompt text"
    },
    {
      "id": 2,
      "timestamp": "2025-11-06T10:15:45Z",
      "prompt": "Another prompt"
    }
  ]
}
```

## Git Management

You can choose to:
- **Commit feature files** to track the development journey alongside the code
- **Add `blog-prompts/` to .gitignore** to keep prompts private

The `.current-feature.json` state file should typically be gitignored.

## Requirements

- **Bash** (Git Bash on Windows, native on macOS/Linux)
- **Python 3** (for JSON manipulation in track-prompt.sh)
- **Claude Code** with hooks enabled

## How the Hook Works

The hook is configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "user-prompt-submit": {
      "command": "bash scripts/track-prompt.sh \"{{PROMPT}}\"",
      "description": "Automatically capture prompts for blog post tracking"
    }
  }
}
```

Every time you submit a prompt, Claude Code runs `track-prompt.sh` which:
1. Checks if there's an active feature
2. If yes, appends the prompt to the feature's JSON file
3. If no, silently exits (no error)

## Tips

- Start a feature before beginning work so all related prompts are captured
- Use descriptive feature names that match your blog post titles
- End features when you're done to mark them as completed
- Review the JSON files when writing blog posts to recall the development flow

## Example Workflow

```bash
# Start working on a new feature
/start-feature Implement user authentication

# ... work with Claude Code ...
# All prompts are automatically captured

# Check progress
/current-feature
# Shows: Currently tracking: Implement user authentication, Prompts captured: 15

# When done
/end-feature

# Later, review for blog post
cat blog-prompts/implement-user-authentication-20251106.json
```
