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

# Show a warning message
show_warning() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

# Variables for timeout tracking
TESTS_TIMED_OUT=0

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
    echo -e "Timed Out:   ${RED}$TESTS_TIMED_OUT${RESET}"

    if [ $TESTS_FAILED -eq 0 ] && [ $TESTS_TIMED_OUT -eq 0 ]; then
        echo -e "${GREEN}All tests passed successfully!${RESET}"
        exit 0
    else
        echo -e "${RED}Some tests failed or timed out!${RESET}"
        exit 1
    fi
}

# Function to trap and handle special exit codes
handle_test_result() {
    local exit_code=$?
    local test_file=$1

    case $exit_code in
        0)
            # Normal exit, no action needed
            ;;
        2)
            echo -e "${RED}ERROR: Test timed out in $(basename "$test_file")${RESET}"
            TESTS_TIMED_OUT=$((TESTS_TIMED_OUT + 1))
            ;;
        3)
            echo -e "${RED}ERROR: Mock input exhausted in $(basename "$test_file")${RESET}"
            echo -e "${YELLOW}Hint: Test may need more mock inputs to complete. Check the test flow.${RESET}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            ;;
        *)
            echo -e "${RED}ERROR: Test failed with exit code $exit_code in $(basename "$test_file")${RESET}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            ;;
    esac
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

            # Use a subshell to isolate test execution
            (
                # Source the test file
                source "$test_file"
            )

            # Handle any special exit codes
            handle_test_result "$test_file"
        fi
    done
}

# Run all integration tests
run_integration_tests() {
    show_section "Integration"

    # Source mock functions and test helpers
    source "$SCRIPT_DIR/mock/mock_functions.sh"
    source "$SCRIPT_DIR/test_helpers.sh"

    # Check for system timeout command
    if ! command -v timeout &> /dev/null; then
        show_warning "The 'timeout' command is not available. Test timeouts may not work correctly."
    fi

    # Run each integration test file
    for test_file in "$SCRIPT_DIR/integration"/*.sh; do
        if [ -f "$test_file" ]; then
            echo -e "${YELLOW}Running test file: $(basename "$test_file")${RESET}"

            # Use a subshell to isolate test execution
            (
                # Set up for safe test execution
                TEST_TIMEOUT_ENABLED=true
                TEST_START_TIME=$(date +%s)

                # Source the test file
                source "$test_file"
            )

            # Handle any special exit codes
            handle_test_result "$test_file"
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
