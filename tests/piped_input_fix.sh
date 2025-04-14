#!/bin/bash
#
# Piped Input Fix Validation
#

# Print a section header
print_header() {
    echo "=================================================="
    echo "  $1"
    echo "=================================================="
    echo
}

# Print a section with code
print_code_section() {
    echo "*** $1 ***"
    echo "$2"
    echo
}

# Main function
main() {
    print_header "Proxmox VM Template Wizard - Piped Input Fix"

    echo "This script demonstrates the fix implemented for handling piped input"
    echo "in the Proxmox VM Template Creation Wizard."
    echo

    echo "## Issue Description"
    echo
    echo "When running the wizard via a pipe (e.g., curl | bash), the menu"
    echo "selection was failing repeatedly with 'Invalid selection' errors."
    echo "This occurred because when stdin is already consumed by the pipe,"
    echo "the read command receives empty input."
    echo

    echo "## Solution"
    echo
    echo "We modified all interactive input functions in lib/core/ui.sh to detect"
    echo "when stdin is redirected and use /dev/tty for reading from the terminal"
    echo "in those cases."
    echo

    echo "## Changes Made"
    echo

    print_code_section "1. Menu Selection Function" "# Function to display a menu and get selection
show_menu() {
    # ... existing code ...

    while true; do
        # ... existing code ...

        # Check if stdin is a terminal or is being redirected
        if [ -t 0 ]; then
            # Terminal input
            read -p \"Enter selection [1-\${#options[@]}]: \" selection
        else
            # Redirected input - use /dev/tty instead
            echo -n \"Enter selection [1-\${#options[@]}]: \"
            read selection < /dev/tty
        fi

        # ... rest of existing code ...
    done
}"

    print_code_section "2. Yes/No Prompt Function" "# Function to prompt for yes/no
prompt_yes_no() {
    # ... existing code ...

    while true; do
        # Check if stdin is a terminal or is being redirected
        if [ -t 0 ]; then
            # Terminal input
            read -p \"\$prompt \" response
        else
            # Redirected input - use /dev/tty instead
            echo -n \"\$prompt \"
            read response < /dev/tty
        fi

        # ... rest of existing code ...
    done
}"

    print_code_section "3. Value Prompt Function" "# Function to prompt for a value with validation
prompt_value() {
    # ... existing code ...

    while true; do
        # Check if stdin is a terminal or is being redirected
        if [ -t 0 ]; then
            # Terminal input
            read -p \"\$prompt [\${default}]: \" value
        else
            # Redirected input - use /dev/tty instead
            echo -n \"\$prompt [\${default}]: \"
            read value < /dev/tty
        fi

        # ... rest of existing code ...
    done
}"

    echo "## Impact"
    echo
    echo "With these changes, the Template Wizard can now be run successfully"
    echo "through a pipe (curl | bash) and will properly handle user input."
    echo "This fixes the issue where the script was failing with repeated"
    echo "'Invalid selection' errors when run via curl."
    echo

    echo "## Testing"
    echo
    echo "To test this fix, you can run the Template Wizard with:"
    echo
    echo "    curl -sSL https://raw.githubusercontent.com/SKOOBdaNOOB/pve-scripts/main/bootstrap/template-wizard.sh | bash"
    echo
    echo "The menu selection should now work correctly, allowing you to"
    echo "navigate through the wizard options."
    echo
}

# Run the main function
main
