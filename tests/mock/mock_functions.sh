#!/bin/bash
#
# Mock Functions for Testing
# Provides test-specific implementations of functions and utilities
#

# Mock test for terminal stdin to ensure UI functions work in tests
# Original: [ -t 0 ]
[ () {
    if [[ "$1" == "-t" && "$2" == "0" ]]; then
        # Always return true during tests (stdin is a terminal)
        return 0
    else
        # For all other tests, use the actual [ command
        builtin [ "$@"
    fi
}

# Global variables for input mocking
MOCK_INPUTS=()
MOCK_INPUT_INDEX=0

# Global variables for command mocking
MOCK_COMMAND_OUTPUTS=()
MOCK_COMMAND_INDEX=0

# Function to set up mock inputs
setup_mock_inputs() {
    MOCK_INPUTS=("$@")
    MOCK_INPUT_INDEX=0
}

# Global timeout for tests to prevent hanging
TEST_TIMEOUT=10  # seconds
TEST_START_TIME=0
TEST_TIMEOUT_ENABLED=false

# Enable test timeout
enable_test_timeout() {
    TEST_TIMEOUT_ENABLED=true
    TEST_START_TIME=$(date +%s)
}

# Check if test has timed out
check_test_timeout() {
    if [[ "$TEST_TIMEOUT_ENABLED" == "true" ]]; then
        local current_time=$(date +%s)
        local elapsed=$((current_time - TEST_START_TIME))

        if [[ $elapsed -gt $TEST_TIMEOUT ]]; then
            echo "TEST TIMEOUT: Test has been running for ${elapsed} seconds, exceeding limit of ${TEST_TIMEOUT} seconds."
            exit 2  # Special exit code for timeout
        fi
    fi
}

# Mock read function for tests
read() {
    local var_name=$1
    local prompt=""
    local timeout_arg=""

    # Check for test timeout
    check_test_timeout

    # Parse read arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p)
                prompt="$2"
                shift 2
                ;;
            -t)
                timeout_arg="$2"
                shift 2
                ;;
            *)
                var_name="$1"
                shift
                ;;
        esac
    done

    # Echo the prompt if provided
    if [[ -n "$prompt" ]]; then
        echo -ne "$prompt"
    fi

    # Check if we have a mock input available
    if [ $MOCK_INPUT_INDEX -lt ${#MOCK_INPUTS[@]} ]; then
        local input="${MOCK_INPUTS[$MOCK_INPUT_INDEX]}"
        MOCK_INPUT_INDEX=$((MOCK_INPUT_INDEX + 1))

        # For debugging
        echo "DEBUG: Mock read providing input: '$input' (input $MOCK_INPUT_INDEX of ${#MOCK_INPUTS[@]})" >&2

        # Assign value to the provided variable
        if [[ -n "$var_name" ]]; then
            eval "$var_name='$input'"
        fi

        # Echo the input to simulate typing
        echo "$input"
        return 0
    else
        echo "MOCK ERROR: No more mock inputs available. Script may be expecting more input than provided." >&2
        # In test environment, automatically exit to prevent hanging
        exit 3  # Special exit code for mock input exhaustion
    fi
}

# Function to set up mock command outputs
setup_mock_commands() {
    local index=0
    MOCK_COMMAND_OUTPUTS=()

    # Parse command-output pairs
    while [ $index -lt $# ]; do
        MOCK_COMMAND_OUTPUTS+=("${!index}")
        index=$((index + 1))
    done

    MOCK_COMMAND_INDEX=0
}

# Mock command execution
command() {
    local action=$1
    local cmd=$2

    if [[ "$action" == "-v" ]]; then
        # We're checking if a command exists
        # Return success for known commands in our test
        case "$cmd" in
            qm|pvesh|wget|sha256sum)
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    fi

    # For other command usages, defer to the real command
    builtin command "$@"
}

# Mock sleep to speed up tests
sleep() {
    # Do nothing to speed up tests
    return 0
}

# Mock test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected '$expected' but got '$actual'}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓ Test passed: $message${RESET}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed: $message${RESET}"
        echo -e "${RED}  Expected: '$expected'${RESET}"
        echo -e "${RED}  Actual:   '$actual'${RESET}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_return_code() {
    local expected=$1
    local actual=$2
    local message="${3:-Expected return code $expected but got $actual}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [[ $expected -eq $actual ]]; then
        echo -e "${GREEN}✓ Test passed: Return code $actual${RESET}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed: $message${RESET}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

run_test() {
    local test_name="$1"
    local test_function="$2"

    echo -e "${BLUE}Running test: $test_name${RESET}"

    # Execute the test function
    $test_function

    echo ""
}

# Mock echo to capture outputs if needed
capture_echo() {
    # Start capturing echo output
    CAPTURED_OUTPUT=""
    function echo() {
        CAPTURED_OUTPUT+="$*\n"
    }
}

release_echo() {
    # Restore original echo function
    unset -f echo
}
