#!/bin/bash
#
# Distribution Information for Proxmox VM Template Wizard
# Contains metadata for supported Linux distributions and cloud images
#

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"

# Distribution information - using a function-based approach instead of associative arrays
# for better compatibility across different shells

# Function to get a distribution property
get_distro_property() {
    local distro="$1"
    local property="$2"

    case "$distro,$property" in
        # Alma Linux 9
        "alma9,name") echo "Alma Linux 9" ;;
        "alma9,url") echo "https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2" ;;
        "alma9,checksum_url") echo "https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/CHECKSUM" ;;
        "alma9,filename") echo "AlmaLinux-9-GenericCloud-latest.x86_64.qcow2" ;;
        "alma9,os_type") echo "l26" ;;
        "alma9,needs_conversion") echo "false" ;;

        # Amazon Linux 2
        "amazon2,name") echo "Amazon Linux 2" ;;
        "amazon2,url") echo "https://cdn.amazonlinux.com/os-images/2.0.20230727.0/kvm/amzn2-kvm-2.0.20230727.0-x86_64.xfs.gpt.qcow2" ;;
        "amazon2,checksum_url") echo "" ;;
        "amazon2,filename") echo "amzn2-kvm-2.0.20230727.0-x86_64.xfs.gpt.qcow2" ;;
        "amazon2,os_type") echo "l26" ;;
        "amazon2,needs_conversion") echo "false" ;;

        # CentOS 9 Stream
        "centos9,name") echo "CentOS 9 Stream" ;;
        "centos9,url") echo "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2" ;;
        "centos9,checksum_url") echo "" ;;
        "centos9,filename") echo "CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2" ;;
        "centos9,os_type") echo "l26" ;;
        "centos9,needs_conversion") echo "false" ;;

        # Fedora 38
        "fedora38,name") echo "Fedora 38" ;;
        "fedora38,url") echo "https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/Fedora-Cloud-Base-38-1.6.x86_64.qcow2" ;;
        "fedora38,checksum_url") echo "" ;;
        "fedora38,filename") echo "Fedora-Cloud-Base-38-1.6.x86_64.qcow2" ;;
        "fedora38,os_type") echo "l26" ;;
        "fedora38,needs_conversion") echo "false" ;;

        # Oracle Linux 9
        "oracle9,name") echo "Oracle Linux 9" ;;
        "oracle9,url") echo "https://yum.oracle.com/templates/OracleLinux/OL9/u2/x86_64/OL9U2_x86_64-kvm-b197.qcow" ;;
        "oracle9,checksum") echo "840345cb866837ac7cc7c347cd9a8196c3a17e9c054c613eda8c2a912434c956" ;;
        "oracle9,filename") echo "OL9U2_x86_64-kvm-b197.qcow" ;;
        "oracle9,os_type") echo "l26" ;;
        "oracle9,needs_conversion") echo "true" ;;
        "oracle9,converted_filename") echo "OL9U2_x86_64-kvm-b197.qcow2" ;;

        # Rocky Linux 9
        "rocky9,name") echo "Rocky Linux 9" ;;
        "rocky9,url") echo "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2" ;;
        "rocky9,checksum_url") echo "" ;;
        "rocky9,filename") echo "Rocky-9-GenericCloud-Base.latest.x86_64.qcow2" ;;
        "rocky9,os_type") echo "l26" ;;
        "rocky9,needs_conversion") echo "false" ;;

        # Ubuntu 23.04 Lunar Lobster
        "ubuntu23,name") echo "Ubuntu 23.04 Lunar Lobster" ;;
        "ubuntu23,url") echo "https://cloud-images.ubuntu.com/lunar/current/lunar-server-cloudimg-amd64.img" ;;
        "ubuntu23,checksum_url") echo "" ;;
        "ubuntu23,filename") echo "lunar-server-cloudimg-amd64.img" ;;
        "ubuntu23,os_type") echo "l26" ;;
        "ubuntu23,needs_conversion") echo "false" ;;

        # Default - return empty string
        *) echo "" ;;
    esac
}

# Function to initialize distribution information (no-op now, kept for compatibility)
init_distro_info() {
    log_debug "Using function-based distribution info system"
    return 0
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
        names+=("$(get_distro_property "$key" "name")")
    done
    echo "${names[@]}"
}

# Get the disk image path for a distribution
get_disk_image_path() {
    local distro="$1"
    local images_path="$2"
    local filename="$(get_distro_property "$distro" "filename")"

    # Check if needs conversion and return the converted filename if true
    if [[ "$(get_distro_property "$distro" "needs_conversion")" == "true" ]]; then
        local converted_filename="$(get_distro_property "$distro" "converted_filename")"
        if [[ -n "$converted_filename" ]]; then
            echo "${images_path}/${converted_filename}"
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

    local url="$(get_distro_property "$distro" "url")"
    local filename="$(get_distro_property "$distro" "filename")"
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
    fi

    # Download the image
    log_info "Downloading $(get_distro_property "$distro" "name") cloud image from: $url"
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
    local checksum_url="$(get_distro_property "$distro" "checksum_url")"
    local checksum="$(get_distro_property "$distro" "checksum")"

    if [[ -n "$checksum_url" ]]; then
        log_info "Verifying checksum..."
        wget -q "$checksum_url" -O SHA256SUMS
        if ! sha256sum -c SHA256SUMS --ignore-missing; then
            log_error "Checksum verification failed"
            cd "$current_dir"
            return 1
        else
            log_success "Checksum verification passed"
        fi
    elif [[ -n "$checksum" ]]; then
        log_info "Verifying checksum..."
        echo "$checksum $filename" > SHA256SUMS-custom
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
    if [[ "$(get_distro_property "$distro" "needs_conversion")" == "true" ]]; then
        log_info "Converting image to qcow2 format..."
        local base_filename="${filename%.*}"
        local converted_filename="$(get_distro_property "$distro" "converted_filename")"

        if [[ -z "$converted_filename" ]]; then
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
