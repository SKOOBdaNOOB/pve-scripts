#!/bin/bash
#
# Module Loading Tests for Proxmox VM Template Wizard
# Tests that all modules are correctly loaded and functions are accessible
#

# Source test helpers and mock functions
source "$(dirname "${BASH_SOURCE[0]}")/../mock/mock_functions.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../test_helpers.sh"

# Test setup
test_setup() {
    # Capture script and repo directories to ensure proper path resolution
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

    # Ensure logs directory exists
    mkdir -p "${HOME}/.pve-template-wizard/logs" 2>/dev/null

    log_test_info "Starting module loading tests"

    # Initialize test tracking
    TEST_COUNT=0
    TEST_PASSED=0
    TEST_FAILED=0
}

# Test function availability with detailed diagnostics on failure
test_function_exists() {
    local function_name="$1"
    local module_name="$2"

    ((TEST_COUNT++))

    if declare -F "$function_name" > /dev/null; then
        log_test_pass "Function '$function_name' from module '$module_name' is available"
        ((TEST_PASSED++))
        return 0
    else
        log_test_fail "Function '$function_name' from module '$module_name' is NOT available"
        # Diagnostic output for debugging
        echo "-------- Module Loading Diagnostic Info --------"
        echo "Function not found: $function_name"
        echo "Module source path: $REPO_DIR/lib/$module_name"
        echo "Current functions loaded: $(declare -F | grep -v "_test")"
        echo "--------------------------------------------"
        ((TEST_FAILED++))
        return 1
    fi
}

# Test that all core modules load correctly
test_core_modules_loading() {
    log_test_section "Testing Core Modules Loading"

    # Source each core module
    source "$REPO_DIR/lib/core/ui.sh"
    source "$REPO_DIR/lib/core/logging.sh"
    source "$REPO_DIR/lib/core/config.sh"
    source "$REPO_DIR/lib/core/validation.sh"

    # Test core UI functions
    test_function_exists "show_menu" "core/ui.sh"
    test_function_exists "prompt_yes_no" "core/ui.sh"
    test_function_exists "section_header" "core/ui.sh"

    # Test logging functions
    test_function_exists "init_logging" "core/logging.sh"
    test_function_exists "log_info" "core/logging.sh"

    # Test config functions
    test_function_exists "load_config" "core/config.sh"
    test_function_exists "save_config" "core/config.sh"

    # Test validation functions
    test_function_exists "validate_ip" "core/validation.sh"
    test_function_exists "validate_path" "core/validation.sh"
}

# Test that all functional modules load correctly
test_functional_modules_loading() {
    log_test_section "Testing Functional Modules Loading"

    # Source each functional module
    source "$REPO_DIR/lib/distributions/distro_info.sh"
    source "$REPO_DIR/lib/storage/storage.sh"
    source "$REPO_DIR/lib/network/network.sh"
    source "$REPO_DIR/lib/vm/vm.sh"

    # Test distribution functions
    test_function_exists "get_distro_keys" "distributions/distro_info.sh"

    # Test storage functions
    test_function_exists "select_storage_pool" "storage/storage.sh"
    test_function_exists "get_storage_pools" "storage/storage.sh"

    # Test network functions
    test_function_exists "configure_network" "network/network.sh"

    # Test VM functions
    test_function_exists "create_vm" "vm/vm.sh"
}

# Test module interdependencies
test_module_interdependencies() {
    log_test_section "Testing Module Interdependencies"

    # Test if storage.sh can properly call functions from its dependencies
    source "$REPO_DIR/lib/storage/storage.sh"

    # The storage module should be able to access UI functions
    if type section_header >/dev/null 2>&1; then
        log_test_pass "Storage module can access UI functions"
        ((TEST_PASSED++))
    else
        log_test_fail "Storage module CANNOT access UI functions"
        ((TEST_FAILED++))
    fi

    # The storage module should be able to access logging functions
    if type log_info >/dev/null 2>&1; then
        log_test_pass "Storage module can access logging functions"
        ((TEST_PASSED++))
    else
        log_test_fail "Storage module CANNOT access logging functions"
        ((TEST_FAILED++))
    fi

    # The storage module should be able to access validation functions
    if type validate_path >/dev/null 2>&1; then
        log_test_pass "Storage module can access validation functions"
        ((TEST_PASSED++))
    else
        log_test_fail "Storage module CANNOT access validation functions"
        ((TEST_FAILED++))
    fi
}

# Test the entrypoint script itself
test_main_script_loading() {
    log_test_section "Testing Main Script Loading"

    # Source the main script with all module initialization
    # Using a subshell to prevent any exit calls from terminating our test
    (
        # Mock certain functions to prevent actual execution
        function check_prerequisites() { return 0; }
        function show_header() { echo "Header shown"; }

        # Source the main script
        source "$REPO_DIR/bin/pve-template-wizard.sh"
    )

    # Verify main functions are loaded
    test_function_exists "create_new_template" "bin/pve-template-wizard.sh"
    test_function_exists "manage_templates" "bin/pve-template-wizard.sh"
    test_function_exists "clone_from_template" "bin/pve-template-wizard.sh"
}

# Print test results
print_test_results() {
    log_test_section "Test Results"

    echo "Tests executed: $TEST_COUNT"
    echo "Tests passed:   $TEST_PASSED"
    echo "Tests failed:   $TEST_FAILED"

    if [ $TEST_FAILED -eq 0 ]; then
        log_test_pass "All module loading tests passed!"
        return 0
    else
        log_test_fail "$TEST_FAILED module loading tests failed!"
        return 1
    fi
}

# Main test function
main() {
    test_setup

    test_core_modules_loading
    test_functional_modules_loading
    test_module_interdependencies
    test_main_script_loading

    print_test_results
}

# Run the tests
main
