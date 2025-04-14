#!/bin/bash
#
# VM Management for Proxmox VM Template Wizard
# Handles VM creation, template operations, and resource allocation
#

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../core/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../storage/storage.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../network/network.sh"

# Default VM configuration
VM_NAME=""
TEMPLATE_ID=1001
VM_CPU_MODEL="host"
VM_CPU_SOCKETS=1
VM_CPU_CORES=2
VM_MEMORY=4098
VM_RESOURCE_POOL=""
VM_AGENT=1
NUMA_ENABLED=1
CLOUD_INIT_USER="user"
CLOUD_INIT_SSHKEY="${HOME}/.ssh/id_rsa.pub"
CLOUD_INIT_PASSWORD=""
CLOUD_INIT_UPGRADE=1
CLOUD_INIT_USERDATA=""
CLOUD_INIT_METADATA=""

# Configure VM resources
configure_vm_resources() {
    section_header "VM Resource Configuration"

    # CPU Model
    local cpu_models=("host" "kvm64" "qemu64" "x86-64-v2-AES" "x86-64-v3" "x86-64-v4")
    local cpu_descriptions=(
        "Host CPU (best performance, less compatibility)"
        "KVM 64-bit (good compatibility)"
        "QEMU 64-bit (best compatibility)"
        "x86-64-v2 with AES (modern CPUs, Haswell+)"
        "x86-64-v3 (newer CPUs, Broadwell+)"
        "x86-64-v4 (latest CPUs, Skylake+)"
    )

    local model_options=()
    for i in "${!cpu_models[@]}"; do
        model_options+=("${cpu_models[$i]} - ${cpu_descriptions[$i]}")
    done

    show_menu "Select CPU Model" "${model_options[@]}"
    VM_CPU_MODEL="${cpu_models[$MENU_SELECTION]}"

    # CPU Sockets
    VM_CPU_SOCKETS=$(prompt_value "Enter number of CPU sockets" "$VM_CPU_SOCKETS" "^[0-9]+$")

    # CPU Cores
    VM_CPU_CORES=$(prompt_value "Enter number of CPU cores per socket" "$VM_CPU_CORES" "^[0-9]+$")

    # Validate CPU configuration
    local total_cores=$((VM_CPU_SOCKETS * VM_CPU_CORES))
    if ! validate_vm_resources_sensible "$VM_CPU_SOCKETS" "$VM_CPU_CORES" "$VM_MEMORY"; then
        show_warning "Resource configuration may be problematic."
        if prompt_yes_no "Would you like to reconfigure VM resources?" "Y"; then
            configure_vm_resources
            return
        fi
    fi

    # Memory
    VM_MEMORY=$(prompt_value "Enter memory in MB" "$VM_MEMORY" "^[0-9]+$")

    # Advanced CPU features
    if prompt_yes_no "Configure advanced CPU features?" "N"; then
        # NUMA
        if prompt_yes_no "Enable NUMA?" "Y"; then
            NUMA_ENABLED=1
        else
            NUMA_ENABLED=0
        fi

        # CPU Flags - show popular ones
        local cpu_flags=("pcid" "spec-ctrl" "ssbd" "pdpe1gb" "aes" "avx" "avx2")
        local flag_descriptions=(
            "Process Context ID (performance feature)"
            "Spectre mitigation"
            "Speculative Store Bypass Disable"
            "1GB Pages support"
            "AES instruction set (encryption acceleration)"
            "Advanced Vector Extensions"
            "Advanced Vector Extensions 2"
        )

        local selected_flags=()
        show_info "Select CPU flags to enable:"

        for i in "${!cpu_flags[@]}"; do
            if prompt_yes_no "Enable ${cpu_flags[$i]} (${flag_descriptions[$i]})?" "N"; then
                selected_flags+=("${cpu_flags[$i]}")
            fi
        done

        if [ ${#selected_flags[@]} -gt 0 ]; then
            CPU_FLAGS=$(IFS=,; echo "${selected_flags[*]}")
            show_success "Enabled CPU flags: $CPU_FLAGS"
        fi
    fi

    # Resource pool
    if prompt_yes_no "Assign to a resource pool?" "N"; then
        VM_RESOURCE_POOL=$(prompt_value "Enter resource pool name" "$VM_RESOURCE_POOL")
    fi

    # QEMU Guest Agent
    if prompt_yes_no "Enable QEMU Guest Agent (recommended)?" "Y"; then
        VM_AGENT=1
    else
        VM_AGENT=0
    fi

    show_success "VM resources configured"

    # Validate against host
    validate_vm_resources "$VM_CPU_SOCKETS" "$VM_CPU_CORES" "$VM_MEMORY"
}

# Configure Cloud-Init settings
configure_cloud_init() {
    section_header "Cloud-Init Configuration"

    # User
    CLOUD_INIT_USER=$(prompt_value "Enter cloud-init username" "$CLOUD_INIT_USER")

    # SSH Key
    CLOUD_INIT_SSHKEY=$(prompt_value "Enter path to SSH public key" "$CLOUD_INIT_SSHKEY")

    # Check if SSH key exists
    if [ ! -f "$CLOUD_INIT_SSHKEY" ]; then
        show_warning "SSH key file does not exist: $CLOUD_INIT_SSHKEY"
        if prompt_yes_no "Would you like to generate a new SSH key?" "Y"; then
            local ssh_dir=$(dirname "$CLOUD_INIT_SSHKEY")
            mkdir -p "$ssh_dir"
            ssh-keygen -t rsa -b 4096 -f "${CLOUD_INIT_SSHKEY%.pub}" -N ""
            show_success "SSH key generated at ${CLOUD_INIT_SSHKEY%.pub} (private) and $CLOUD_INIT_SSHKEY (public)"
        else
            show_warning "Continuing with non-existent SSH key path"
        fi
    else
        # Validate SSH key
        if ! validate_ssh_key "$CLOUD_INIT_SSHKEY"; then
            show_warning "SSH key file exists but may not be a valid public key: $CLOUD_INIT_SSHKEY"
            if ! prompt_yes_no "Continue with this SSH key?" "N"; then
                configure_cloud_init
                return
            fi
        else
            show_success "SSH key validated: $CLOUD_INIT_SSHKEY"
        fi
    fi

    # Password
    if prompt_yes_no "Set a password for the cloud-init user?" "Y"; then
        while true; do
            local password=$(prompt_value "Enter password (leave empty to disable)" "")

            if [ -z "$password" ]; then
                CLOUD_INIT_PASSWORD=""
                break
            else
                # Simple password strength check
                if [ ${#password} -lt 8 ]; then
                    show_warning "Password is too short. Please use at least 8 characters."
                elif [[ ! "$password" =~ [A-Z] ]] || [[ ! "$password" =~ [a-z] ]] || [[ ! "$password" =~ [0-9] ]]; then
                    show_warning "Password is weak. It should contain uppercase, lowercase, and numbers."
                    if prompt_yes_no "Use this password anyway?" "N"; then
                        CLOUD_INIT_PASSWORD="$password"
                        break
                    fi
                else
                    CLOUD_INIT_PASSWORD="$password"
                    break
                fi
            fi
        done
    fi

    # Package upgrade on first boot
    if prompt_yes_no "Upgrade packages on first boot?" "Y"; then
        CLOUD_INIT_UPGRADE=1
    else
        CLOUD_INIT_UPGRADE=0
    fi

    # Advanced cloud-init options
    if prompt_yes_no "Configure advanced cloud-init options?" "N"; then
        # Custom user-data
        if prompt_yes_no "Provide custom user-data script?" "N"; then
            show_info "Enter custom user-data script (end with 'EOF' on a line by itself):"
            local userdata=""
            local line=""
            while read -r line; do
                [ "$line" = "EOF" ] && break
                userdata+="$line"$'\n'
            done
            CLOUD_INIT_USERDATA="$userdata"
        fi

        # Custom metadata
        if prompt_yes_no "Provide custom metadata?" "N"; then
            show_info "Enter custom metadata in YAML format (end with 'EOF' on a line by itself):"
            local metadata=""
            local line=""
            while read -r line; do
                [ "$line" = "EOF" ] && break
                metadata+="$line"$'\n'
            done
            CLOUD_INIT_METADATA="$metadata"
        fi
    fi

    show_success "Cloud-init configuration complete"
}

# Create a new VM
create_vm() {
    local vm_id="$1"
    local vm_name="$2"
    local disk_image="$3"
    local is_template="${4:-false}"

    log_info "Creating VM with ID $vm_id and name $vm_name"

    # Validate VM ID
    if ! validate_vmid "$vm_id"; then
        log_error "Invalid VM ID: $vm_id"
        return 1
    fi

    # Check for duplicate VM ID
    if ! check_duplicate_vmid "$vm_id"; then
        log_warning "VM ID $vm_id is already in use"
        if prompt_yes_no "Would you like to use the next available ID?" "Y"; then
            vm_id=$(get_next_vmid)
            log_info "Using next available VM ID: $vm_id"
        else
            log_error "Cannot create VM with duplicate ID"
            return 1
        fi
    fi

    # Validate VM name
    if ! validate_vm_name "$vm_name"; then
        log_warning "Invalid VM name: $vm_name"
        local suggested_name=$(suggest_valid_vm_name "$vm_name")
        if prompt_yes_no "Would you like to use the suggested name '$suggested_name' instead?" "Y"; then
            vm_name="$suggested_name"
        else
            log_error "Cannot create VM with invalid name"
            return 1
        fi
    fi

    # Build the base command
    local cmd="qm create $vm_id --name $vm_name --cpu $VM_CPU_MODEL --sockets $VM_CPU_SOCKETS --cores $VM_CPU_CORES --memory $VM_MEMORY --agent $VM_AGENT --ostype l26"

    # Add resource pool if specified
    [ -n "$VM_RESOURCE_POOL" ] && cmd="$cmd --pool $VM_RESOURCE_POOL"

    # Add NUMA if enabled
    [ "$NUMA_ENABLED" -eq 1 ] && cmd="$cmd --numa 1"

    # Add CPU flags if specified
    [ -n "$CPU_FLAGS" ] && cmd="$cmd --cpu-flags +$CPU_FLAGS"

    # Add network device(s)
    for (( i=0; i<$NET_INTERFACES; i++ )); do
        local net_config=$(get_net_config_string $i)
        cmd="$cmd --net$i $net_config"
    done

    # Add scsi controller
    cmd="$cmd --scsihw virtio-scsi-single"

    # Execute the base command to create the VM
    log_debug "Executing: $cmd"
    if ! eval "$cmd"; then
        log_error "Failed to create VM"
        return 1
    fi

    # Import disk if specified
    if [ -n "$disk_image" ]; then
        log_info "Importing disk image: $disk_image"
        if ! import_disk_image "$vm_id" "scsi0" "$disk_image"; then
            log_error "Failed to import disk image"
            return 1
        fi
    else
        # Create a new disk if no image specified
        log_info "Creating new disk"
        local disk_options=$(get_disk_options_string "0" "$STORAGE_POOL" "new")
        local disk_cmd="qm set $vm_id --scsi0 $disk_options"

        log_debug "Executing: $disk_cmd"
        if ! eval "$disk_cmd"; then
            log_error "Failed to create disk"
            return 1
        fi
    fi

    # Add Cloud-Init CD-ROM drive
    log_info "Adding Cloud-Init CD-ROM drive"
    local ci_cmd="qm set $vm_id --ide2 $STORAGE_POOL:cloudinit --boot order=scsi0"

    log_debug "Executing: $ci_cmd"
    if ! eval "$ci_cmd"; then
        log_error "Failed to add Cloud-Init CD-ROM drive"
        return 1
    fi

    # Configure Cloud-init network
    for (( i=0; i<$NET_INTERFACES; i++ )); do
        local ipconfig=$(get_ipconfig_string $i)
        if [ -n "$ipconfig" ]; then
            log_info "Configuring Cloud-init network for interface $i"
            local net_cmd="qm set $vm_id --ipconfig$i $ipconfig"

            if [ "$i" -eq 0 ]; then
                # Add DNS for first interface only
                net_cmd="$net_cmd --nameserver $NET_NAMESERVER --searchdomain $NET_SEARCHDOMAIN"
            fi

            log_debug "Executing: $net_cmd"
            if ! eval "$net_cmd"; then
                log_warning "Failed to configure Cloud-init network for interface $i"
            fi
        fi
    done

    # Configure Cloud-init user
    log_info "Configuring Cloud-init user"
    local user_cmd="qm set $vm_id --ciuser $CLOUD_INIT_USER --ciupgrade $CLOUD_INIT_UPGRADE"

    # Add SSH key if exists
    if [ -f "$CLOUD_INIT_SSHKEY" ]; then
        user_cmd="$user_cmd --sshkeys $CLOUD_INIT_SSHKEY"
    fi

    # Add password if set
    if [ -n "$CLOUD_INIT_PASSWORD" ]; then
        user_cmd="$user_cmd --cipassword $CLOUD_INIT_PASSWORD"
    fi

    log_debug "Executing: $user_cmd"
    if ! eval "$user_cmd"; then
        log_error "Failed to configure Cloud-init user"
        return 1
    fi

    # Add custom user-data if specified
    if [ -n "$CLOUD_INIT_USERDATA" ]; then
        log_info "Adding custom user-data"
        local userdata_file="/tmp/userdata_$vm_id.yaml"
        echo "$CLOUD_INIT_USERDATA" > "$userdata_file"

        local userdata_cmd="qm set $vm_id --cicustom user=$STORAGE_POOL:snippets/userdata_$vm_id.yaml"
        log_debug "Executing: $userdata_cmd"

        if ! pvesh create /nodes/localhost/storage/$STORAGE_POOL/content/snippets -filename "userdata_$vm_id.yaml" -content "$(cat $userdata_file)" 2>/dev/null; then
            log_error "Failed to upload user-data"
            rm -f "$userdata_file"
            return 1
        fi

        rm -f "$userdata_file"

        if ! eval "$userdata_cmd"; then
            log_error "Failed to set custom user-data"
            return 1
        fi
    fi

    # Add custom metadata if specified
    if [ -n "$CLOUD_INIT_METADATA" ]; then
        log_info "Adding custom metadata"
        local metadata_file="/tmp/metadata_$vm_id.yaml"
        echo "$CLOUD_INIT_METADATA" > "$metadata_file"

        local metadata_cmd="qm set $vm_id --cicustom meta=$STORAGE_POOL:snippets/metadata_$vm_id.yaml"
        log_debug "Executing: $metadata_cmd"

        if ! pvesh create /nodes/localhost/storage/$STORAGE_POOL/content/snippets -filename "metadata_$vm_id.yaml" -content "$(cat $metadata_file)" 2>/dev/null; then
            log_error "Failed to upload metadata"
            rm -f "$metadata_file"
            return 1
        fi

        rm -f "$metadata_file"

        if ! eval "$metadata_cmd"; then
            log_error "Failed to set custom metadata"
            return 1
        fi
    fi

    # Update Cloud-init
    log_info "Updating Cloud-init"
    if ! qm cloudinit update "$vm_id"; then
        log_error "Failed to update Cloud-init"
        return 1
    fi

    # Convert to template if requested
    if [ "$is_template" = "true" ]; then
        convert_to_template "$vm_id" "$vm_name"
    fi

    log_success "VM created successfully: ID $vm_id, Name $vm_name"
    return 0
}

# Convert a VM to a template
convert_to_template() {
    local vm_id="$1"
    local vm_name="$2"

    log_info "Converting VM $vm_id to template"

    # Rename VM to indicate it's a template
    local template_name
    if [[ "$vm_name" != *-Template ]]; then
        template_name="${vm_name}-Template"

        log_info "Renaming VM to $template_name"
        if ! qm set "$vm_id" --name "$template_name"; then
            log_error "Failed to rename VM"
            return 1
        fi
    fi

    # Convert to template
    log_info "Setting VM as template"
    if ! qm template "$vm_id"; then
        log_error "Failed to convert VM to template"
        return 1
    fi

    log_success "VM $vm_id converted to template successfully"
    return 0
}

# Create a VM from a template
create_vm_from_template() {
    local template_id="$1"
    local vm_name="$2"
    local start="${3:-true}"

    log_info "Creating VM from template $template_id with name $vm_name"

    # Get next VM ID
    local vm_id
    vm_id=$(get_next_vmid)
    log_info "Using VM ID: $vm_id"

    # Clone template
    log_info "Cloning template"
    if ! qm clone "$template_id" "$vm_id" --name "$vm_name"; then
        log_error "Failed to clone template"
        return 1
    fi

    # Apply additional customizations if needed

    # Start VM if requested
    if [ "$start" = "true" ]; then
        log_info "Starting VM"
        if ! qm start "$vm_id"; then
            log_error "Failed to start VM"
            return 1
        fi
    fi

    log_success "VM created from template successfully: ID $vm_id, Name $vm_name"

    return 0
}

# List existing templates
list_templates() {
    local templates=()
    local template_details=()
    local output

    if output=$(qm list 2>/dev/null); then
        log_debug "Searching for templates in QM list"

        # Parse output to find templates
        while read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+([^[:space:]]+)[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+) ]] && [ "${BASH_REMATCH[3]}" = "stopped" ]; then
                # Check if it's a template
                local vmid="${BASH_REMATCH[1]}"
                local config

                if config=$(qm config "$vmid" 2>/dev/null) && [[ "$config" == *"template: 1"* ]]; then
                    templates+=("$vmid")
                    template_details+=("${BASH_REMATCH[1]} - ${BASH_REMATCH[2]}")
                fi
            fi
        done < <(echo "$output" | tail -n +2)
    fi

    # Display templates if found
    if [ ${#templates[@]} -eq 0 ]; then
        show_info "No templates found."
        return 1
    else
        section_header "Available Templates"
        for detail in "${template_details[@]}"; do
            echo "  - $detail"
        done
        echo ""
        return 0
    fi
}

# Select an existing template
select_template() {
    section_header "Template Selection"

    # Get templates
    local templates=()
    local template_details=()
    local output

    if output=$(qm list 2>/dev/null); then
        # Parse output to find templates
        while read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+([^[:space:]]+)[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+) ]] && [ "${BASH_REMATCH[3]}" = "stopped" ]; then
                # Check if it's a template
                local vmid="${BASH_REMATCH[1]}"
                local config

                if config=$(qm config "$vmid" 2>/dev/null) && [[ "$config" == *"template: 1"* ]]; then
                    templates+=("$vmid")
                    template_details+=("${BASH_REMATCH[2]}")
                fi
            fi
        done < <(echo "$output" | tail -n +2)
    fi

    # Display templates if found
    if [ ${#templates[@]} -eq 0 ]; then
        show_info "No templates found."
        return 1
    else
        show_menu "Select a template" "${template_details[@]}"
        local selected_template="${templates[$MENU_SELECTION]}"
        echo "$selected_template"
        return 0
    fi
}

# Clone selected template
clone_template() {
    section_header "Clone Template to VM"

    # Select template
    local template_id
    if ! template_id=$(select_template); then
        show_warning "No templates available for cloning."
        return 1
    fi

    # VM name
    local new_vm_name
    new_vm_name=$(prompt_value "Enter name for the new VM" "")

    if [ -z "$new_vm_name" ]; then
        show_error "VM name cannot be empty."
        return 1
    fi

    # Clone
    if create_vm_from_template "$template_id" "$new_vm_name" true; then
        show_success "Template cloned successfully to VM: $new_vm_name"
        return 0
    else
        show_error "Failed to clone template."
        return 1
    fi
}

# Modify template
modify_template() {
    section_header "Modify Existing Template"

    # Select template
    local template_id
    if ! template_id=$(select_template); then
        show_warning "No templates available for modification."
        return 1
    fi

    # Get template name
    local template_name
    template_name=$(qm config "$template_id" | grep -E "^name:" | cut -d' ' -f2)

    # Options for modification
    local options=("Rename Template" "Modify Resources" "Modify Cloud-Init Settings" "Modify Network Settings")
    show_menu "Select modification type" "${options[@]}"

    case $MENU_SELECTION in
        0) # Rename
            local new_name
            new_name=$(prompt_value "Enter new name for the template" "$template_name")

            if [ -n "$new_name" ] && [ "$new_name" != "$template_name" ]; then
                if qm set "$template_id" --name "$new_name"; then
                    show_success "Template renamed to: $new_name"
                else
                    show_error "Failed to rename template."
                fi
            fi
            ;;
        1) # Resources
            # First, we need to convert it back to a VM temporarily
            if qm template "$template_id" --force 0; then
                configure_vm_resources

                # Apply changes
                local cmd="qm set $template_id --cpu $VM_CPU_MODEL --sockets $VM_CPU_SOCKETS --cores $VM_CPU_CORES --memory $VM_MEMORY --agent $VM_AGENT"
                [ "$NUMA_ENABLED" -eq 1 ] && cmd="$cmd --numa 1"
                [ -n "$CPU_FLAGS" ] && cmd="$cmd --cpu-flags +$CPU_FLAGS"

                if eval "$cmd"; then
                    show_success "Template resources updated."
                else
                    show_error "Failed to update template resources."
                fi

                # Convert back to template
                qm template "$template_id"
            else
                show_error "Failed to temporarily convert template to VM for modification."
            fi
            ;;
        2) # Cloud-Init
            # Temporarily convert to VM
            if qm template "$template_id" --force 0; then
                configure_cloud_init

                # Apply changes
                local cmd="qm set $template_id --ciuser $CLOUD_INIT_USER --ciupgrade $CLOUD_INIT_UPGRADE"
                [ -f "$CLOUD_INIT_SSHKEY" ] && cmd="$cmd --sshkeys $CLOUD_INIT_SSHKEY"
                [ -n "$CLOUD_INIT_PASSWORD" ] && cmd="$cmd --cipassword $CLOUD_INIT_PASSWORD"

                if eval "$cmd"; then
                    qm cloudinit update "$template_id"
                    show_success "Template cloud-init settings updated."
                else
                    show_error "Failed to update template cloud-init settings."
                fi

                # Convert back to template
                qm template "$template_id"
            else
                show_error "Failed to temporarily convert template to VM for modification."
            fi
            ;;
        3) # Network
            # Temporarily convert to VM
            if qm template "$template_id" --force 0; then
                configure_network

                # Apply changes for each interface
                local success=true
                for (( i=0; i<$NET_INTERFACES; i++ )); do
                    local net_config=$(get_net_config_string $i)
                    local ipconfig=$(get_ipconfig_string $i)

                    # Set network device
                    if ! qm set "$template_id" --net$i "$net_config"; then
                        show_error "Failed to update network interface $i."
                        success=false
                    fi

                    # Set IP config if not empty
                    if [ -n "$ipconfig" ]; then
                        local net_cmd="qm set $template_id --ipconfig$i $ipconfig"

                        if [ "$i" -eq 0 ]; then
                            # Add DNS for first interface only
                            net_cmd="$net_cmd --nameserver $NET_NAMESERVER --searchdomain $NET_SEARCHDOMAIN"
                        fi

                        if ! eval "$net_cmd"; then
                            show_error "Failed to update IP configuration for interface $i."
                            success=false
                        fi
                    fi
                done

                if [ "$success" = true ]; then
                    qm cloudinit update "$template_id"
                    show_success "Template network settings updated."
                fi

                # Convert back to template
                qm template "$template_id"
            else
                show_error "Failed to temporarily convert template to VM for modification."
            fi
            ;;
    esac

    return 0
}

