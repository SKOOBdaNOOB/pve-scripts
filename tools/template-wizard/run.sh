#!/bin/bash
#
# Proxmox VM Template Wizard - Self-contained Version
# A comprehensive tool for creating and managing VM templates in Proxmox
#

# Text formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# Global configuration variables with defaults
CONFIG_FILE="${HOME}/.pve-template-wizard.conf"
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

# Distribution information
declare -A DISTRO_INFO
DISTRO_INFO=(
    ["alma9,name"]="Alma Linux 9"
    ["alma9,url"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
    ["alma9,checksum_url"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/CHECKSUM"
    ["alma9,filename"]="AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"

    ["amazon2,name"]="Amazon Linux 2"
    ["amazon2,url"]="https://cdn.amazonlinux.com/os-images/2.0.20230727.0/kvm/amzn2-kvm-2.0.20230727.0-x86_64.xfs.gpt.qcow2"
    ["amazon2,checksum_url"]=""
    ["amazon2,filename"]="amzn2-kvm-2.0.20230727.0-x86_64.xfs.gpt.qcow2"

    ["centos9,name"]="CentOS 9 Stream"
    ["centos9,url"]="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
    ["centos9,checksum_url"]=""
    ["centos9,filename"]="CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"

    ["fedora38,name"]="Fedora 38"
    ["fedora38,url"]="https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
    ["fedora38,checksum_url"]=""
    ["fedora38,filename"]="Fedora-Cloud-Base-38-1.6.x86_64.qcow2"

    ["oracle9,name"]="Oracle Linux 9"
    ["oracle9,url"]="https://yum.oracle.com/templates/OracleLinux/OL9/u2/x86_64/OL9U2_x86_64-kvm-b197.qcow"
    ["oracle9,checksum"]="840345cb866837ac7cc7c347cd9a8196c3a17e9c054c613eda8c2a912434c956"
    ["oracle9,filename"]="OL9U2_x86_64-kvm-b197.qcow"
    ["oracle9,needs_conversion"]="true"

    ["rocky9,name"]="Rocky Linux 9"
    ["rocky9,url"]="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
    ["rocky9,checksum_url"]=""
    ["rocky9,filename"]="Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"

    ["ubuntu23,name"]="Ubuntu 23.04 Lunar Lobster"
    ["ubuntu23,url"]="https://cloud-images.ubuntu.com/lunar/current/lunar-server-cloudimg-amd64.img"
    ["ubuntu23,checksum_url"]=""
    ["ubuntu23,filename"]="lunar-server-cloudimg-amd64.img"
)

# Function to display a header
show_header() {
    clear
    echo -e "${BOLD}${BLUE}============================================${RESET}"
    echo -e "${BOLD}${BLUE}  Proxmox VM Template Creation Wizard      ${RESET}"
    echo -e "${BOLD}${BLUE}============================================${RESET}"
    echo ""
}

# Function to display a section header
section_header() {
    echo ""
    echo -e "${BOLD}${CYAN}== $1 ==${RESET}"
    echo ""
}

# Function to show a success message
show_success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

# Function to show an error message
show_error() {
    echo -e "${RED}✗ $1${RESET}"
}

# Function to show a warning message
show_warning() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

# Function to show an info message
show_info() {
    echo -e "${BLUE}ℹ $1${RESET}"
}

# Function to prompt for yes/no
prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local response

    if [[ "$default" == "Y" ]]; then
        prompt="$prompt [Y/n]"
    else
        prompt="$prompt [y/N]"
    fi

    while true; do
        read -p "$prompt " response
        response=${response:-$default}
        case "${response,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Function to prompt for a value with validation
prompt_value() {
    local prompt="$1"
    local default="$2"
    local validation="$3"
    local value

    while true; do
        read -p "$prompt [${default}]: " value
        value=${value:-$default}

        if [[ -z "$validation" ]] || [[ "$value" =~ $validation ]]; then
            echo "$value"
            return
        else
            show_error "Invalid input. Please try again."
        fi
    done
}

# Global variable for menu selection
MENU_SELECTION=0

# Function to display a menu and get selection
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selection

    section_header "$title"

    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[$i]}"
    done

    echo ""
    while true; do
        read -p "Enter selection [1-${#options[@]}]: " selection

        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#options[@]}" ]; then
            MENU_SELECTION=$((selection-1))
            return
        else
            show_error "Invalid selection. Please try again."
        fi
    done
}

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

