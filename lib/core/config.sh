#!/bin/bash
#
# Configuration Management for Proxmox VM Template Wizard
# Handles loading, saving, and validating configuration settings
#

# Import UI module
source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"

# Default configuration file path
CONFIG_FILE="${HOME}/.pve-template-wizard.conf"

# Default configuration values
IMAGES_PATH="/cloud-init/"
QEMU_CPU_MODEL="host"
VM_CPU_SOCKETS=1
VM_CPU_CORES=2
VM_MEMORY=4098
VM_RESOURCE_POOL=""
CLOUD_INIT_USER="user"
CLOUD_INIT_SSHKEY="${HOME}/.ssh/id_rsa.pub"
CLOUD_INIT_IP="dhcp"
CLOUD_INIT_NAMESERVER="1.1.1.1"
CLOUD_INIT_SEARCHDOMAIN="example.com"
TEMPLATE_ID=1001
VM_NAME=""
VM_DISK_IMAGE=""
SELECTED_DISTRO=""
LOG_LEVEL="info"
LOG_FILE=""

# Function to load configuration from file
load_config() {
    local config_file="${1:-$CONFIG_FILE}"

    if [ -f "$config_file" ]; then
        section_header "Loading Configuration"

        if prompt_yes_no "Found saved configuration at $config_file. Would you like to load it?" "Y"; then
            # Source the config file
            source "$config_file"
            show_success "Configuration loaded from $config_file"
            return 0
        else
            show_info "Using default configuration."
            return 1
        fi
    else
        show_info "No configuration file found at $config_file. Using default configuration."
        return 1
    fi
}

# Function to save configuration to file
save_config() {
    local config_file="${1:-$CONFIG_FILE}"

    section_header "Saving Configuration"

    if prompt_yes_no "Would you like to save this configuration for future use?" "Y"; then
        # Create config directory if it doesn't exist
        local config_dir=$(dirname "$config_file")
        if [ ! -d "$config_dir" ]; then
            mkdir -p "$config_dir" || {
                show_error "Failed to create configuration directory: $config_dir"
                return 1
            }
        fi

        # Create configuration file with current settings
        cat > "$config_file" <<EOL
# Proxmox VM Template Wizard Configuration
# Generated on $(date)
IMAGES_PATH="$IMAGES_PATH"
QEMU_CPU_MODEL="$QEMU_CPU_MODEL"
VM_CPU_SOCKETS=$VM_CPU_SOCKETS
VM_CPU_CORES=$VM_CPU_CORES
VM_MEMORY=$VM_MEMORY
VM_RESOURCE_POOL="$VM_RESOURCE_POOL"
CLOUD_INIT_USER="$CLOUD_INIT_USER"
CLOUD_INIT_SSHKEY="$CLOUD_INIT_SSHKEY"
CLOUD_INIT_IP="$CLOUD_INIT_IP"
CLOUD_INIT_NAMESERVER="$CLOUD_INIT_NAMESERVER"
CLOUD_INIT_SEARCHDOMAIN="$CLOUD_INIT_SEARCHDOMAIN"
TEMPLATE_ID=$TEMPLATE_ID
SELECTED_DISTRO="$SELECTED_DISTRO"
LOG_LEVEL="$LOG_LEVEL"
LOG_FILE="$LOG_FILE"
EOL
        # Check if save was successful
        if [ $? -eq 0 ]; then
            # Set permissions to restrict to current user
            chmod 600 "$config_file"
            show_success "Configuration saved to $config_file"
            return 0
        else
            show_error "Failed to save configuration to $config_file"
            return 1
        fi
    else
        show_info "Configuration not saved."
        return 1
    fi
}

# Function to create a named profile
save_profile() {
    local profile_name="$1"
    local profile_path="${HOME}/.pve-template-wizard/profiles"

    # Create profiles directory if it doesn't exist
    if [ ! -d "$profile_path" ]; then
        mkdir -p "$profile_path" || {
            show_error "Failed to create profiles directory: $profile_path"
            return 1
        }
    fi

    local profile_file="${profile_path}/${profile_name}.conf"

    # Save configuration to profile file
    if save_config "$profile_file"; then
        show_success "Profile '$profile_name' saved to $profile_file"
        return 0
    else
        show_error "Failed to save profile '$profile_name'"
        return 1
    fi
}

# Function to load a named profile
load_profile() {
    local profile_name="$1"
    local profile_path="${HOME}/.pve-template-wizard/profiles"
    local profile_file="${profile_path}/${profile_name}.conf"

    # Check if profile file exists
    if [ -f "$profile_file" ]; then
        if load_config "$profile_file"; then
            show_success "Profile '$profile_name' loaded from $profile_file"
            return 0
        else
            show_error "Failed to load profile '$profile_name'"
            return 1
        fi
    else
        show_error "Profile '$profile_name' does not exist"
        return 1
    fi
}

