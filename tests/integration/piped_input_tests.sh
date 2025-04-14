#!/bin/bash
#
# Piped Input Tests for Proxmox VM Template Wizard
# Tests that the script handles piped input correctly, particularly for menu selections
#

# Source test helpers and mock functions
source "$(dirname "${BASH_SOURCE[0]}")/../mock/mock_functions.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../test_helpers.sh"

# Path to the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
WIZARD_SCRIPT="$REPO_DIR/bin/pve-template-wizard.sh"

# Test piped input in menu selections
test_piped_input_menu_selection() {
    log_test_section "Testing Menu Selection with Piped Input"

    # Create a temporary file for our test input
    local input_file=$(mktemp)

    # Prepare the input sequence to navigate through wizard
    # 1. Select 'n' when asked to load config (to start fresh)
    # 2. Select '1' in main menu (Create New Template)
    # 3. Select '1' for distribution choice
    # 4. Select '1' for storage pool choice
    # 5. Select 'q' to go back and exit
    cat > "$input_file" << EOF
n
1
1
1
q
EOF

    # Set up test timeout (15 seconds should be enough for this test)
    local timeout_seconds=15

    log_test_info "Running wizard with piped input - will timeout in $timeout_seconds seconds"

    # Create a temporary script that runs the wizard with our piped input
    local test_script=$(mktemp)
    cat > "$test_script" << EOF
#!/bin/bash
set -e  # Exit on any error
# Set up mock environment
source "$REPO_DIR/tests/mock/mock_functions.sh"
mock_proxmox_commands

# Print diagnostic info
echo "=== Starting piped input test ==="
echo "Using input from: $input_file"

# Redirect stderr to a temporary file for analysis
STDERR_LOG=\$(mktemp)
echo "Logging stderr to: \$STDERR_LOG"

# Run the actual test with piped input
cat "$input_file" | bash "$WIZARD_SCRIPT" >\$(mktemp) 2>\$STDERR_LOG

# Check for critical errors in stderr
if grep -q "command not found" \$STDERR_LOG; then
    echo "ERROR: 'command not found' detected in stderr!"
    echo "=== STDERR Contents ==="
    cat \$STDERR_LOG
    echo "======================="
    exit 1
fi

if grep -q "select_storage_pool" \$STDERR_LOG; then
    echo "ERROR: Issues with select_storage_pool function detected!"
    echo "=== STDERR Contents ==="
    cat \$STDERR_LOG
    echo "======================="
    exit 1
fi

# Look specifically for our error case
if grep -q "select_storage_pool: command not found" \$STDERR_LOG; then
    echo "ERROR: The specific error 'select_storage_pool: command not found' was detected!"
    exit 1
fi

echo "=== Piped input test completed successfully ==="
exit 0
EOF

    chmod +x "$test_script"

    # Run the test script with timeout
    local test_output_file=$(mktemp)
    if command -v timeout &> /dev/null; then
        if timeout $timeout_seconds bash "$test_script" > "$test_output_file" 2>&1; then
            log_test_pass "Menu selection with piped input test passed"
            cat "$test_output_file"

            # Clean up
            rm -f "$input_file" "$test_script" "$test_output_file"
            return 0
        else
            local exit_code=$?
            log_test_fail "Menu selection with piped input test FAILED with exit code $exit_code"
            echo "=== Test Output ==="
            cat "$test_output_file"
            echo "=================="

            # Clean up
            rm -f "$input_file" "$test_script" "$test_output_file"
            return 1
        fi
    else
        # Fallback if timeout command isn't available
        log_test_warn "timeout command not available, using fallback approach"

        bash "$test_script" > "$test_output_file" 2>&1 &
        local pid=$!

        # Wait for test to complete or timeout
        local count=0
        while kill -0 $pid 2>/dev/null; do
            sleep 1
            ((count++))
            if [ $count -ge $timeout_seconds ]; then
                log_test_fail "Test timed out after $timeout_seconds seconds"
                kill -9 $pid 2>/dev/null || true
                echo "=== Test Output (Incomplete - Test Timed Out) ==="
                cat "$test_output_file"
                echo "================================================="

                # Clean up
                rm -f "$input_file" "$test_script" "$test_output_file"
                return 1
            fi
        done

        # Get exit code
        wait $pid
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            log_test_pass "Menu selection with piped input test passed"
            cat "$test_output_file"

            # Clean up
            rm -f "$input_file" "$test_script" "$test_output_file"
            return 0
        else
            log_test_fail "Menu selection with piped input test FAILED with exit code $exit_code"
            echo "=== Test Output ==="
            cat "$test_output_file"
            echo "=================="

            # Clean up
            rm -f "$input_file" "$test_script" "$test_output_file"
            return 1
        fi
    fi
}

# Main function
main() {
    log_test_info "Starting piped input tests for Proxmox VM Template Wizard"

    # Run the tests
    test_piped_input_menu_selection

    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log_test_section "All piped input tests PASSED"
        return 0
    else
        log_test_section "Some piped input tests FAILED"
        return 1
    fi
}

# Execute main if this script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
