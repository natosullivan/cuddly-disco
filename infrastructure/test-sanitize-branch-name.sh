#!/bin/bash

# Test script for branch name sanitization
# Runs all test cases from BRANCH-VERSIONING-TASKS.md

set -e

# Source the sanitization script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sanitize-branch-name.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_sanitization() {
    local input="$1"
    local expected="$2"
    local result=$(sanitize_branch_name "$input")

    if [ "$result" == "$expected" ]; then
        echo -e "${GREEN}✓${NC} '$input' → '$result'"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} '$input' → expected '$expected', got '$result'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "Running branch name sanitization tests..."
echo ""

# Test cases from BRANCH-VERSIONING-TASKS.md
test_sanitization "feature/add-user-auth" "add-user-auth"
test_sanitization "bugfix/fix-timeout-issue" "fix-timeout-issue"
test_sanitization "PROJ-123/implement-feature" "proj-123-implement-feature"
test_sanitization "user/john/experimental" "john-experimental"
test_sanitization "add_user_auth" "add-user-auth"
test_sanitization "add.user.auth" "add-user-auth"
test_sanitization "feature/CAPS-and-123" "caps-and-123"
test_sanitization "very/long/nested/branch/name" "nested-branch-name"

# Additional edge cases
echo ""
echo "Additional edge cases:"
test_sanitization "feat/new-feature" "new-feature"
test_sanitization "fix/urgent-bug" "urgent-bug"
test_sanitization "hotfix/critical-fix" "critical-fix"
test_sanitization "release/v1.2.3" "v1-2-3"
test_sanitization "chore/update-deps" "update-deps"
test_sanitization "feature/add--multiple---hyphens" "add-multiple-hyphens"
test_sanitization "feature/-leading-hyphen" "leading-hyphen"
test_sanitization "feature/trailing-hyphen-" "trailing-hyphen"
test_sanitization "FEATURE/UPPERCASE" "uppercase"
test_sanitization "feature/special!@#chars" "specialchars"
test_sanitization "a/b/c/d/e/f/g" "e-f-g"

# Test very long branch name (should truncate to 50 chars)
test_sanitization "feature/this-is-a-very-long-branch-name-that-exceeds-fifty-characters-limit" "this-is-a-very-long-branch-name-that-exceeds-fifty"

echo ""
echo "================================"
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC} ($TESTS_PASSED/$((TESTS_PASSED + TESTS_FAILED)))"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC} Passed: $TESTS_PASSED, Failed: $TESTS_FAILED"
    exit 1
fi
