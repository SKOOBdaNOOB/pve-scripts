#!/bin/bash
#
# Integration Tests for Wizard Flow
# Tests how the menu system works in the context of the full application
#

# Source test helpers
source "$SCRIPT_DIR/test_helpers.sh"

# Test main menu exits correctly when user selects exit option
test_main_menu_exit() {
    echo "Testing main menu exit functionality..."

    # Set up mock inputs - select exit option
    setup_mock_inputs "6"  # Option 6 is Exit in the main menu

    # Run the test
    run_test_in_safe_env 5 > /tmp/test_output 2>&1
    local output=$(cat /tmp/test_output)

    # Display output for debugging
    echo "DEBUG Output: $output" >&2

    # Check for success
    if grep -q "Exit called with code: 0" /tmp/test_output || grep -q "DEBUG: Exit option selected" /tmp/test_output; then
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ Test passed: Main menu exit works correctly${RESET}"
    else
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ Test failed: Main menu exit not detected${RESET}"
        echo -e "${RED}  Output: $(head -n 20 /tmp/test_output | tr '\n' ' ')${RESET}"
    fi
}

# Test main menu handles invalid selections
test_main_menu_invalid_selection() {
    echo "Testing main menu invalid selection handling..."

    # Set up mock inputs - multiple invalid followed by exit
    setup_mock_inputs "invalid" "100" "0" "abc" "xyz" "6"

    # Run the test
    run_test_in_safe_env 5 > /tmp/test_output 2>&1
    local output=$(cat /tmp/test_output)

    # Display output for debugging
    echo "DEBUG Output: $output" >&2

    # Check for success
    if grep -q "Exit called with code: 0" /tmp/test_output || grep -q "DEBUG: Exit option selected" /tmp/test_output; then
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ Test passed: Main menu handles invalid selections correctly${RESET}"
    else
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ Test failed: Invalid selection handling not working${RESET}"
        echo -e "${RED}  Output: $(head -n 20 /tmp/test_output | tr '\n' ' ')${RESET}"
    fi
}

# Test main menu handles max attempts
test_main_menu_max_attempts() {
    echo "Testing main menu max attempts handling..."

    # Set up mock inputs - more than max_attempts invalid inputs
    # The test script has a max_attempts of 5
    setup_mock_inputs "invalid" "0" "100" "abc" "xyz" "zzz"

    # Run the test
    run_test_in_safe_env 5 > /tmp/test_output 2>&1
    local output=$(cat /tmp/test_output)

    # Display output for debugging
    echo "DEBUG Output: $output" >&2

    # Check for success - either we see exit code 1 or too many attempts message
    if grep -q "Exit called with code: 1" /tmp/test_output || grep -q "DEBUG: Too many invalid attempts" /tmp/test_output; then
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ Test passed: Main menu handles max invalid attempts correctly${RESET}"
    else
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ Test failed: Max attempts handling not working${RESET}"
        echo -e "${RED}  Output: $(head -n 20 /tmp/test_output | tr '\n' ' ')${RESET}"
    fi
}

# Test submenu handling
test_submenu_handling() {
    echo "Testing submenu navigation..."

    # Set up mock inputs for submenu navigation:
    # 1. Choose "Configuration Management" (option 5)
    # 2. Choose "Show Current Configuration" (option 1)
    # 3. Press Enter to return to submenu
    # 4. Press Enter to return to main menu
    # 5. Choose Exit (option 6)
    setup_mock_inputs "5" "1" "" "q" "6"

    # Run the test with an 8 second timeout (submenu navigation is more complex)
    run_test_in_safe_env 8 > /tmp/test_output 2>&1
    local output=$(cat /tmp/test_output)

    # Display output for debugging
    echo "DEBUG Output: $output" >&2

    # Check for success
    if grep -q "Exit called with code: 0" /tmp/test_output || grep -q "DEBUG: Exit option selected" /tmp/test_output; then
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ Test passed: Submenu navigation works correctly${RESET}"
    else
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ Test failed: Submenu navigation not working${RESET}"
        echo -e "${RED}  Output: $(head -n 20 /tmp/test_output | tr '\n' ' ')${RESET}"
    fi
}

# Run integration tests
run_test "Main Menu Exit" test_main_menu_exit
run_test "Main Menu Invalid Selection" test_main_menu_invalid_selection
run_test "Main Menu Max Attempts" test_main_menu_max_attempts
run_test "Submenu Handling" test_submenu_handling
