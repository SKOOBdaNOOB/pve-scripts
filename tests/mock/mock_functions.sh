#!/bin/bash
#
# Mock Functions for Testing
# Provides test-specific implementations of functions and utilities
#

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

# Mock read function for tests
read() {
    local var_name=$1

    # Strip '-p' flag and prompt if present
    if [[ "$1" == "-p" ]]; then
        # The prompt is in $2, and the variable is in $3
        var_name=$3
        # We can echo the prompt to stdout to simulate the prompt
        echo -ne "$2"
    fi

    # Check if we have a mock input available
    if [ $MOCK_INPUT_INDEX -lt ${#MOCK_INPUTS[@]} ]; then
        local input="${MOCK_INPUTS[$MOCK_INPUT_INDEX]}"
        MOCK_INPUT_INDEX=$((MOCK_INPUT_INDEX + 1))

        # Assign value to the provided variable
        if [[ -n "$var_name" ]]; then
            eval "$var_name='$input'"
        fi

        # Echo the input to simulate typing
        echo "$input"
        return 0
    else
        echo "MOCK ERROR: No more mock inputs available."
        return 1
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