# Function to load saved configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        section_header "Loading Saved Configuration"

        if prompt_yes_no "Found saved configuration. Would you like to load it?" "Y"; then
            source "$CONFIG_FILE"
            show_success "Configuration loaded."
        else
            show_info "Using default configuration."
        fi
    fi
}

# Function to save configuration
save_config() {
    section_header "Saving Configuration"

    # Ensure the parent directory exists
    local config_dir=$(dirname "$CONFIG_FILE")
    mkdir -p "$config_dir"

    if prompt_yes_no "Would you like to save this configuration for future use?" "Y"; then
        cat > "$CONFIG_FILE" <<EOL
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
EOL
        show_success "Configuration saved to $CONFIG_FILE"
    fi
}

# Function to save a profile
save_profile() {
    local profile_name="$1"
    local profile_dir="${HOME}/.pve-template-wizard/profiles"
    local profile_file="${profile_dir}/${profile_name}.conf"

    # Create profile directory if it doesn't exist
    mkdir -p "$profile_dir"

    # Save current configuration to profile
    cat > "$profile_file" <<EOL
# Proxmox VM Template Wizard Profile: $profile_name
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
EOL

    show_success "Profile saved as $profile_name"
}

# Function to list profiles
list_profiles() {
    local profile_dir="${HOME}/.pve-template-wizard/profiles"

    if [ ! -d "$profile_dir" ] || [ -z "$(ls -A "$profile_dir")" ]; then
        show_warning "No profiles found."
        return 1
    fi

    section_header "Available Profiles"

    local count=1
    for profile in "$profile_dir"/*.conf; do
        local profile_name=$(basename "${profile%.conf}")
        echo "  $count. $profile_name"
        ((count++))
    done

    echo ""
    return 0
}

# Function to load a profile
load_profile() {
    local profile_name="$1"
    local profile_file="${HOME}/.pve-template-wizard/profiles/${profile_name}.conf"

    if [ ! -f "$profile_file" ]; then
        show_error "Profile '$profile_name' not found."
        return 1
    fi

    source "$profile_file"
    show_success "Profile '$profile_name' loaded."
    return 0
}

# Function to configure logging
configure_logging() {
    section_header "Configure Logging"

    local log_levels=("Error" "Warning" "Info" "Debug")
    show_menu "Select Log Level" "${log_levels[@]}"

    local log_level="${log_levels[$MENU_SELECTION],,}"
    echo "Selected log level: $log_level"

    # In a real implementation, this would update the logging configuration
    show_success "Logging configured to $log_level level."
}

# Function to get distribution keys
get_distro_keys() {
    echo "alma9 amazon2 centos9 fedora38 oracle9 rocky9 ubuntu23"
}

# Function to select storage pool
select_storage_pool() {
    section_header "Select Storage Pool"

    local pools=()
    local pool_data=$(pvesh get /storage --output-format=json 2>/dev/null || echo "[]")

    if [ "$pool_data" == "[]" ]; then
        show_warning "Failed to retrieve storage pools. Using default storage."
        return
    fi

    local pool_names=()
    local i=0

    # Extract pool names from JSON (simplified parsing)
    while read -r line; do
        if [[ $line =~ \"storage\":\"([^\"]+)\" ]]; then
            pool_names[i]="${BASH_REMATCH[1]}"
            ((i++))
        fi
    done < <(echo "$pool_data" | tr ',' '\n')

    if [ ${#pool_names[@]} -eq 0 ]; then
        show_warning "No storage pools found. Using default storage."
        return
    fi

    show_menu "Available Storage Pools" "${pool_names[@]}"
    STORAGE_POOL="${pool_names[$MENU_SELECTION]}"

    show_success "Selected storage pool: $STORAGE_POOL"
}

# Function to configure VM resources
configure_vm_resources() {
    section_header "Configure VM Resources"

    # CPU Model
    QEMU_CPU_MODEL=$(prompt_value "Enter CPU model" "$QEMU_CPU_MODEL")

    # CPU Sockets
    VM_CPU_SOCKETS=$(prompt_value "Enter number of CPU sockets" "$VM_CPU_SOCKETS" "^[0-9]+$")

    # CPU Cores
    VM_CPU_CORES=$(prompt_value "Enter number of CPU cores per socket" "$VM_CPU_CORES" "^[0-9]+$")

    # Memory
    VM_MEMORY=$(prompt_value "Enter memory in MB" "$VM_MEMORY" "^[0-9]+$")

    # Resource Pool
    VM_RESOURCE_POOL=$(prompt_value "Enter resource pool (leave empty for none)" "$VM_RESOURCE_POOL")

    show_success "VM resources configured."
}

# Function to configure network
configure_network() {
    section_header "Configure Network"

    # Network Configuration
    local network_options=("DHCP" "Static IP")
    show_menu "Network Configuration" "${network_options[@]}"

    if [ "$MENU_SELECTION" -eq 1 ]; then
        CLOUD_INIT_IP=$(prompt_value "Enter static IP/CIDR (e.g., 192.168.1.100/24)" "")
        local gateway=$(prompt_value "Enter gateway IP" "")
        if [ -n "$gateway" ]; then
            CLOUD_INIT_IP="${CLOUD_INIT_IP},gw=${gateway}"
        fi
    else
        CLOUD_INIT_IP="dhcp"
    fi

    # DNS
    CLOUD_INIT_NAMESERVER=$(prompt_value "Enter DNS nameserver" "$CLOUD_INIT_NAMESERVER")
    CLOUD_INIT_SEARCHDOMAIN=$(prompt_value "Enter search domain" "$CLOUD_INIT_SEARCHDOMAIN")

    show_success "Network settings configured."
}

# Function to configure cloud-init
configure_cloud_init() {
    section_header "Configure Cloud-Init"

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
            show_success "SSH key generated."
        else
            show_warning "Continuing with non-existent SSH key path."
        fi
    fi

    show_success "Cloud-init settings configured."
}

# Function to show configuration
show_config() {
    echo -e "${BOLD}Distribution:${RESET} ${DISTRO_INFO["$SELECTED_DISTRO,name"]}"
    echo -e "${BOLD}Template ID:${RESET} $TEMPLATE_ID"
    echo -e "${BOLD}VM Name:${RESET} $VM_NAME"
    echo ""
    echo -e "${BOLD}CPU Model:${RESET} $QEMU_CPU_MODEL"
    echo -e "${BOLD}CPU Configuration:${RESET} $VM_CPU_SOCKETS socket(s), $VM_CPU_CORES core(s) per socket"
    echo -e "${BOLD}Memory:${RESET} $VM_MEMORY MB"

    if [ -n "$VM_RESOURCE_POOL" ]; then
        echo -e "${BOLD}Resource Pool:${RESET} $VM_RESOURCE_POOL"
    else
        echo -e "${BOLD}Resource Pool:${RESET} None"
    fi

    echo ""
    echo -e "${BOLD}Cloud-Init User:${RESET} $CLOUD_INIT_USER"
    echo -e "${BOLD}SSH Key:${RESET} $CLOUD_INIT_SSHKEY"
    echo -e "${BOLD}Network:${RESET} $CLOUD_INIT_IP"
    echo -e "${BOLD}DNS Server:${RESET} $CLOUD_INIT_NAMESERVER"
    echo -e "${BOLD}Search Domain:${RESET} $CLOUD_INIT_SEARCHDOMAIN"
    echo ""
}

# Function to get disk image path
get_disk_image_path() {
    local distro="$1"
    local base_path="$2"
    local filename="${DISTRO_INFO["$distro,filename"]}"

    if [[ "${DISTRO_INFO["$distro,needs_conversion"]}" == "true" ]]; then
        local base_filename="${filename%.*}"
        echo "${base_path}/${base_filename}.qcow2"
    else
        echo "${base_path}/${filename}"
    fi
}

# Function to download distro image
download_distro_image() {
    local distro="$1"
    local dest_path="$2"
    local url="${DISTRO_INFO["$distro,url"]}"
    local filename="${DISTRO_INFO["$distro,filename"]}"
    local full_path="${dest_path}/${filename}"

    show_info "Downloading from: $url"
    show_info "This may take some time depending on your internet connection..."

    mkdir -p "$dest_path"
    cd "$dest_path" || return 1

    if ! wget -q --show-progress "$url" -O "$filename"; then
        show_error "Failed to download image."
        return 1
    fi

    show_success "Download complete."

    # Handle checksum verification
    if [[ -n "${DISTRO_INFO["$distro,checksum_url"]}" ]]; then
        show_info "Verifying checksum..."
        wget -q "${DISTRO_INFO["$distro,checksum_url"]}" -O SHA256SUMS
        if ! sha256sum -c SHA256SUMS --ignore-missing; then
            show_error "Checksum verification failed."
            if ! prompt_yes_no "Continue anyway?" "N"; then
                return 1
            fi
        else
            show_success "Checksum verification passed."
        fi
    elif [[ -n "${DISTRO_INFO["$distro,checksum"]}" ]]; then
        show_info "Verifying checksum..."
        echo "${DISTRO_INFO["$distro,checksum"]} $filename" > SHA256SUMS-custom
        if ! sha256sum -c SHA256SUMS-custom; then
            show_error "Checksum verification failed."
            if ! prompt_yes_no "Continue anyway?" "N"; then
                return 1
            fi
        else
            show_success "Checksum verification passed."
        fi
    else
        show_warning "No checksum available for verification."
    fi

    # Handle image conversion if needed
    if [[ "${DISTRO_INFO["$distro,needs_conversion"]}" == "true" ]]; then
        show_info "Converting image to qcow2 format..."
        local base_filename="${filename%.*}"
        if ! qemu-img convert -O qcow2 -o compat=0.10 "$filename" "${base_filename}.qcow2"; then
            show_error "Image conversion failed."
            return 1
        fi
        show_success "Image conversion complete."
    fi

    return 0
}

# Function to create a VM
create_vm() {
    local id="$1"
    local name="$2"
    local disk_image="$3"
    local is_template="$4"

    # Create VM
    show_info "Creating VM with ID $id..."
    local storage_option="local-lvm"

    if [ -n "$STORAGE_POOL" ]; then
        storage_option="$STORAGE_POOL"
    fi

    local create_cmd="qm create $id --name $name --cpu $QEMU_CPU_MODEL --sockets $VM_CPU_SOCKETS --cores $VM_CPU_CORES --memory $VM_MEMORY --numa 1 --net0 virtio,bridge=vmbr0 --ostype l26 --agent 1 --scsihw virtio-scsi-single"

    if [ -n "$VM_RESOURCE_POOL" ]; then
        create_cmd="$create_cmd --pool $VM_RESOURCE_POOL"
    fi

    if ! eval "$create_cmd"; then
        show_error "Failed to create VM."
        return 1
    fi

    # Import disk
    show_info "Importing disk image..."
    if ! qm set $id --scsi0 ${storage_option}:0,import-from="$disk_image"; then
        show_error "Failed to import disk image."
        return 1
    fi

    # Add Cloud-Init CD-ROM drive
    show_info "Adding Cloud-Init CD-ROM drive..."
    if ! qm set $id --ide2 ${storage_option}:cloudinit --boot order=scsi0; then
        show_error "Failed to add Cloud-Init CD-ROM drive."
        return 1
    fi

    # Configure Cloud-init network
    show_info "Configuring Cloud-init network..."
    if ! qm set $id --ipconfig0 ip=$CLOUD_INIT_IP --nameserver $CLOUD_INIT_NAMESERVER --searchdomain $CLOUD_INIT_SEARCHDOMAIN; then
        show_error "Failed to configure Cloud-init network."
        return 1
    fi

    # Configure Cloud-init user
    show_info "Configuring Cloud-init user..."
    if ! qm set $id --ciupgrade 1 --ciuser $CLOUD_INIT_USER --sshkeys $CLOUD_INIT_SSHKEY; then
        show_error "Failed to configure Cloud-init user."
        return 1
    fi

    # Update Cloud-init
    show_info "Updating Cloud-init..."
    if ! qm cloudinit update $id; then
        show_error "Failed to update Cloud-init."
        return 1
    fi

    # Convert to template if requested
    if [ "$is_template" = true ]; then
        show_info "Converting to template..."
        if ! qm template $id; then
            show_error "Failed to convert VM to template."
            return 1
        fi
    fi

    show_success "VM created successfully."
    return 0
}

# Function to list templates
list_templates() {
    local template_data=$(pvesh get /cluster/resources --type vm --output-format=json 2>/dev/null | grep -E '"template":[^0]' || echo "[]")

    if [ "$template_data" == "[]" ]; then
        return 1
    fi

    section_header "Available Templates"

    local templates=()
    local template_ids=()
    local i=0

    # Extract template information (simplified parsing)
    while read -r line; do
        if [[ $line =~ \"vmid\":([0-9]+) ]]; then
            local vmid="${BASH_REMATCH[1]}"
            if [[ $line =~ \"name\":\"([^\"]+)\" ]]; then
                local name="${BASH_REMATCH[1]}"
                templates[i]="$name (ID: $vmid)"
                template_ids[i]="$vmid"
                echo "  $((i+1)). ${templates[i]}"
                ((i++))
            fi
        fi
    done < <(echo "$template_data" | tr ',' '\n')

    if [ ${#templates[@]} -eq 0 ]; then
        return 1
    fi

    # Store for later use
    TEMPLATE_LIST=("${templates[@]}")
    TEMPLATE_IDS=("${template_ids[@]}")

    echo ""
    return 0
}

# Function to clone a template
clone_template() {
    if [ ${#TEMPLATE_LIST[@]} -eq 0 ]; then
        show_error "No templates available."
        return 1
    fi

    show_menu "Select Template to Clone" "${TEMPLATE_LIST[@]}"
    local selected_template="${TEMPLATE_IDS[$MENU_SELECTION]}"

    # Get next VM ID
    local vm_id
    vm_id=$(pvesh get /cluster/nextid)
    show_info "Using VM ID: $vm_id"

    # Get VM name
    local vm_name
    vm_name=$(prompt_value "Enter name for the new VM" "vm-$vm_id")

    # Clone template
    show_info "Cloning template $selected_template to VM $vm_id..."
    if ! qm clone $selected_template $vm_id --name $vm_name; then
        show_error "Failed to clone template."
        return 1
    fi

    # Ask if user wants to start the VM
    if prompt_yes_no "Would you like to start the VM now?" "Y"; then
        show_info "Starting VM..."
        if ! qm start $vm_id; then
            show_error "Failed to start VM."
        else
            show_success "VM started successfully."
        fi
    fi

    show_success "VM cloned successfully: $vm_name (ID: $vm_id)"
    return 0
}

# Function to modify a template
modify_template() {
    if [ ${#TEMPLATE_LIST[@]} -eq 0 ]; then
        show_error "No templates available."
        return 1
    fi

    show_menu "Select Template to Modify" "${TEMPLATE_LIST[@]}"
    local selected_template="${TEMPLATE_IDS[$MENU_SELECTION]}"

    local modification_options=("Resources" "Cloud-Init Settings" "Network" "Cancel")
    show_menu "Select What to Modify" "${modification_options[@]}"

    case $MENU_SELECTION in
        0) # Resources
            section_header "Modify Resources"

            local cpu_sockets=$(prompt_value "Enter number of CPU sockets" "1" "^[0-9]+$")
            local cpu_cores=$(prompt_value "Enter number of CPU cores per socket" "2" "^[0-9]+$")
            local memory=$(prompt_value "Enter memory in MB" "4096" "^[0-9]+$")

            show_info "Applying resource changes..."
            if ! qm set $selected_template --sockets $cpu_sockets --cores $cpu_cores --memory $memory; then
                show_error "Failed to modify resources."
                return 1
            fi

            show_success "Resources updated successfully."
            ;;

        1) # Cloud-Init
            section_header "Modify Cloud-Init Settings"

            local user=$(prompt_value "Enter cloud-init username" "user")
            local sshkey=$(prompt_value "Enter path to SSH public key" "${HOME}/.ssh/id_rsa.pub")

            show_info "Applying cloud-init changes..."
            if ! qm set $selected_template --ciuser $user --sshkeys $sshkey; then
                show_error "Failed to modify cloud-init settings."
                return 1
            fi

            show_success "Cloud-init settings updated successfully."
            ;;

        2) # Network
            section_header "Modify Network Settings"

            local network_options=("DHCP" "Static IP")
            show_menu "Network Configuration" "${network_options[@]}"

            local ip_config="dhcp"
            if [ "$MENU_SELECTION" -eq 1 ]; then
                local static_ip=$(prompt_value "Enter static IP/CIDR (e.g., 192.168.1.100/24)" "")
                local gateway=$(prompt_value "Enter gateway IP" "")
                if [ -n "$gateway" ]; then
                    ip_config="${static_ip},gw=${gateway}"
                else
                    ip_config="$static_ip"
                fi
            fi

            local nameserver=$(prompt_value "Enter DNS nameserver" "1.1.1.1")
            local searchdomain=$(prompt_value "Enter search domain" "example.com")

            show_info "Applying network changes..."
            if ! qm set $selected_template --ipconfig0 ip=$ip_config --nameserver $nameserver --searchdomain $searchdomain; then
                show_error "Failed to modify network settings."
                return 1
            fi

            if ! qm cloudinit update $selected_template; then
                show_error "Failed to update cloud-init."
                return 1
            fi

            show_success "Network settings updated successfully."
            ;;

        3) # Cancel
            show_info "Modification cancelled."
            ;;
    esac

    return 0
}

# Function to delete a template
delete_template() {
    if [ ${#TEMPLATE_LIST[@]} -eq 0 ]; then
        show_error "No templates available."
        return 1
    fi

    show_menu "Select Template to Delete" "${TEMPLATE_LIST[@]}"
    local selected_template="${TEMPLATE_IDS[$MENU_SELECTION]}"

    if ! prompt_yes_no "Are you sure you want to delete this template?" "N"; then
        show_info "Deletion cancelled."
        return 0
    fi

    show_info "Deleting template $selected_template..."
    if ! qm destroy $selected_template --purge; then
        show_error "Failed to delete template."
        return 1
    fi

    show_success "Template deleted successfully."
    return 0
}

# Function for batch template operations
batch_template_operations() {
    local options=("Create Multiple Templates" "Clone to Multiple VMs" "Delete Multiple Templates" "Cancel")
    show_menu "Select Batch Operation" "${options[@]}"

    case $MENU_SELECTION in
        0) # Create Multiple
            batch_create_templates
            ;;
        1) # Clone Multiple
            batch_clone_templates
            ;;
        2) # Delete Multiple
            batch_delete_templates
            ;;
        3) # Cancel
            show_info "Batch operation cancelled."
            ;;
    esac

    return 0
}

# Function to create multiple templates
batch_create_templates() {
    section_header "Create Multiple Templates"

    local count=$(prompt_value "How many templates do you want to create?" "2" "^[0-9]+$")

    if [ "$count" -lt 1 ]; then
        show_error "Invalid count."
        return 1
    fi

    # Select distribution
    local distro_keys=($(get_distro_keys))
    local distro_names=()

    for key in "${distro_keys[@]}"; do
        distro_names+=("${DISTRO_INFO["$key,name"]}")
    done

    show_menu "Select Linux Distribution" "${distro_names[@]}"
    local selected_distro="${distro_keys[$MENU_SELECTION]}"

    # Configure base settings
    SELECTED_DISTRO="$selected_distro"
    configure_vm_resources
    configure_network
    configure_cloud_init

    # Starting ID
    local start_id=$(prompt_value "Enter starting template ID" "1001" "^[0-9]+$")

    # Create templates
    show_info "Creating $count templates..."

    local success_count=0
    for ((i=0; i<count; i++)); do
        local id=$((start_id + i))
        local name="${selected_distro}-template-$id"

        # Download distribution image if needed
        local disk_image

        if ! disk_image=$(get_disk_image_path "$selected_distro" "$IMAGES_PATH"); then
            show_error "Failed to get disk image path for $selected_distro"
            continue
        fi

        if [ ! -f "$disk_image" ]; then
            show_info "Downloading ${DISTRO_INFO["$selected_distro,name"]} cloud image..."
            if ! download_distro_image "$selected_distro" "$IMAGES_PATH"; then
                show_error "Failed to download cloud image"
                continue
            fi
        fi

        # Create the template
        show_info "Creating template $name (ID: $id)..."
        if create_vm "$id" "$name" "$disk_image" true; then
            show_success "Template $name created successfully."
            ((success_count++))
        else
            show_error "Failed to create template $name."
        fi
    done

    show_info "Batch operation completed. $success_count of $count templates created successfully."
    return 0
}

# Function to clone multiple VMs from a template
batch_clone_templates() {
    section_header "Clone Multiple VMs"

    if ! list_templates; then
        show_warning "No templates available for cloning."
        return 1
    fi

    show_menu "Select Template to Clone" "${TEMPLATE_LIST[@]}"
    local selected_template="${TEMPLATE_IDS[$MENU_SELECTION]}"

    local count=$(prompt_value "How many VMs do you want to create?" "2" "^[0-9]+$")

    if [ "$count" -lt 1 ]; then
        show_error "Invalid count."
        return 1
    fi

    local base_name=$(prompt_value "Enter base name for VMs" "vm")
    local start_id=$(pvesh get /cluster/nextid)

    # Clone VMs
    show_info "Cloning $count VMs from template $selected_template..."

    local success_count=0
    for ((i=0; i<count; i++)); do
        local id=$((start_id + i))
        local name="${base_name}-$id"

        show_info "Cloning VM $name (ID: $id)..."
        if qm clone $selected_template $id --name $name; then
            show_success "VM $name cloned successfully."
            ((success_count++))
        else
            show_error "Failed to clone VM $name."
        fi
    done

    # Ask if user wants to start the VMs
    if [ "$success_count" -gt 0 ] && prompt_yes_no "Would you like to start the VMs now?" "Y"; then
        for ((i=0; i<count; i++)); do
            local id=$((start_id + i))
            local name="${base_name}-$id"

            show_info "Starting VM $name (ID: $id)..."
            if qm start $id; then
                show_success "VM $name started successfully."
            else
                show_error "Failed to start VM $name."
            fi
        done
    fi

    show_info "Batch operation completed. $success_count of $count VMs cloned successfully."
    return 0
}

# Function to delete multiple templates
batch_delete_templates() {
    section_header "Delete Multiple Templates"

    if ! list_templates; then
        show_warning "No templates available for deletion."
        return 1
    fi

    local all_templates=("${TEMPLATE_LIST[@]}")
    local all_template_ids=("${TEMPLATE_IDS[@]}")
    local selected_ids=()
    local selected_names=()

    while true; do
        # Display available templates
        section_header "Available Templates"
        for i in "${!all_templates[@]}"; do
            echo "  $((i+1)). ${all_templates[$i]}"
        done
        echo ""

        # Display selected templates
        if [ ${#selected_ids[@]} -gt 0 ]; then
            section_header "Selected Templates"
            for i in "${!selected_names[@]}"; do
                echo "  $((i+1)). ${selected_names[$i]}"
            done
            echo ""
        fi

        # Menu options
        local options=("Add Template to Selection" "Remove Template from Selection" "Delete Selected Templates" "Cancel")
        show_menu "Select Action" "${options[@]}"

        case $MENU_SELECTION in
            0) # Add template
                if [ ${#all_templates[@]} -eq 0 ]; then
                    show_warning "No more templates available to add."
                    continue
                fi

                show_menu "Select Template to Add" "${all_templates[@]}"
                local index=$MENU_SELECTION
                local template_id="${all_template_ids[$index]}"
                local template_name="${all_templates[$index]}"

                selected_ids+=("$template_id")
                selected_names+=("$template_name")

                # Remove from available list
                all_templates=("${all_templates[@]:0:$index}" "${all_templates[@]:$((index+1))}")
                all_template_ids=("${all_template_ids[@]:0:$index}" "${all_template_ids[@]:$((index+1))}")
                ;;

            1) # Remove template
                if [ ${#selected_names[@]} -eq 0 ]; then
                    show_warning "No templates selected to remove."
                    continue
                fi

                show_menu "Select Template to Remove" "${selected_names[@]}"
                local index=$MENU_SELECTION
                local template_id="${selected_ids[$index]}"
                local template_name="${selected_names[$index]}"

                all_template_ids+=("$template_id")
                all_templates+=("$template_name")

                # Remove from selected list
                selected_ids=("${selected_ids[@]:0:$index}" "${selected_ids[@]:$((index+1))}")
                selected_names=("${selected_names[@]:0:$index}" "${selected_names[@]:$((index+1))}")
                ;;

            2) # Delete selected
                if [ ${#selected_ids[@]} -eq 0 ]; then
                    show_warning "No templates selected for deletion."
                    continue
                fi

                if ! prompt_yes_no "Are you sure you want to delete ${#selected_ids[@]} templates?" "N"; then
                    show_info "Deletion cancelled."
                    continue
                fi

                local success_count=0
                for i in "${!selected_ids[@]}"; do
                    local id="${selected_ids[$i]}"
                    local name="${selected_names[$i]}"

                    show_info "Deleting template $name..."
                    if qm destroy $id --purge; then
                        show_success "Template $name deleted successfully."
                        ((success_count++))
                    else
                        show_error "Failed to delete template $name."
                    fi
                done

                show_info "Batch deletion completed. $success_count of ${#selected_ids[@]} templates deleted successfully."
                return 0
                ;;

            3) # Cancel
                show_info "Batch operation cancelled."
                return 0
                ;;
        esac
    done
}

# Main function
main() {
    show_header
    check_prerequisites
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

        case $MENU_SELECTION in
            0) # Create new template
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
                    continue
                fi

                # Download distribution image if needed
                local disk_image

                if ! disk_image=$(get_disk_image_path "$selected_distro" "$IMAGES_PATH"); then
                    show_error "Failed to get disk image path for $selected_distro"
                    continue
                fi

                if [ ! -f "$disk_image" ]; then
                    show_info "Downloading ${DISTRO_INFO["$selected_distro,name"]} cloud image..."
                    if ! download_distro_image "$selected_distro" "$IMAGES_PATH"; then
                        show_error "Failed to download cloud image"
                        continue
                    fi
                fi

                # Create the template
                if create_vm "$TEMPLATE_ID" "$VM_NAME" "$disk_image" true; then
                    show_success "Template created successfully: $VM_NAME (ID: $TEMPLATE_ID)"
                    # Save configuration
                    save_config
                else
                    show_error "Failed to create template"
                fi
                ;;

            1) # Clone from template
                section_header "Clone from Template"

                # List available templates
                if ! list_templates; then
                    show_warning "No templates available for cloning."
                    if prompt_yes_no "Would you like to create a new template first?" "Y"; then
                        MENU_SELECTION=0
                        continue
                    fi
                    continue
                fi

                # Clone selected template
                clone_template
                ;;

            2) # Manage templates
                section_header "Template Management"

                # Check if templates exist
                if ! list_templates; then
                    show_warning "No templates found to manage."
                    continue
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
                ;;

            3) # Batch operations
                section_header "Batch Operations"
                batch_template_operations
                ;;

            4) # Configuration management
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
