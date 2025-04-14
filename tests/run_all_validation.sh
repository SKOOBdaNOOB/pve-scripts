#!/bin/bash
#
# Master Validation Test Script
# Runs all validation tests to ensure the system is working correctly
#

# Colors for output
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# Get script directory and repo directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Display header
echo -e "${BLUE}============================================${RESET}"
echo -e "${BLUE}  PVE Template Wizard Validation Tests     ${RESET}"
echo -e "${BLUE}============================================${RESET}"
echo ""

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test and track results
run_test() {
    local test_script="$1"
    local test_name="$2"

    echo -e "${YELLOW}Running test: $test_name${RESET}"
    echo -e "${YELLOW}-------------$(printf '%*s' ${#test_name} | tr ' ' '-')${RESET}"

    if [ -x "$test_script" ]; then
        "$test_script"
        local result=$?

        if [ $result -eq 0 ]; then
            echo -e "${GREEN}✓ Test passed: $test_name${RESET}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ Test failed: $test_name (Exit code: $result)${RESET}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi

        echo ""
        return $result
    else
        echo -e "${RED}Error: Test script not found or not executable: $test_script${RESET}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run individual tests
run_test "$SCRIPT_DIR/validate_piped_input_fix.sh" "Piped Input Fix Validation"
run_test "$SCRIPT_DIR/unit/module_loading_tests.sh" "Module Loading Tests"

# If all of the above passed, try the distribution to storage flow test
if [ $TESTS_FAILED -eq 0 ]; then
    run_test "$SCRIPT_DIR/integration/wizard_distribution_to_storage_tests.sh" "Distribution to Storage Flow Tests"
fi

# Display summary
echo -e "${BLUE}============================================${RESET}"
echo -e "${BLUE}  Test Summary                             ${RESET}"
echo -e "${BLUE}============================================${RESET}"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${RESET}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${RESET}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All validation tests passed!${RESET}"
    exit 0
else
    echo -e "${RED}Some validation tests failed! Please check the output above.${RESET}"
    exit 1
fi
