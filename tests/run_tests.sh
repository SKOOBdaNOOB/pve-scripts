#!/bin/bash
#
# Test Runner for Proxmox VM Template Wizard
# Executes all tests or specific test categories
#

# Set script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# Test results tracking
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Show test header
show_header() {
    echo -e "${BLUE}==========================================${RESET}"
    echo -e "${BLUE}  Proxmox VM Template Wizard Test Suite  ${RESET}"
    echo -e "${BLUE}==========================================${RESET}"
    echo ""
}

# Show section header
show_section() {
    echo -e "${YELLOW}== Running $1 Tests ==${RESET}"
    echo ""
}

# Display test results
show_results() {
    echo ""
    echo -e "${BLUE}==========================================${RESET}"
    echo -e "${BLUE}              Test Results               ${RESET}"
    echo -e "${BLUE}==========================================${RESET}"
    echo -e "Total Tests: $TESTS_TOTAL"
    echo -e "Passed:      ${GREEN}$TESTS_PASSED${RESET}"
    echo -e "Failed:      ${RED}$TESTS_FAILED${RESET}"
    echo -e "Skipped:     ${YELLOW}$TESTS_SKIPPED${RESET}"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed successfully!${RESET}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${RESET}"
        exit 1
    fi
}

# Run all unit tests
run_unit_tests() {
    show_section "Unit"

    # Source mock functions
    source "$SCRIPT_DIR/mock/mock_functions.sh"

    # Run each unit test file
    for test_file in "$SCRIPT_DIR/unit"/*.sh; do
        if [ -f "$test_file" ]; then
            echo -e "${YELLOW}Running test file: $(basename "$test_file")${RESET}"
            source "$test_file"
        fi
    done
}

# Run all integration tests
run_integration_tests() {
    show_section "Integration"

    # Source mock functions
    source "$SCRIPT_DIR/mock/mock_functions.sh"

    # Run each integration test file
    for test_file in "$SCRIPT_DIR/integration"/*.sh; do
        if [ -f "$test_file" ]; then
            echo -e "${YELLOW}Running test file: $(basename "$test_file")${RESET}"
            source "$test_file"
        fi
    done
}

# Main function
main() {
    show_header

    # Check if specific test type is requested
    if [ "$1" == "unit" ]; then
        run_unit_tests
    elif [ "$1" == "integration" ]; then
        run_integration_tests
    else
        run_unit_tests
        run_integration_tests
    fi

    show_results
}

# Execute main function
main "$@"
