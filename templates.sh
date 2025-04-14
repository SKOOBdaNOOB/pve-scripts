#!/bin/bash
#
# Proxmox VM Template Creation Wizard
# This script guides you through creating VM templates in Proxmox using cloud images
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
CONFIG_FILE=".pve-template-wizard.conf"
IMAGES_PATH="/cloud-init/"
QEMU_CPU_MODEL="host"
VM_CPU_SOCKETS=1
VM_CPU_CORES=2
VM_MEMORY=4098
VM_RESOURCE_POOL=""
CLOUD_INIT_USER="user"
CLOUD_INIT_SSHKEY="/home/user/.ssh/id_rsa.pub"
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

    echo ""
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

# Function to select Linux distribution
select_distribution() {
    section_header "Select Linux Distribution"

    local distro_keys=("alma9" "amazon2" "centos9" "fedora38" "oracle9" "rocky9" "ubuntu23")
    local distro_names=()

    for key in "${distro_keys[@]}"; do
        distro_names+=("${DISTRO_INFO["$key,name"]}")
    done

    show_menu "Available Linux Distributions" "${distro_names[@]}"
    SELECTED_DISTRO="${distro_keys[$MENU_SELECTION]}"
    VM_NAME="${SELECTED_DISTRO}"

    show_success "Selected: ${DISTRO_INFO["$SELECTED_DISTRO,name"]}"

    # Set the VM disk image path
    local filename="${DISTRO_INFO["$SELECTED_DISTRO,filename"]}"
    VM_DISK_IMAGE="${IMAGES_PATH}/${filename}"

    if [[ "${DISTRO_INFO["$SELECTED_DISTRO,needs_conversion"]}" == "true" ]]; then
        show_info "Note: This image will need conversion to qcow2 format."
    fi
}

# Function to configure image path and download
configure_images() {
    section_header "Configure Image Path and Download"

    # Prompt for images path
    IMAGES_PATH=$(prompt_value "Enter path to store cloud images" "$IMAGES_PATH")

    # Create directory if it doesn't exist
    if [ ! -d "$IMAGES_PATH" ]; then
        if prompt_yes_no "Directory $IMAGES_PATH does not exist. Create it?" "Y"; then
            mkdir -p "$IMAGES_PATH"
            show_success "Created directory: $IMAGES_PATH"
        else
            show_error "Cannot proceed without a valid directory."
            configure_images
            return
        fi
    fi

    # Check if image already exists
    local filename="${DISTRO_INFO["$SELECTED_DISTRO,filename"]}"
    local full_path="${IMAGES_PATH}/${filename}"

    if [ -f "$full_path" ]; then
        show_info "Image file already exists: $full_path"
        if ! prompt_yes_no "Would you like to download it again?" "N"; then
            return
        fi
    fi

    # Download the image
    if prompt_yes_no "Download ${DISTRO_INFO["$SELECTED_DISTRO,name"]} cloud image?" "Y"; then
        section_header "Downloading Cloud Image"

        cd "$IMAGES_PATH" || {
            show_error "Failed to change to directory: $IMAGES_PATH"
            return
        }

        local url="${DISTRO_INFO["$SELECTED_DISTRO,url"]}"
        show_info "Downloading from: $url"
        show_info "This may take some time depending on your internet connection..."

        if ! wget -q --show-progress "$url"; then
            show_error "Failed to download image."
            return
        fi

        show_success "Download complete."

        # Handle checksum verification
        if [[ -n "${DISTRO_INFO["$SELECTED_DISTRO,checksum_url"]}" ]]; then
            show_info "Verifying checksum..."
            wget -q "${DISTRO_INFO["$SELECTED_DISTRO,checksum_url"]}" -O SHA256SUMS
            if ! sha256sum -c SHA256SUMS --ignore-missing; then
                show_error "Checksum verification failed."
                if ! prompt_yes_no "Continue anyway?" "N"; then
                    return
                fi
            else
                show_success "Checksum verification passed."
            fi
        elif [[ -n "${DISTRO_INFO["$SELECTED_DISTRO,checksum"]}" ]]; then
            show_info "Verifying checksum..."
            echo "${DISTRO_INFO["$SELECTED_DISTRO,checksum"]} $filename" > SHA256SUMS-custom
            if ! sha256sum -c SHA256SUMS-custom; then
                show_error "Checksum verification failed."
                if ! prompt_yes_no "Continue anyway?" "N"; then
                    return
                fi
            else
                show_success "Checksum verification passed."
            fi
        else
            show_warning "No checksum available for verification."
        fi

        # Handle image conversion if needed
        if [[ "${DISTRO_INFO["$SELECTED_DISTRO,needs_conversion"]}" == "true" ]]; then
            show_info "Converting image to qcow2 format..."
            local base_filename="${filename%.*}"
            if ! qemu-img convert -O qcow2 -o compat=0.10 "$filename" "${base_filename}.qcow2"; then
                show_error "Image conversion failed."
                return
            fi
            show_success "Image conversion complete."
            VM_DISK_IMAGE="${IMAGES_PATH}/${base_filename}.qcow2"
        fi
    fi
}