# Function to list available profiles
list_profiles() {
    local profile_path="${HOME}/.pve-template-wizard/profiles"

    # Check if profiles directory exists
    if [ ! -d "$profile_path" ]; then
        show_info "No profiles directory found."
        return 1
    fi

    local profiles=()

    # Get list of profile files
    while IFS= read -r -d '' file; do
        local profile_name=$(basename "$file" .conf)
        profiles+=("$profile_name")
    done < <(find "$profile_path" -name "*.conf" -print0)

    # Display profiles
    if [ ${#profiles[@]} -eq 0 ]; then
        show_info "No profiles found."
        return 1
    else
        section_header "Available Profiles"
        for profile in "${profiles[@]}"; do
            echo "  - $profile"
        done
        echo ""
        return 0
    fi
}

# Function to validate configuration
validate_config() {
    local validation_errors=0

    # Validate image path
    if [ ! -d "$IMAGES_PATH" ]; then
        show_warning "Image path '$IMAGES_PATH' does not exist"
        validation_errors=$((validation_errors + 1))
    fi

    # Validate SSH key
    if [ ! -f "$CLOUD_INIT_SSHKEY" ]; then
        show_warning "SSH key file '$CLOUD_INIT_SSHKEY' does not exist"
        validation_errors=$((validation_errors + 1))
    fi

    # Validate IP address if not DHCP
    if [ "$CLOUD_INIT_IP" != "dhcp" ]; then
        local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?(,gw=([0-9]{1,3}\.){3}[0-9]{1,3})?$'
        if ! [[ "$CLOUD_INIT_IP" =~ $ip_regex ]]; then
            show_warning "Invalid IP address format: '$CLOUD_INIT_IP'"
            validation_errors=$((validation_errors + 1))
        fi
    fi

    # Validate numeric values
    if ! [[ "$VM_CPU_SOCKETS" =~ ^[0-9]+$ ]] || [ "$VM_CPU_SOCKETS" -lt 1 ]; then
        show_warning "Invalid CPU socket count: '$VM_CPU_SOCKETS'"
        validation_errors=$((validation_errors + 1))
    fi

    if ! [[ "$VM_CPU_CORES" =~ ^[0-9]+$ ]] || [ "$VM_CPU_CORES" -lt 1 ]; then
        show_warning "Invalid CPU core count: '$VM_CPU_CORES'"
        validation_errors=$((validation_errors + 1))
    fi

    if ! [[ "$VM_MEMORY" =~ ^[0-9]+$ ]] || [ "$VM_MEMORY" -lt 256 ]; then
        show_warning "Invalid memory value: '$VM_MEMORY'"
        validation_errors=$((validation_errors + 1))
    fi

    if ! [[ "$TEMPLATE_ID" =~ ^[0-9]+$ ]] || [ "$TEMPLATE_ID" -lt 100 ]; then
        show_warning "Invalid template ID: '$TEMPLATE_ID'"
        validation_errors=$((validation_errors + 1))
    fi

    # Return validation result
    if [ "$validation_errors" -gt 0 ]; then
        show_warning "Found $validation_errors configuration issues"
        return 1
    else
        show_success "Configuration validation passed"
        return 0
    fi
}

# Function to display current configuration
show_config() {
    section_header "Current Configuration"

    echo -e "${BOLD}General Settings:${RESET}"
    echo -e "  Image Path:       ${IMAGES_PATH}"
    echo -e "  Template ID:      ${TEMPLATE_ID}"
    echo -e "  Selected Distro:  ${SELECTED_DISTRO}"
    [ -n "$VM_NAME" ] && echo -e "  VM Name:         ${VM_NAME}"
    echo ""

    echo -e "${BOLD}VM Resources:${RESET}"
    echo -e "  CPU Model:        ${QEMU_CPU_MODEL}"
    echo -e "  CPU Sockets:      ${VM_CPU_SOCKETS}"
    echo -e "  CPU Cores:        ${VM_CPU_CORES}"
    echo -e "  Memory (MB):      ${VM_MEMORY}"
    [ -n "$VM_RESOURCE_POOL" ] && echo -e "  Resource Pool:    ${VM_RESOURCE_POOL}"
    echo ""

    echo -e "${BOLD}Cloud-Init Settings:${RESET}"
    echo -e "  Username:         ${CLOUD_INIT_USER}"
    echo -e "  SSH Key:          ${CLOUD_INIT_SSHKEY}"
    echo -e "  IP Configuration: ${CLOUD_INIT_IP}"
    echo -e "  Nameserver:       ${CLOUD_INIT_NAMESERVER}"
    echo -e "  Search Domain:    ${CLOUD_INIT_SEARCHDOMAIN}"
    echo ""

    echo -e "${BOLD}Logging:${RESET}"
    echo -e "  Log Level:        ${LOG_LEVEL}"
    [ -n "$LOG_FILE" ] && echo -e "  Log File:         ${LOG_FILE}"
    echo ""
}
