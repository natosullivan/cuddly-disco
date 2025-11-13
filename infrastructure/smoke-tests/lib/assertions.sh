#!/bin/bash

# Assertion helper functions for smoke tests
# Provides reusable assertion functions with clear pass/fail output

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test result
print_test_result() {
    local status=$1
    local message=$2

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert that a command succeeds (exit code 0)
assert_success() {
    local description=$1
    shift
    local output

    if output=$("$@" 2>&1); then
        print_test_result "PASS" "$description"
        return 0
    else
        print_test_result "FAIL" "$description (command failed: $output)"
        return 1
    fi
}

# Assert that two strings are equal
assert_equals() {
    local expected=$1
    local actual=$2
    local description=$3

    if [ "$expected" = "$actual" ]; then
        print_test_result "PASS" "$description"
        return 0
    else
        print_test_result "FAIL" "$description (expected: '$expected', got: '$actual')"
        return 1
    fi
}

# Assert that a string contains a substring
assert_contains() {
    local haystack=$1
    local needle=$2
    local description=$3

    if echo "$haystack" | grep -q "$needle"; then
        print_test_result "PASS" "$description"
        return 0
    else
        print_test_result "FAIL" "$description (string '$haystack' does not contain '$needle')"
        return 1
    fi
}

# Assert that a string does not contain a substring
assert_not_contains() {
    local haystack=$1
    local needle=$2
    local description=$3

    if ! echo "$haystack" | grep -q "$needle"; then
        print_test_result "PASS" "$description"
        return 0
    else
        print_test_result "FAIL" "$description (string '$haystack' should not contain '$needle')"
        return 1
    fi
}

# Assert that a value is not empty
assert_not_empty() {
    local value=$1
    local description=$2

    if [ -n "$value" ]; then
        print_test_result "PASS" "$description"
        return 0
    else
        print_test_result "FAIL" "$description (value is empty)"
        return 1
    fi
}

# Assert that a number is greater than or equal to a threshold
assert_gte() {
    local actual=$1
    local threshold=$2
    local description=$3

    if [ "$actual" -ge "$threshold" ]; then
        print_test_result "PASS" "$description"
        return 0
    else
        print_test_result "FAIL" "$description (expected >= $threshold, got $actual)"
        return 1
    fi
}

# Assert that HTTP status code is 200
assert_http_200() {
    local url=$1
    local description=$2
    local extra_curl_args=${3:-""}

    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" $extra_curl_args "$url" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        print_test_result "PASS" "$description"
        return 0
    else
        print_test_result "FAIL" "$description (expected HTTP 200, got $status_code)"
        return 1
    fi
}

# Print test summary
print_test_summary() {
    local test_file=$1

    echo ""
    echo "=========================================="
    echo "Test Summary: $test_file"
    echo "=========================================="
    echo -e "Total:  $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo "=========================================="
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Reset counters (useful when running multiple test files)
reset_test_counters() {
    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0
}