# Function to configure VM settings
configure_vm_settings() {
    section_header "Configure VM Settings"

    # Template ID
    TEMPLATE_ID=$(prompt_value "Enter template ID" "$TEMPLATE_ID" "^[0-9]+$")

    # VM Name
    VM_NAME=$(prompt_value "Enter VM name" "$VM_NAME" "^[a-zA-Z0-9_-]+$")

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

    show_success "VM settings configured."
}

# Function to configure cloud-init settings
configure_cloud_init() {
    section_header "Configure Cloud-Init Settings"

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

    show_success "Cloud-init settings configured."
}

# Function to review configuration
review_configuration() {
    section_header "Review Configuration"

    echo -e "${BOLD}Distribution:${RESET} ${DISTRO_INFO["$SELECTED_DISTRO,name"]}"
    echo -e "${BOLD}Image Path:${RESET} $IMAGES_PATH"
    echo -e "${BOLD}Disk Image:${RESET} $VM_DISK_IMAGE"
    echo ""
    echo -e "${BOLD}Template ID:${RESET} $TEMPLATE_ID"
    echo -e "${BOLD}VM Name:${RESET} $VM_NAME"
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

    if ! prompt_yes_no "Is this configuration correct?" "Y"; then
        return 1
    fi

    return 0
}

# Function to create VM template
create_vm_template() {
    section_header "Creating VM Template"

    # Create VM
    show_info "Creating VM with ID $TEMPLATE_ID..."
    local create_cmd="qm create $TEMPLATE_ID --name $VM_NAME --cpu $QEMU_CPU_MODEL --sockets $VM_CPU_SOCKETS --cores $VM_CPU_CORES --memory $VM_MEMORY --numa 1 --net0 virtio,bridge=vmbr0 --ostype l26 --agent 1 --scsihw virtio-scsi-single"

    if [ -n "$VM_RESOURCE_POOL" ]; then
        create_cmd="$create_cmd --pool $VM_RESOURCE_POOL"
    fi

    if ! eval "$create_cmd"; then
        show_error "Failed to create VM."
        return 1
    fi

    # Import disk
    show_info "Importing disk image..."
    if ! qm set $TEMPLATE_ID --scsi0 local-zfs:0,import-from=$VM_DISK_IMAGE; then
        show_error "Failed to import disk image."
        return 1
    fi

    # Add Cloud-Init CD-ROM drive
    show_info "Adding Cloud-Init CD-ROM drive..."
    if ! qm set $TEMPLATE_ID --ide2 local-zfs:cloudinit --boot order=scsi0; then
        show_error "Failed to add Cloud-Init CD-ROM drive."
        return 1
    fi

    # Configure Cloud-init network
    show_info "Configuring Cloud-init network..."
    if ! qm set $TEMPLATE_ID --ipconfig0 ip=$CLOUD_INIT_IP --nameserver $CLOUD_INIT_NAMESERVER --searchdomain $CLOUD_INIT_SEARCHDOMAIN; then
        show_error "Failed to configure Cloud-init network."
        return 1
    fi

    # Configure Cloud-init user
    show_info "Configuring Cloud-init user..."
    if ! qm set $TEMPLATE_ID --ciupgrade 1 --ciuser $CLOUD_INIT_USER --sshkeys $CLOUD_INIT_SSHKEY; then
        show_error "Failed to configure Cloud-init user."
        return 1
    fi

    # Update Cloud-init
    show_info "Updating Cloud-init..."
    if ! qm cloudinit update $TEMPLATE_ID; then
        show_error "Failed to update Cloud-init."
        return 1
    fi

    # Rename VM to template
    show_info "Renaming VM to template..."
    if ! qm set $TEMPLATE_ID --name "${VM_NAME}-Template"; then
        show_error "Failed to rename VM."
        return 1
    fi

    # Convert to template
    show_info "Converting to template..."
    if ! qm template $TEMPLATE_ID; then
        show_error "Failed to convert VM to template."
        return 1
    fi

    show_success "Template created successfully."
    return 0
}

