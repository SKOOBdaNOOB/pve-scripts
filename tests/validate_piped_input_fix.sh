#!/bin/bash
#
# Validation Script for Piped Input Fix
# This script verifies the piped input fix is working correctly
#

# Define colors
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# Display header
echo -e "${BLUE}============================================${RESET}"
echo -e "${BLUE}  Piped Input Fix Validation               ${RESET}"
echo -e "${BLUE}============================================${RESET}"
echo ""

# Get script directory and repo directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Create a test script to pipe input into
cat > "$SCRIPT_DIR/temp_piped_test.sh" << 'EOF'
#!/bin/bash

# Source UI functions
source "$(dirname "${BASH_SOURCE[0]}")/../lib/core/ui.sh"

# Debug helper for stdin
debug_stdin() {
    if [ -t 0 ]; then
        echo "DEBUG: stdin is a terminal"
    else
        echo "DEBUG: stdin is NOT a terminal (it's being piped/redirected)"
    fi
    if [ -t 1 ]; then
        echo "DEBUG: stdout is a terminal"
    else
        echo "DEBUG: stdout is NOT a terminal"
    fi
}

# Run with debug
echo "Checking stdin status..."
debug_stdin

# Test yes/no prompt
echo "Testing yes/no prompt..."
if prompt_yes_no "Continue with test?" "Y"; then
    echo "User selected: YES"
else
    echo "User selected: NO"
fi

# Test value prompt
echo "Testing value prompt..."
result=$(prompt_value "Enter a value" "default" "^[a-zA-Z0-9]+$")
echo "User entered: $result"

# Test menu selection
echo "Testing menu selection..."
options=("Option 1" "Option 2" "Option 3")
show_menu "Select an option" "${options[@]}"
echo "User selected option: $((MENU_SELECTION+1)) - ${options[$MENU_SELECTION]}"

echo "All tests completed successfully!"
exit 0
EOF

# Make the script executable
chmod +x "$SCRIPT_DIR/temp_piped_test.sh"

# Better test that uses expect-like behavior
test_with_answers() {
    local test_script="$1"
    shift
    local answers=("$@")

    echo -e "${YELLOW}Running test with automated input...${RESET}"

    # Create a temporary file for input
    local input_file=$(mktemp)
    for answer in "${answers[@]}"; do
        echo "$answer" >> "$input_file"
    done

    # Display the answers we're providing
    echo -e "${YELLOW}Providing answers:${RESET}"
    cat "$input_file" | nl
    echo ""

    # Run the test with input
    cat "$input_file" | bash "$test_script"
    local result=$?

    # Clean up
    rm -f "$input_file"

    # Check result
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}SUCCESS: Piped input test passed!${RESET}"
    else
        echo -e "${RED}FAILED: Piped input test failed with exit code $result${RESET}"
    fi

    return $result
}

# Run the test with specific answers
test_with_answers "$SCRIPT_DIR/temp_piped_test.sh" "y" "test1234" "2"

# Clean up
rm -f "$SCRIPT_DIR/temp_piped_test.sh"

echo ""
echo -e "${BLUE}============================================${RESET}"
echo -e "${BLUE}  Test Complete                            ${RESET}"
echo -e "${BLUE}============================================${RESET}"
