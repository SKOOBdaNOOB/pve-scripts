#!/bin/bash
#
# Test Helper Functions
# Provides specialized test environments and utilities
#

# Set script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Global variables for mock environment
MOCK_TEST_ENV=false

# Colors for test output
TEST_RED="\033[31m"
TEST_GREEN="\033[32m"
TEST_YELLOW="\033[33m"
TEST_BLUE="\033[34m"
TEST_MAGENTA="\033[35m"
TEST_RESET="\033[0m"

# Test logging functions
log_test_info() {
    echo -e "${TEST_BLUE}[INFO]${TEST_RESET} $1"
}

log_test_pass() {
    echo -e "${TEST_GREEN}[PASS]${TEST_RESET} $1"
}

log_test_fail() {
    echo -e "${TEST_RED}[FAIL]${TEST_RESET} $1"
}

log_test_warn() {
    echo -e "${TEST_YELLOW}[WARN]${TEST_RESET} $1"
}

log_test_section() {
    echo -e "\n${TEST_MAGENTA}=== $1 ===${TEST_RESET}"
}

# Enable mocked test environment
enable_mock_test_env() {
    MOCK_TEST_ENV=true
    echo "DEBUG: Mock test environment enabled" >&2
}

# Mock core functionality for test environment
mock_core_functions() {
    # Mock check_prerequisites to return success immediately
    function check_prerequisites() {
        echo "DEBUG: Mock check_prerequisites called" >&2
        return 0
    }

    # Mock load_config
    function load_config() {
        echo "DEBUG: Mock load_config called" >&2
        return 0
    }

    # Mock show_config
    function show_config() {
        echo "DEBUG: Mock show_config called" >&2
        return 0
    }

    # Mock any UI functions that might hang or need special handling
    function section_header() {
        echo "DEBUG: Mock section_header: $1" >&2
    }

    # Mock show_header to not clear screen
    function show_header() {
        echo "DEBUG: Mock show_header called" >&2
    }

    # Other mock function overrides as needed
}

# Create a test-safe version of the main script
create_test_script() {
    local output_file="$SCRIPT_DIR/temp_test_script.sh"

    cat > "$output_file" << 'EOF'
#!/bin/bash
# Temporary test script

# Get repo dir from the original script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Source test helpers and mock functions
source "$SCRIPT_DIR/mock/mock_functions.sh"
source "$SCRIPT_DIR/test_helpers.sh"

# Enable mock environment
enable_mock_test_env
enable_test_timeout
mock_core_functions

# Source the real script modules in a controlled way
source "$REPO_DIR/lib/core/ui.sh"
source "$REPO_DIR/lib/core/logging.sh"
source "$REPO_DIR/lib/core/config.sh"
source "$REPO_DIR/lib/core/validation.sh"
source "$REPO_DIR/lib/distributions/distro_info.sh"
source "$REPO_DIR/lib/storage/storage.sh"
source "$REPO_DIR/lib/network/network.sh"
source "$REPO_DIR/lib/vm/vm.sh"

# Override main sections with simplified test versions
function create_new_template() {
    echo "DEBUG: Mock create_new_template called" >&2
    return 0
}

function clone_from_template() {
    echo "DEBUG: Mock clone_from_template called" >&2
    return 0
}

function manage_templates() {
    echo "DEBUG: Mock manage_templates called" >&2
    return 0
}

function perform_batch_operations() {
    echo "DEBUG: Mock perform_batch_operations called" >&2
    return 0
}

function manage_configuration() {
    echo "DEBUG: Mock manage_configuration called" >&2

    local options=("Show Current Configuration" "Configure Logging" "Save Configuration" "Load Configuration" "Create Named Profile" "Load Named Profile")
    show_menu "Select Configuration Option" "${options[@]}"

    case $MENU_SELECTION in
        0) # Show current config
            echo "DEBUG: Mock show_config called" >&2
            ;;
        *) # Other options
            echo "DEBUG: Mock config option $MENU_SELECTION called" >&2
            ;;
    esac

    return 0
}

