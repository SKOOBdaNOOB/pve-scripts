#!/bin/bash
#
# Storage Management for Proxmox VM Template Wizard
# Handles storage pools, disk paths, and disk configuration
#

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../core/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/validation.sh"

# Default storage configuration
STORAGE_POOL="local-lvm"
STORAGE_TYPE=""
DISK_FORMAT="raw"
DISK_SIZE="8G"
DISK_CACHE="none"
DISK_SSD_EMULATION=0
DISK_DISCARD="ignore"
DISK_IO_THREAD=0
DISK_BACKUP=1

# Get list of available storage pools
get_storage_pools() {
    local storage_pools=()
    local output

    # Try to get storage pools from Proxmox
    if output=$(pvesh get /storage --output-format json 2>/dev/null); then
        # Parse JSON output
        while read -r line; do
            if [[ "$line" =~ \"storage\":\"([^\"]+)\" ]]; then
                storage_pools+=("${BASH_REMATCH[1]}")
            fi
        done < <(echo "$output" | grep -o '"storage":"[^"]*"')

        if [ ${#storage_pools[@]} -eq 0 ]; then
            log_warning "No storage pools found in Proxmox API output"
        else
            log_debug "Found ${#storage_pools[@]} storage pools from Proxmox API"
        fi
    else
        log_warning "Failed to get storage pools from Proxmox API, using fallback method"

        # Fallback to common storage pool names
        storage_pools=("local-lvm" "local" "local-zfs" "local-dir")
        log_debug "Using fallback storage pool list: ${storage_pools[*]}"
    fi

    # Return the array as a space-separated string
    echo "${storage_pools[@]}"
}

# Get storage pool details
get_storage_pool_details() {
    local storage_pool="$1"
    local details=""
    local output

    if output=$(pvesh get /storage/"$storage_pool" --output-format json 2>/dev/null); then
        # Extract type and content from JSON
        local type=$(echo "$output" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
        local content=$(echo "$output" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
        local avail=$(echo "$output" | grep -o '"avail":"[^"]*"' | cut -d'"' -f4)

        # Build details string
        details="Type: $type"
        [ -n "$content" ] && details="$details, Content: $content"
        [ -n "$avail" ] && details="$details, Available: $avail"
    else
        log_warning "Failed to get details for storage pool: $storage_pool"
        details="(Details unavailable)"
    fi

    echo "$details"
}

# Check if storage pool is valid and usable
check_storage_pool() {
    local storage_pool="$1"
    local content_type="${2:-images}" # Default to checking for 'images' content
    local output

    if output=$(pvesh get /storage/"$storage_pool" --output-format json 2>/dev/null); then
        # Check if storage is enabled
        if [[ "$output" == *'"disable":1'* ]]; then
            log_error "Storage pool '$storage_pool' is disabled"
            return 1
        fi

        # Check content types
        local content
        if [[ "$output" =~ \"content\":\"([^\"]+)\" ]]; then
            content="${BASH_REMATCH[1]}"
            if [[ ! "$content" == *"$content_type"* ]]; then
                log_error "Storage pool '$storage_pool' doesn't support '$content_type' content (only: $content)"
                return 1
            fi
        else
            log_warning "Could not determine content types for storage pool '$storage_pool'"
        fi

        # Get storage type
        if [[ "$output" =~ \"type\":\"([^\"]+)\" ]]; then
            STORAGE_TYPE="${BASH_REMATCH[1]}"
            log_debug "Storage pool '$storage_pool' is of type '$STORAGE_TYPE'"
        else
            log_warning "Could not determine type for storage pool '$storage_pool'"
            STORAGE_TYPE="unknown"
        fi

        return 0
    else
        log_error "Storage pool '$storage_pool' doesn't exist or is not accessible"
        return 1
    fi
}

# Get available space in storage pool (in bytes)
get_storage_available_space() {
    local storage_pool="$1"
    local available=0
    local output

    if output=$(pvesh get /nodes/localhost/storage/"$storage_pool"/status --output-format json 2>/dev/null); then
        if [[ "$output" =~ \"avail\":([0-9]+) ]]; then
            available="${BASH_REMATCH[1]}"
            log_debug "Storage pool '$storage_pool' has $available bytes available"
        else
            log_warning "Could not determine available space for storage pool '$storage_pool'"
        fi
    else
        log_warning "Failed to get status for storage pool: $storage_pool"
    fi

    echo "$available"
}

# Select storage pool with menu
select_storage_pool() {
    section_header "Storage Pool Selection"

    local storage_pools=($(get_storage_pools))

    if [ ${#storage_pools[@]} -eq 0 ]; then
        show_warning "No storage pools found. Using default: $STORAGE_POOL"
        return
    fi

    # Create array with details for display
    local display_options=()
    for pool in "${storage_pools[@]}"; do
        local details=$(get_storage_pool_details "$pool")
        display_options+=("$pool ($details)")
    done

    show_menu "Select Storage Pool" "${display_options[@]}"
    STORAGE_POOL="${storage_pools[$MENU_SELECTION]}"

    # Verify the selected pool is usable
    if ! check_storage_pool "$STORAGE_POOL" "images"; then
        show_warning "Selected storage pool may not be suitable for VM images"
        if prompt_yes_no "Would you like to select a different storage pool?" "Y"; then
            select_storage_pool
            return
        fi
    fi

    show_success "Selected storage pool: $STORAGE_POOL"

    # Determine appropriate disk format based on storage type
    case "$STORAGE_TYPE" in
        zfspool)
            DISK_FORMAT="raw"
            show_info "Using raw disk format for ZFS storage"
            ;;
        lvmthin|lvm)
            DISK_FORMAT="raw"
            show_info "Using raw disk format for LVM storage"
            ;;
        dir|nfs|cifs)
            DISK_FORMAT="qcow2"
            show_info "Using qcow2 disk format for file-based storage"
            ;;
        *)
            # Ask user for format preference
            local format_options=("raw (better performance, no snapshots)" "qcow2 (snapshots, thin provisioning)")
            show_menu "Select Disk Format" "${format_options[@]}"
            if [ "$MENU_SELECTION" -eq 0 ]; then
                DISK_FORMAT="raw"
            else
                DISK_FORMAT="qcow2"
            fi
            ;;
    esac
}

# Configure disk settings
configure_disk() {
    section_header "Disk Configuration"

    # Disk size
    DISK_SIZE=$(prompt_value "Enter disk size (with suffix G for GB, M for MB)" "$DISK_SIZE" "^[0-9]+[GM]$")

    # Advanced disk options
    if prompt_yes_no "Configure advanced disk options?" "N"; then
        # Cache mode
        local cache_options=("none (safest)" "writeback (faster but less safe)" "writethrough (safe but slower)")
        show_menu "Select cache mode" "${cache_options[@]}"
        case $MENU_SELECTION in
            0) DISK_CACHE="none" ;;
            1) DISK_CACHE="writeback" ;;
            2) DISK_CACHE="writethrough" ;;
        esac

        # SSD emulation
        if prompt_yes_no "Enable SSD emulation?" "N"; then
            DISK_SSD_EMULATION=1
        else
            DISK_SSD_EMULATION=0
        fi

        # Discard/TRIM
        local discard_options=("ignore (default)" "on (enable TRIM/discard)")
        show_menu "Select discard mode" "${discard_options[@]}"
        case $MENU_SELECTION in
            0) DISK_DISCARD="ignore" ;;
            1) DISK_DISCARD="on" ;;
        esac

        # IO thread
        if prompt_yes_no "Enable IO thread (can improve performance)?" "Y"; then
            DISK_IO_THREAD=1
        else
            DISK_IO_THREAD=0
        fi

        # Backup inclusion
        if prompt_yes_no "Include disk in backups?" "Y"; then
            DISK_BACKUP=1
        else
            DISK_BACKUP=0
        fi
    fi

    show_success "Disk configuration complete"
}

# Build the disk option string for qm commands
get_disk_options_string() {
    local disk_id="$1"
    local storage_pool="$2"
    local options=""

    options="${storage_pool}:${disk_id}"

    # Add size option if it's a new disk
    if [[ "$3" == "new" ]]; then
        options="${options},size=${DISK_SIZE}"
    fi

    # Add format for appropriate storage types
    if [[ "$STORAGE_TYPE" == "dir" || "$STORAGE_TYPE" == "nfs" || "$STORAGE_TYPE" == "cifs" ]]; then
        options="${options},format=${DISK_FORMAT}"
    fi

    # Add advanced options
    [ "$DISK_CACHE" != "none" ] && options="${options},cache=${DISK_CACHE}"
    [ "$DISK_SSD_EMULATION" -eq 1 ] && options="${options},ssd=1"
    [ "$DISK_DISCARD" != "ignore" ] && options="${options},discard=${DISK_DISCARD}"
    [ "$DISK_IO_THREAD" -eq 1 ] && options="${options},iothread=1"
    [ "$DISK_BACKUP" -eq 0 ] && options="${options},backup=0"

    echo "$options"
}

# Import an image to a VM disk
import_disk_image() {
    local vm_id="$1"
    local disk_id="${2:-scsi0}"
    local image_path="$3"

    log_info "Importing disk image from $image_path to VM $vm_id disk $disk_id on storage $STORAGE_POOL"

    # Validate image path
    if ! validate_path_exists "$image_path" "file"; then
        log_error "Image file does not exist: $image_path"
        return 1
    fi

    # Execute the import
    local cmd="qm set $vm_id --$disk_id $STORAGE_POOL:0,import-from=$image_path"
    log_debug "Executing: $cmd"

    if ! eval "$cmd"; then
        log_error "Failed to import disk image"
        return 1
    fi

    log_success "Disk image imported successfully"
    return 0
}

# Recommend storage configuration based on VM purpose
recommend_storage_config() {
    local vm_purpose="$1" # general, database, webserver, fileserver, container, etc.

    section_header "Storage Recommendations"

    case "$vm_purpose" in
        database)
            show_info "For database servers, performance and data integrity are critical."
            show_info "- Recommended storage: LVM/ZFS for better performance"
            show_info "- Recommended format: raw"
            show_info "- Recommended cache: none or writethrough for data safety"
            show_info "- Consider enabling IO thread"
            ;;
        webserver)
            show_info "For web servers, a balance of performance and safety is important."
            show_info "- Any storage pool type should work well"
            show_info "- Consider using writeback cache if data loss risk is acceptable"
            show_info "- SSD emulation can improve performance for static content"
            ;;
        fileserver)
            show_info "For file servers, larger disks and backup capability are important."
            show_info "- ZFS/LVM provides good performance for large files"
            show_info "- Consider multiple disks for different data types"
            show_info "- Ensure disks are included in backup"
            ;;
        container)
            show_info "For container hosts, performance is key."
            show_info "- LVM/ZFS recommended for performance"
            show_info "- Raw format recommended"
            show_info "- Consider writeback cache and IO thread"
            ;;
        *)
            show_info "For general purpose VMs, balanced configuration works well."
            show_info "- Any storage pool should be suitable"
            show_info "- Default cache and format settings are a good starting point"
            show_info "- Consider your backup strategy when configuring disks"
            ;;
    esac

    if prompt_yes_no "Would you like to use recommended settings for $vm_purpose?" "Y"; then
        # Set recommended values based on purpose
        case "$vm_purpose" in
            database)
                DISK_FORMAT="raw"
                DISK_CACHE="none"
                DISK_IO_THREAD=1
                DISK_BACKUP=1
                ;;
            webserver)
                DISK_CACHE="writeback"
                DISK_SSD_EMULATION=1
                ;;
            fileserver)
                DISK_FORMAT="raw"
                DISK_SIZE="32G"
                DISK_BACKUP=1
                ;;
            container)
                DISK_FORMAT="raw"
                DISK_CACHE="writeback"
                DISK_IO_THREAD=1
                ;;
        esac
        show_success "Applied recommended settings for $vm_purpose"
    fi
}