# Function to create VM from template
create_vm_from_template() {
    section_header "Creating VM from Template"

    if ! prompt_yes_no "Would you like to create a VM from this template?" "Y"; then
        return 1
    fi

    # Get next VM ID
    local VM_ID
    VM_ID=$(pvesh get /cluster/nextid)
    show_info "Using VM ID: $VM_ID"

    # Clone template
    show_info "Cloning template..."
    if ! qm clone $TEMPLATE_ID $VM_ID --name $VM_NAME; then
        show_error "Failed to clone template."
        return 1
    fi

    # Start VM
    show_info "Starting VM..."
    if ! qm start $VM_ID; then
        show_error "Failed to start VM."
        return 1
    fi

    show_success "VM created and started successfully."

    # Display connection info
    section_header "Connection Information"

    echo -e "${BOLD}VM ID:${RESET} $VM_ID"
    echo -e "${BOLD}VM Name:${RESET} $VM_NAME"

    if [ "$CLOUD_INIT_IP" == "dhcp" ]; then
        echo ""
        show_info "VM is configured to use DHCP. You may need to check your DHCP server or router to find the assigned IP address."
        echo ""
        echo -e "Once you have the IP address, you can connect using:"
        echo -e "${BOLD}ssh $CLOUD_INIT_USER@<VM_IP_ADDRESS> -i ${CLOUD_INIT_SSHKEY%.pub}${RESET}"
    else
        local static_ip="${CLOUD_INIT_IP%%,*}"
        static_ip="${static_ip%%/*}"
        echo ""
        echo -e "You can connect to the VM using:"
        echo -e "${BOLD}ssh $CLOUD_INIT_USER@$static_ip -i ${CLOUD_INIT_SSHKEY%.pub}${RESET}"
    fi

    echo ""
    show_info "Note: It may take a few moments for the VM to fully boot and configure cloud-init."

    return 0
}

# Main function
main() {
    show_header
    check_prerequisites
    load_config

    select_distribution
    configure_images
    configure_vm_settings
    configure_cloud_init

    while ! review_configuration; do
        show_info "Let's revise the configuration."

        local config_options=("Distribution Selection" "Image Path & Download" "VM Settings" "Cloud-Init Settings" "Continue with current settings")
        show_menu "What would you like to change?" "${config_options[@]}"

        case $MENU_SELECTION in
            0) select_distribution ;;
            1) configure_images ;;
            2) configure_vm_settings ;;
            3) configure_cloud_init ;;
            4) break ;;
        esac
    done

    save_config

    if create_vm_template; then
        create_vm_from_template
    fi

    section_header "Wizard Complete"
    show_success "Thank you for using the Proxmox VM Template Creation Wizard!"
}

# Run the main function
main
