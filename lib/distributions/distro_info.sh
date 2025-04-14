#!/bin/bash
#
# Distribution Information for Proxmox VM Template Wizard
# Contains metadata for supported Linux distributions and cloud images
#

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"

# Distribution information
declare -A DISTRO_INFO

# Function to initialize distribution information
init_distro_info() {
    # Alma Linux 9
    DISTRO_INFO["alma9,name"]="Alma Linux 9"
    DISTRO_INFO["alma9,url"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
    DISTRO_INFO["alma9,checksum_url"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/CHECKSUM"
    DISTRO_INFO["alma9,filename"]="AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
    DISTRO_INFO["alma9,os_type"]="l26"
    DISTRO_INFO["alma9,needs_conversion"]="false"

    # Amazon Linux 2
    DISTRO_INFO["amazon2,name"]="Amazon Linux 2"
    DISTRO_INFO["amazon2,url"]="https://cdn.amazonlinux.com/os-images/2.0.20230727.0/kvm/amzn2-kvm-2.0.20230727.0-x86_64.xfs.gpt.qcow2"
    DISTRO_INFO["amazon2,checksum_url"]=""
    DISTRO_INFO["amazon2,filename"]="amzn2-kvm-2.0.20230727.0-x86_64.xfs.gpt.qcow2"
    DISTRO_INFO["amazon2,os_type"]="l26"
    DISTRO_INFO["amazon2,needs_conversion"]="false"

    # CentOS 9 Stream
    DISTRO_INFO["centos9,name"]="CentOS 9 Stream"
    DISTRO_INFO["centos9,url"]="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
    DISTRO_INFO["centos9,checksum_url"]=""
    DISTRO_INFO["centos9,filename"]="CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
    DISTRO_INFO["centos9,os_type"]="l26"
    DISTRO_INFO["centos9,needs_conversion"]="false"

    # Fedora 38
    DISTRO_INFO["fedora38,name"]="Fedora 38"
    DISTRO_INFO["fedora38,url"]="https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
    DISTRO_INFO["fedora38,checksum_url"]=""
    DISTRO_INFO["fedora38,filename"]="Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
    DISTRO_INFO["fedora38,os_type"]="l26"
    DISTRO_INFO["fedora38,needs_conversion"]="false"

    # Oracle Linux 9
    DISTRO_INFO["oracle9,name"]="Oracle Linux 9"
    DISTRO_INFO["oracle9,url"]="https://yum.oracle.com/templates/OracleLinux/OL9/u2/x86_64/OL9U2_x86_64-kvm-b197.qcow"
    DISTRO_INFO["oracle9,checksum"]="840345cb866837ac7cc7c347cd9a8196c3a17e9c054c613eda8c2a912434c956"
    DISTRO_INFO["oracle9,filename"]="OL9U2_x86_64-kvm-b197.qcow"
    DISTRO_INFO["oracle9,os_type"]="l26"
    DISTRO_INFO["oracle9,needs_conversion"]="true"
    DISTRO_INFO["oracle9,converted_filename"]="OL9U2_x86_64-kvm-b197.qcow2"

    # Rocky Linux 9
    DISTRO_INFO["rocky9,name"]="Rocky Linux 9"
    DISTRO_INFO["rocky9,url"]="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
    DISTRO_INFO["rocky9,checksum_url"]=""
    DISTRO_INFO["rocky9,filename"]="Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
    DISTRO_INFO["rocky9,os_type"]="l26"
    DISTRO_INFO["rocky9,needs_conversion"]="false"

    # Ubuntu 23.04 Lunar Lobster
    DISTRO_INFO["ubuntu23,name"]="Ubuntu 23.04 Lunar Lobster"
    DISTRO_INFO["ubuntu23,url"]="https://cloud-images.ubuntu.com/lunar/current/lunar-server-cloudimg-amd64.img"
    DISTRO_INFO["ubuntu23,checksum_url"]=""
    DISTRO_INFO["ubuntu23,filename"]="lunar-server-cloudimg-amd64.img"
    DISTRO_INFO["ubuntu23,os_type"]="l26"
    DISTRO_INFO["ubuntu23,needs_conversion"]="false"

    log_debug "Distribution information initialized with ${#DISTRO_INFO[@]} entries"
}

# Get a list of distribution keys
get_distro_keys() {
    local keys=("alma9" "amazon2" "centos9" "fedora38" "oracle9" "rocky9" "ubuntu23")
    echo "${keys[@]}"
}

# Get a list of distribution names
get_distro_names() {
    local names=()
    for key in $(get_distro_keys); do
        names+=("${DISTRO_INFO["$key,name"]}")
    done
    echo "${names[@]}"
}

# Get the disk image path for a distribution
get_disk_image_path() {
    local distro="$1"
    local images_path="$2"
    local filename="${DISTRO_INFO["$distro,filename"]}"

    # Check if needs conversion and return the converted filename if true
    if [[ "${DISTRO_INFO["$distro,needs_conversion"]}" == "true" ]]; then
        if [[ -n "${DISTRO_INFO["$distro,converted_filename"]}" ]]; then
            echo "${images_path}/${DISTRO_INFO["$distro,converted_filename"]}"
        else
            local base_filename="${filename%.*}"
            echo "${images_path}/${base_filename}.qcow2"
        fi
    else
        echo "${images_path}/${filename}"
    fi
}

# Download and verify a distribution image
download_distro_image() {
    local distro="$1"
    local images_path="$2"
    local force_download="${3:-false}"

    local url="${DISTRO_INFO["$distro,url"]}"
    local filename="${DISTRO_INFO["$distro,filename"]}"
    local full_path="${images_path}/${filename}"

    # Check if image already exists
    if [ -f "$full_path" ] && [ "$force_download" != "true" ]; then
        log_info "Image file already exists: $full_path"
        return 0
    fi

    # Create directory if it doesn't exist
    if [ ! -d "$images_path" ]; then
        log_info "Creating directory: $images_path"
        mkdir -p "$images_path" || {
            log_error "Failed to create directory: $images_path"
            return 1
        }
    }

    # Download the image
    log_info "Downloading ${DISTRO_INFO["$distro,name"]} cloud image from: $url"
    log_info "This may take some time depending on your internet connection..."

    # Change to images directory
    local current_dir=$(pwd)
    cd "$images_path" || {
        log_error "Failed to change to directory: $images_path"
        return 1
    }

    if ! wget -q --show-progress "$url"; then
        log_error "Failed to download image"
        cd "$current_dir"
        return 1
    fi

    log_success "Download complete"

    # Handle checksum verification
    if [[ -n "${DISTRO_INFO["$distro,checksum_url"]}" ]]; then
        log_info "Verifying checksum..."
        wget -q "${DISTRO_INFO["$distro,checksum_url"]}" -O SHA256SUMS
        if ! sha256sum -c SHA256SUMS --ignore-missing; then
            log_error "Checksum verification failed"
            cd "$current_dir"
            return 1
        else
            log_success "Checksum verification passed"
        fi
    elif [[ -n "${DISTRO_INFO["$distro,checksum"]}" ]]; then
        log_info "Verifying checksum..."
        echo "${DISTRO_INFO["$distro,checksum"]} $filename" > SHA256SUMS-custom
        if ! sha256sum -c SHA256SUMS-custom; then
            log_error "Checksum verification failed"
            cd "$current_dir"
            return 1
        else
            log_success "Checksum verification passed"
        fi
    else
        log_warning "No checksum available for verification"
    fi

    # Handle image conversion if needed
    if [[ "${DISTRO_INFO["$distro,needs_conversion"]}" == "true" ]]; then
        log_info "Converting image to qcow2 format..."
        local base_filename="${filename%.*}"
        local converted_filename

        if [[ -n "${DISTRO_INFO["$distro,converted_filename"]}" ]]; then
            converted_filename="${DISTRO_INFO["$distro,converted_filename"]}"
        else
            converted_filename="${base_filename}.qcow2"
        fi

        if ! qemu-img convert -O qcow2 -o compat=0.10 "$filename" "$converted_filename"; then
            log_error "Image conversion failed"
            cd "$current_dir"
            return 1
        fi
        log_success "Image conversion complete: $converted_filename"
    fi

    # Return to original directory
    cd "$current_dir"
    return 0
}

# Initialize distributions
init_distro_info
