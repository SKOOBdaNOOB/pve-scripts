#!/bin/bash
#
# Simple verification test for piped input handling
# Tests that the UI functions correctly handle stdin when piped
#

# Current directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$CURRENT_DIR")"

# Output test file
TEST_OUTPUT="/tmp/pve-script-test-output.txt"

# Function to verify menu selection works via pipe
test_piped_menu_selection() {
    echo "Testing menu selection via pipe..."

    # Create a script that uses the UI menu selection
    cat > /tmp/test_menu.sh << 'EOF'
#!/bin/bash
source "$(dirname "$0")/lib/core/ui.sh"

show_header
section_header "Testing Piped Input"

# Simple menu test
options=("Option 1" "Option 2" "Option 3")
show_menu "Test Menu" "${options[@]}"
echo "You selected: ${options[$MENU_SELECTION]}"

echo "Test completed successfully!"
EOF

    chmod +x /tmp/test_menu.sh

    # Run the script with echo piping input "2" to it
    echo "2" | /tmp/test_menu.sh > "$TEST_OUTPUT" 2>&1

    # Check if the output contains the success message
    if grep -q "You selected: Option 2" "$TEST_OUTPUT" && grep -q "Test completed successfully" "$TEST_OUTPUT"; then
        echo "✅ Menu selection via pipe test passed!"
        return 0
    else
        echo "❌ Menu selection via pipe test failed!"
        echo "Output:"
        cat "$TEST_OUTPUT"
        return 1
    fi
}

# Function to verify yes/no prompt works via pipe
test_piped_yes_no() {
    echo "Testing yes/no prompt via pipe..."

    # Create a script that uses the yes/no prompt
    cat > /tmp/test_yes_no.sh << 'EOF'
#!/bin/bash
source "$(dirname "$0")/lib/core/ui.sh"

show_header
section_header "Testing Piped Input"

# Simple yes/no test
if prompt_yes_no "Do you want to continue?" "Y"; then
    echo "User said YES"
else
    echo "User said NO"
fi

echo "Test completed successfully!"
EOF

    chmod +x /tmp/test_yes_no.sh

    # Run the script with echo piping input "n" to it
    echo "n" | /tmp/test_yes_no.sh > "$TEST_OUTPUT" 2>&1

    # Check if the output contains the success message
    if grep -q "User said NO" "$TEST_OUTPUT" && grep -q "Test completed successfully" "$TEST_OUTPUT"; then
        echo "✅ Yes/No prompt via pipe test passed!"
        return 0
    else
        echo "❌ Yes/No prompt via pipe test failed!"
        echo "Output:"
        cat "$TEST_OUTPUT"
        return 1
    fi
}

# Function to verify value prompt works via pipe
test_piped_value() {
    echo "Testing value prompt via pipe..."

    # Create a script that uses the value prompt
    cat > /tmp/test_value.sh << 'EOF'
#!/bin/bash
source "$(dirname "$0")/lib/core/ui.sh"

show_header
section_header "Testing Piped Input"

# Simple value prompt test
value=$(prompt_value "Enter a value" "default" "^[a-zA-Z0-9_]+$")
echo "User entered: $value"

echo "Test completed successfully!"
EOF

    chmod +x /tmp/test_value.sh

    # Run the script with echo piping input "test_value" to it
    echo "test_value" | /tmp/test_value.sh > "$TEST_OUTPUT" 2>&1

    # Check if the output contains the success message
    if grep -q "User entered: test_value" "$TEST_OUTPUT" && grep -q "Test completed successfully" "$TEST_OUTPUT"; then
        echo "✅ Value prompt via pipe test passed!"
        return 0
    else
        echo "❌ Value prompt via pipe test failed!"
        echo "Output:"
        cat "$TEST_OUTPUT"
        return 1
    fi
}

# Main test function
main() {
    echo "=== Running Simple Verification Tests ==="
    echo "These tests verify that UI functions correctly handle piped input"
    echo

    # Copy the UI file to tmp for testing
    mkdir -p /tmp/lib/core
    cp "$REPO_DIR/lib/core/ui.sh" /tmp/lib/core/

    # Run the tests
    test_piped_menu_selection
    local menu_result=$?

    test_piped_yes_no
    local yes_no_result=$?

    test_piped_value
    local value_result=$?

    # Clean up
    rm -f /tmp/test_menu.sh /tmp/test_yes_no.sh /tmp/test_value.sh "$TEST_OUTPUT"
    rm -rf /tmp/lib

    echo
    echo "=== Test Summary ==="

    # Check if all tests passed
    if [ $menu_result -eq 0 ] && [ $yes_no_result -eq 0 ] && [ $value_result -eq 0 ]; then
        echo "All tests passed! The UI functions correctly handle piped input."
        return 0
    else
        echo "Some tests failed. See above for details."
        return 1
    fi
}

# Run the tests
main
