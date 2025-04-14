#!/bin/bash
#
# Integration test for distribution to storage flow
# Tests the specific path where the error occurred in the wizard
#

# Source test helpers and mock functions
source "$(dirname "${BASH_SOURCE[0]}")/../mock/mock_functions.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../test_helpers.sh"

# Set script paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
WIZARD_SCRIPT="$REPO_DIR/bin/pve-template-wizard.sh"

# Test the main flow path that was failing
test_distribution_to_storage_flow() {
    log_test_section "Testing Distribution to Storage Flow"

    # Setup mocked environment
    mock_proxmox_commands

    # Create a temporary script that isolates and tests just the relevant function
    local test_script=$(mktemp)
    cat > "$test_script" << 'EOF'
#!/bin/bash

# Get repo dir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Set up a test environment
export TEST_MODE=true

# Source required modules in the correct order
source "$REPO_DIR/lib/core/ui.sh"
source "$REPO_DIR/lib/core/logging.sh"
source "$REPO_DIR/lib/core/config.sh"
source "$REPO_DIR/lib/core/validation.sh"
source "$REPO_DIR/lib/distributions/distro_info.sh"
source "$REPO_DIR/lib/storage/storage.sh"
source "$REPO_DIR/lib/network/network.sh"
source "$REPO_DIR/lib/vm/vm.sh"

# Initialize logging
init_logging "debug" "/tmp/test-wizard.log"

# Test function
test_dist_to_storage() {
    # Select a distribution
    SELECTED_DISTRO="ubuntu2204"
    VM_NAME="ubuntu-template"

    echo "=== About to call select_storage_pool function ==="

    # Directly call the function that was failing
    if select_storage_pool; then
        echo "SUCCESS: select_storage_pool function executed successfully"
        return 0
    else
        echo "ERROR: select_storage_pool function failed"
        return 1
    fi
}

# Run the test
test_dist_to_storage
exit $?
EOF

    chmod +x "$test_script"

    # Execute the test script
    log_test_info "Running distribution to storage flow test"
    if bash "$test_script"; then
        log_test_pass "Distribution to storage flow test passed: select_storage_pool function is accessible and working"
        rm -f "$test_script"
        return 0
    else
        log_test_fail "Distribution to storage flow test FAILED: select_storage_pool function is not accessible or not working"
        echo "Check that the function is properly defined and imported in the create_new_template function"
        rm -f "$test_script"
        return 1
    fi

    # Clean up mock environment
    cleanup_mock_proxmox
}

# Test with mocked input to simulate user selecting options
test_full_template_creation_flow() {
    log_test_section "Testing Full Template Creation Flow"

    # Setup mocked environment
    mock_proxmox_commands

    # Create temporary files for test input and output
    local input_file=$(mktemp)
    local output_file=$(mktemp)

    # Prepare input sequence - this matches what would be entered in the wizard
    cat > "$input_file" << EOF
n
1
1
1
100
n
y
EOF

    # Create a temporary script to run the wizard with input
    local test_script=$(mktemp)
    cat > "$test_script" << EOF
#!/bin/bash
set -e

# Print diagnostic header
echo "=== Testing Full Template Creation Flow ==="

# Run the wizard with input
cat "$input_file" | bash "$REPO_DIR/bin/pve-template-wizard.sh" > "$output_file" 2>&1
exit_code=\$?

# Check for success
if [ \$exit_code -eq 0 ]; then
    echo "SUCCESS: Wizard completed without errors"
    exit 0
else
    echo "ERROR: Wizard exited with code \$exit_code"
    echo "=== Output ==="
    cat "$output_file"
    echo "=============="
    exit 1
fi
EOF

    chmod +x "$test_script"

    # Run the test script with timeout
    local timeout_seconds=30
    log_test_info "Running full template creation flow with timeout of $timeout_seconds seconds"

    if command -v timeout &> /dev/null; then
        if timeout $timeout_seconds bash "$test_script"; then
            log_test_pass "Full template creation flow passed"
            rm -f "$input_file" "$output_file" "$test_script"
            return 0
        else
            local exit_code=$?
            if [ $exit_code -eq 124 ]; then
                log_test_fail "Full template creation flow FAILED: Test timed out after $timeout_seconds seconds"
                echo "This suggests the wizard may be hanging or waiting for input that wasn't provided"
            else
                log_test_fail "Full template creation flow FAILED with exit code $exit_code"
            fi
            echo "=== Test Output ==="
            cat "$output_file"
            echo "==================="
            rm -f "$input_file" "$output_file" "$test_script"
            return 1
        fi
    else
        # Fallback if timeout command isn't available
        log_test_warn "timeout command not available, test may hang if there are issues"
        if bash "$test_script"; then
            log_test_pass "Full template creation flow passed"
            rm -f "$input_file" "$output_file" "$test_script"
            return 0
        else
            local exit_code=$?
            log_test_fail "Full template creation flow FAILED with exit code $exit_code"
            echo "=== Test Output ==="
            cat "$output_file"
            echo "==================="
            rm -f "$input_file" "$output_file" "$test_script"
            return 1
        fi
    fi

    # Clean up mock environment
    cleanup_mock_proxmox
}

# Main function
main() {
    log_test_info "Starting wizard distribution to storage flow tests"

    # Run the isolated function test first
    test_distribution_to_storage_flow
    local function_test_result=$?

    # If the function test passes, try the full flow test
    if [ $function_test_result -eq 0 ]; then
        test_full_template_creation_flow
        local flow_test_result=$?

        if [ $flow_test_result -eq 0 ]; then
            log_test_section "All wizard flow tests PASSED"
            return 0
        else
            log_test_section "Full flow test FAILED"
            return 1
        fi
    else
        log_test_section "Function test FAILED, skipping full flow test"
        return 1
    fi
}

# Execute main if this script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