# Main function simplified for testing
main() {
    echo "DEBUG: Starting test main function" >&2

    # Main menu loop
    while true; do
        echo "DEBUG: Showing main menu" >&2

        local main_options=(
            "Create New Template"
            "Clone from Template"
            "Manage Templates"
            "Batch Operations"
            "Configuration Management"
            "Exit"
        )

        show_menu "Select Option" "${main_options[@]}"
        local menu_result=$?

        echo "DEBUG: Menu selection result: $menu_result, Option: $MENU_SELECTION" >&2

        # Handle special return codes
        if [ $menu_result -eq 254 ]; then
            # User requested to exit
            echo "DEBUG: User requested exit" >&2
            echo "Exit called with code: 0"
            exit 0
        elif [ $menu_result -eq 255 ]; then
            # Too many invalid attempts
            echo "DEBUG: Too many invalid attempts" >&2
            echo "Exit called with code: 1"
            exit 1
        fi

        case $MENU_SELECTION in
            0) # Create new template
                create_new_template
                ;;
            1) # Clone from template
                clone_from_template
                ;;
            2) # Manage templates
                manage_templates
                ;;
            3) # Batch operations
                perform_batch_operations
                ;;
            4) # Configuration management
                manage_configuration
                ;;
            5) # Exit
                echo "DEBUG: Exit option selected" >&2
                echo "Exit called with code: 0"
                exit 0
                ;;
        esac

        echo "DEBUG: Asking to press Enter to return to menu" >&2
        echo -e "\nPress Enter to return to the main menu..."
        read -r
    done
}

# Run the main function with test wrappers
main
EOF

    chmod +x "$output_file"
    echo "$output_file"
}

# Run a test with the test-safe script
run_test_in_safe_env() {
    local test_script=$(create_test_script)
    local timeout_seconds=${1:-10}

    echo "DEBUG: Running test in safe environment with $timeout_seconds second timeout" >&2

    # Check if the timeout command is available
    if command -v timeout &> /dev/null; then
        # Use timeout command if available
        timeout $timeout_seconds bash -c "source $test_script" || {
            local exit_code=$?
            if [ $exit_code -eq 124 ]; then
                echo "ERROR: Test timed out after $timeout_seconds seconds" >&2
                rm -f "$test_script"
                return 2  # Our timeout exit code
            else
                rm -f "$test_script"
                return $exit_code
            fi
        }
    else
        # Fallback method using background process and kill
        echo "DEBUG: Using fallback timeout method (timeout command not available)" >&2

        # Create a temporary file to store output
        local output_file=$(mktemp)

        # Run the script in background and capture PID
        (
            # Set a trap to handle the timeout
            trap 'echo "DEBUG: Script execution completed" >&2' EXIT

            # Run the script and save output
            bash -c "source $test_script" > "$output_file" 2>&1
        ) &
        local script_pid=$!

        # Wait for script to finish or timeout
        local elapsed=0
        local sleep_interval=1
        while kill -0 $script_pid 2>/dev/null; do
            sleep $sleep_interval
            elapsed=$((elapsed + sleep_interval))

            # Check if we've reached the timeout
            if [ $elapsed -ge $timeout_seconds ]; then
                echo "ERROR: Test timed out after $timeout_seconds seconds" >&2
                kill -9 $script_pid 2>/dev/null || true
                wait $script_pid 2>/dev/null || true
                cat "$output_file"
                rm -f "$output_file" "$test_script"
                return 2  # Our timeout exit code
            fi
        done

        # Get the exit code
        wait $script_pid
        local exit_code=$?

        # Display the output
        cat "$output_file"

        # Clean up
        rm -f "$output_file"
    fi

    # Clean up
    rm -f "$test_script"

    return 0
}
