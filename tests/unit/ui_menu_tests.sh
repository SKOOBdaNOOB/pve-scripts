#!/bin/bash
#
# Unit Tests for Menu Selection
# Tests the show_menu function with various inputs
#

# Source the UI module
source "$REPO_DIR/lib/core/ui.sh"

# Test valid menu selection
test_valid_menu_selection() {
    # Set up mock inputs
    setup_mock_inputs "2"

    # Call the menu function
    show_menu "Test Menu" "Option 1" "Option 2" "Option 3"
    local result=$?

    # Assert the result
    assert_equals 1 $MENU_SELECTION "Menu selection index should be 1 (Option 2)"
    assert_return_code 0 $result "Return code should be 0 for valid selection"
}

# Test exiting with 'q'
test_menu_exit_with_q() {
    # Set up mock inputs
    setup_mock_inputs "q"

    # Call the menu function
    show_menu "Test Menu" "Option 1" "Option 2" "Option 3"
    local result=$?

    # Assert the result
    assert_return_code 254 $result "Return code should be 254 when user exits with 'q'"
}

# Test exiting with 'quit'
test_menu_exit_with_quit() {
    # Set up mock inputs
    setup_mock_inputs "quit"

    # Call the menu function
    show_menu "Test Menu" "Option 1" "Option 2" "Option 3"
    local result=$?

    # Assert the result
    assert_return_code 254 $result "Return code should be 254 when user exits with 'quit'"
}

# Test max attempt limit
test_menu_max_attempts() {
    # Set up mock inputs - 5 invalid inputs
    setup_mock_inputs "invalid" "0" "10" "abc" "xyz"

    # Call the menu function
    show_menu "Test Menu" "Option 1" "Option 2" "Option 3"
    local result=$?

    # Assert the result
    assert_return_code 255 $result "Return code should be 255 after max invalid attempts"
}

# Test recovery from invalid input
test_menu_recovery_from_invalid() {
    # Set up mock inputs - 2 invalid followed by valid
    setup_mock_inputs "invalid" "abc" "2"

    # Call the menu function
    show_menu "Test Menu" "Option 1" "Option 2" "Option 3"
    local result=$?

    # Assert the result
    assert_equals 1 $MENU_SELECTION "Menu selection index should be 1 (Option 2)"
    assert_return_code 0 $result "Return code should be 0 for valid selection after invalid inputs"
}

# Run all tests
run_test "Valid Menu Selection" test_valid_menu_selection
run_test "Menu Exit with 'q'" test_menu_exit_with_q
run_test "Menu Exit with 'quit'" test_menu_exit_with_quit
run_test "Menu Max Attempts" test_menu_max_attempts
run_test "Menu Recovery from Invalid Input" test_menu_recovery_from_invalid
