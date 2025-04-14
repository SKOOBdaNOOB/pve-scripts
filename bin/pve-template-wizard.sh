#!/bin/bash
#
# Proxmox VM Template Creation Wizard
# A comprehensive tool for creating and managing VM templates in Proxmox
#

# Resolve script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Import required modules
source "$REPO_DIR/lib/core/ui.sh"
source "$REPO_DIR/lib/core/logging.sh"
source "$REPO_DIR/lib/core/config.sh"
source "$REPO_DIR/lib/core/validation.sh"
source "$REPO_DIR/lib/distributions/distro_info.sh"
source "$REPO_DIR/lib/storage/storage.sh"
source "$REPO_DIR/lib/network/network.sh"
source "$REPO_DIR/lib/vm/vm.sh"

# Initialize logging
init_logging "info" "${HOME}/.pve-template-wizard/logs/wizard.log"

# Function to check prerequisites
check_prerequisites() {
    section_header "Checking Prerequisites"

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        show_warning "This script should be run as root for full functionality."
        if ! prompt_yes_no "Continue anyway?" "N"; then
            exit 1
        fi
    else
        show_success "Running with root privileges."
    fi

    # Check for required commands
    local required_commands=("qm" "pvesh" "wget" "sha256sum")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -gt 0 ]; then
        show_error "Missing required commands: ${missing_commands[*]}"
        show_info "Please install the required packages and try again."
        exit 1
    else
        show_success "All required commands are available."
    fi

    # Check if running on a Proxmox server
    if [ ! -f "/etc/pve/qemu-server" ] && [ ! -d "/etc/pve" ]; then
        show_warning "This doesn't appear to be a Proxmox server."
        if ! prompt_yes_no "Continue anyway?" "N"; then
            exit 1
        fi
    else
        show_success "Running on a Proxmox server."
    fi

    # Check write permissions in common directories
    local dirs_to_check=("/etc/pve" "$IMAGES_PATH")
    local permission_issues=0

    for dir in "${dirs_to_check[@]}"; do
        if [ -d "$dir" ]; then
            if [ ! -w "$dir" ]; then
                show_warning "No write permission for $dir - some operations may fail."
                permission_issues=$((permission_issues + 1))
            else
                show_success "Write permission verified for $dir."
            fi
        fi
    done

    if [ $permission_issues -gt 0 ]; then
        show_warning "Some directories have permission issues. Consider running as root."
        if ! prompt_yes_no "Continue anyway?" "Y"; then
            exit 1
        fi
    fi

    return 0
}

# Function to create a new template
create_new_template() {
    section_header "Create New Template"

    # Select distribution
    local distro_keys=($(get_distro_keys))
    local distro_names=()

    for key in "${distro_keys[@]}"; do
        distro_names+=("${DISTRO_INFO["$key,name"]}")
    done

    show_menu "Select Linux Distribution" "${distro_names[@]}"
    local selected_distro="${distro_keys[$MENU_SELECTION]}"
    SELECTED_DISTRO="$selected_distro"
    VM_NAME="${selected_distro/[0-9]/-template}"

    show_success "Selected: ${DISTRO_INFO["$selected_distro,name"]}"

    # Configure storage
    select_storage_pool

    # Configure resources
    configure_vm_resources

    # Configure network
    configure_network

    # Configure cloud-init
    configure_cloud_init

    # Template ID
    TEMPLATE_ID=$(prompt_value "Enter template ID" "$TEMPLATE_ID" "^[0-9]+$")

    # Review configuration
    section_header "Review Configuration"

    show_config

    if ! prompt_yes_no "Is this configuration correct?" "Y"; then
        show_info "Template creation cancelled."
        return 1
    fi

    # Download distribution image if needed
    local disk_image

    if ! disk_image=$(get_disk_image_path "$selected_distro" "$IMAGES_PATH"); then
        show_error "Failed to get disk image path for $selected_distro"
        return 1
    fi

    if [ ! -f "$disk_image" ]; then
        show_info "Downloading ${DISTRO_INFO["$selected_distro,name"]} cloud image..."
        if ! download_distro_image "$selected_distro" "$IMAGES_PATH"; then
            show_error "Failed to download cloud image"
            return 1
        fi
    fi

    # Create the template
    if create_vm "$TEMPLATE_ID" "$VM_NAME" "$disk_image" true; then
        show_success "Template created successfully: $VM_NAME (ID: $TEMPLATE_ID)"
        # Save configuration
        save_config
        return 0
    else
        show_error "Failed to create template"
        return 1
    fi
}

# Function to clone from template
clone_from_template() {
    section_header "Clone from Template"

    # List available templates
    if ! list_templates; then
        show_warning "No templates available for cloning."
        if prompt_yes_no "Would you like to create a new template first?" "Y"; then
            create_new_template
            # Try again after creating a template
            if ! list_templates; then
                show_error "No templates available after creation attempt."
                return 1
            fi
        else
            return 1
        fi
    fi

    # Clone selected template
    if clone_template; then
        return 0
    else
        return 1
    fi
}

# Function to manage templates
manage_templates() {
    section_header "Template Management"

    # Check if templates exist
    if ! list_templates; then
        show_warning "No templates found to manage."
        return 1
    fi

    # Management options
    local options=("Modify Template" "Delete Template")
    show_menu "Select Template Operation" "${options[@]}"

    case $MENU_SELECTION in
        0) # Modify
            modify_template
            ;;
        1) # Delete
            delete_template
            ;;
    esac

    return 0
}

# Function for batch operations
perform_batch_operations() {
    section_header "Batch Operations"

    batch_template_operations

    return 0
}

# Function to manage configuration
manage_configuration() {
    section_header "Configuration Management"

    local options=("Show Current Configuration" "Configure Logging" "Save Configuration" "Load Configuration" "Create Named Profile" "Load Named Profile")
    show_menu "Select Configuration Option" "${options[@]}"

    case $MENU_SELECTION in
        0) # Show current config
            show_config
            ;;
        1) # Configure logging
            configure_logging
            ;;
        2) # Save configuration
            save_config
            ;;
        3) # Load configuration
            load_config
            ;;
        4) # Create profile
            local profile_name
            profile_name=$(prompt_value "Enter profile name" "default")
            save_profile "$profile_name"
            ;;
        5) # Load profile
            list_profiles
            local profile_name
            profile_name=$(prompt_value "Enter profile name to load" "default")
            load_profile "$profile_name"
            ;;
    esac

    return 0
}

# Main function
main() {
    show_header

    # Check prerequisites first
    check_prerequisites

    # Try to load default configuration
    load_config

    # Main menu loop
    while true; do
        section_header "Main Menu"

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

        # Handle special return codes
        if [ $menu_result -eq 254 ]; then
            # User requested to exit
            section_header "Exiting"
            show_info "Thank you for using the Proxmox VM Template Creation Wizard!"
            exit 0
        elif [ $menu_result -eq 255 ]; then
            # Too many invalid attempts
            show_error "Menu selection failed. Please restart the wizard."
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
                section_header "Exiting"
                show_info "Thank you for using the Proxmox VM Template Creation Wizard!"
                exit 0
                ;;
        esac

        echo ""
        show_info "Press Enter to return to the main menu..."
        read -r
    done
}

# Run the main function
main