# Delete template
delete_template() {
    section_header "Delete Template"

    # Select template
    local template_id
    if ! template_id=$(select_template); then
        show_warning "No templates available for deletion."
        return 1
    fi

    # Get template name
    local template_name
    template_name=$(qm config "$template_id" | grep -E "^name:" | cut -d' ' -f2)

    # Confirmation
    if prompt_yes_no "Are you sure you want to delete template '$template_name' (ID: $template_id)?" "N"; then
        if qm destroy "$template_id"; then
            show_success "Template deleted successfully."
            return 0
        else
            show_error "Failed to delete template."
            return 1
        fi
    else
        show_info "Template deletion cancelled."
        return 0
    fi
}

# Batch template operations
batch_template_operations() {
    section_header "Batch Template Operations"

    local options=("Create Multiple Templates" "Clone Template to Multiple VMs" "Delete Multiple Templates")
    show_menu "Select batch operation" "${options[@]}"

    case $MENU_SELECTION in
        0) # Create Multiple Templates
            create_multiple_templates
            ;;
        1) # Clone Template to Multiple VMs
            clone_template_to_multiple_vms
            ;;
        2) # Delete Multiple Templates
            delete_multiple_templates
            ;;
    esac
}

# Create multiple templates
create_multiple_templates() {
    section_header "Create Multiple Templates"

    # Get the base configuration
    show_info "Configure the base settings for all templates"

    # Configure resources, storage, and network
    configure_vm_resources
    select_storage_pool
    configure_network
    configure_cloud_init

    # Ask for distros to create templates for
    show_info "Select distributions to create templates for:"

    local distro_keys=($(get_distro_keys))
    local distro_names=()
    local selected_distros=()

    for key in "${distro_keys[@]}"; do
        distro_names+=("${DISTRO_INFO["$key,name"]}")
    done

    for i in "${!distro_names[@]}"; do
        if prompt_yes_no "Create template for ${distro_names[$i]}?" "N"; then
            selected_distros+=("${distro_keys[$i]}")
        fi
    done

    if [ ${#selected_distros[@]} -eq 0 ]; then
        show_warning "No distributions selected. Batch operation cancelled."
        return 1
    fi

    # Starting template ID
    local start_id
    start_id=$(prompt_value "Enter starting template ID" "9000" "^[0-9]+$")

    # Create templates
    local success_count=0
    local current_id=$start_id

    for distro in "${selected_distros[@]}"; do
        local distro_name="${DISTRO_INFO["$distro,name"]}"
        local template_name="${distro/[0-9]/-template}"

        show_info "Creating template for $distro_name with ID $current_id"

        # Download the distribution image if needed
        local disk_image
        if ! disk_image=$(get_disk_image_path "$distro" "$IMAGES_PATH"); then
            show_error "Failed to get disk image path for $distro"
            continue
        fi

        if [ ! -f "$disk_image" ]; then
            show_info "Downloading $distro_name cloud image..."
            if ! download_distro_image "$distro" "$IMAGES_PATH"; then
                show_error "Failed to download cloud image for $distro"
                continue
            fi
        fi

        # Create the template
        if create_vm "$current_id" "$template_name" "$disk_image" true; then
            show_success "Created template for $distro_name with ID $current_id"
            success_count=$((success_count + 1))
        else
            show_error "Failed to create template for $distro_name"
        fi

        # Increment ID for next template
        current_id=$((current_id + 1))
    done

    show_info "Batch template creation complete. Successfully created $success_count out of ${#selected_distros[@]} templates."
    return 0
}

# Clone template to multiple VMs
clone_template_to_multiple_vms() {
    section_header "Clone Template to Multiple VMs"

    # Select template
    local template_id
    if ! template_id=$(select_template); then
        show_warning "No templates available for cloning."
        return 1
    fi

    # Get template name
    local template_name
    template_name=$(qm config "$template_id" | grep -E "^name:" | cut -d' ' -f2)
    show_info "Selected template: $template_name (ID: $template_id)"

    # Number of VMs to create
    local vm_count
    vm_count=$(prompt_value "Enter number of VMs to create" "1" "^[0-9]+$")

    if [ "$vm_count" -lt 1 ]; then
        show_error "Number of VMs must be at least 1."
        return 1
    fi

    # Base VM name
    local base_name
    base_name=$(prompt_value "Enter base name for VMs" "$(echo $template_name | sed 's/-Template//')")

    # Starting VM ID
    local start_id=$(get_next_vmid)
    show_info "Starting with VM ID: $start_id"

    # Start VMs after creation?
    local start_vms=true
    if ! prompt_yes_no "Start VMs after creation?" "Y"; then
        start_vms=false
    fi

    # Create VMs
    local success_count=0
    local current_id=$start_id

    for (( i=1; i<=vm_count; i++ )); do
        local vm_name="${base_name}-${i}"

        show_info "Creating VM $i of $vm_count: $vm_name (ID: $current_id)"

        if create_vm_from_template "$template_id" "$vm_name" "$start_vms"; then
            show_success "Created VM $vm_name with ID $current_id"
            success_count=$((success_count + 1))
        else
            show_error "Failed to create VM $vm_name"
        fi

        # Increment ID for next VM
        current_id=$((current_id + 1))
    done

    show_info "Batch VM creation complete. Successfully created $success_count out of $vm_count VMs."
    return 0
}

# Delete multiple templates
delete_multiple_templates() {
    section_header "Delete Multiple Templates"

    # Get templates
    local templates=()
    local template_details=()
    local output

    if output=$(qm list 2>/dev/null); then
        # Parse output to find templates
        while read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+([^[:space:]]+)[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+) ]] && [ "${BASH_REMATCH[3]}" = "stopped" ]; then
                # Check if it's a template
                local vmid="${BASH_REMATCH[1]}"
                local config

                if config=$(qm config "$vmid" 2>/dev/null) && [[ "$config" == *"template: 1"* ]]; then
                    templates+=("$vmid")
                    template_details+=("${BASH_REMATCH[1]} - ${BASH_REMATCH[2]}")
                fi
            fi
        done < <(echo "$output" | tail -n +2)
    fi

    # Display templates if found
    if [ ${#templates[@]} -eq 0 ]; then
        show_info "No templates found for deletion."
        return 1
    fi

    # Select templates to delete
    local selected_templates=()
    local selected_names=()

    section_header "Select Templates to Delete"
    for i in "${!template_details[@]}"; do
        if prompt_yes_no "Delete ${template_details[$i]}?" "N"; then
            selected_templates+=("${templates[$i]}")
            selected_names+=("${template_details[$i]}")
        fi
    done

    if [ ${#selected_templates[@]} -eq 0 ]; then
        show_warning "No templates selected for deletion."
        return 1
    fi

    # Confirmation
    section_header "Confirm Template Deletion"
    echo "The following templates will be deleted:"
    for name in "${selected_names[@]}"; do
        echo "  - $name"
    done
    echo ""

    if ! prompt_yes_no "Are you sure you want to delete these templates? This action cannot be undone." "N"; then
        show_info "Template deletion cancelled."
        return 0
    fi

    # Delete templates
    local success_count=0

    for template_id in "${selected_templates[@]}"; do
        show_info "Deleting template ID $template_id..."

        if qm destroy "$template_id"; then
            show_success "Deleted template ID $template_id"
            success_count=$((success_count + 1))
        else
            show_error "Failed to delete template ID $template_id"
        fi
    done

    show_info "Batch template deletion complete. Successfully deleted $success_count out of ${#selected_templates[@]} templates."
    return 0
}
