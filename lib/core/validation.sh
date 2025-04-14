#!/bin/bash
#
# Validation Utilities for Proxmox VM Template Wizard
# Implements comprehensive validation for inputs including IP addresses, paths, resources, and VM names
#

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# IP Address Validation Functions

# Validate IPv4 address
validate_ipv4() {
    local ip="$1"
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if ! [[ "$ip" =~ $ip_regex ]]; then
        return 1
    fi

    # Check each octet is between 0-255
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [ "$octet" -gt 255 ]; then
            return 1
        fi
    done

    return 0
}

# Validate CIDR notation
validate_cidr() {
    local cidr="$1"
    local cidr_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$'

    if ! [[ "$cidr" =~ $cidr_regex ]]; then
        return 1
    fi

    # Extract IP and prefix
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"

    # Validate IP part
    if ! validate_ipv4 "$ip"; then
        return 1
    fi

    # Validate prefix is between 0-32
    if [ "$prefix" -lt 0 ] || [ "$prefix" -gt 32 ]; then
        return 1
    fi

    return 0
}

# Validate IP configuration (supports DHCP or static with optional gateway)
validate_ip_config() {
    local config="$1"

    # Check if config is DHCP
    if [ "$config" = "dhcp" ]; then
        return 0
    fi

    # Check for static IP with gateway format
    local ip_part gateway

    # Split by comma to extract gateway part if it exists
    if [[ "$config" == *,gw=* ]]; then
        ip_part="${config%%,*}"
        gateway="${config#*,gw=}"

        # Validate gateway is a valid IP
        if ! validate_ipv4 "$gateway"; then
            log_error "Invalid gateway IP: $gateway"
            return 1
        fi
    else
        ip_part="$config"
    fi

    # Validate IP part (with or without CIDR)
    if [[ "$ip_part" == */* ]]; then
        # IP has CIDR notation
        if ! validate_cidr "$ip_part"; then
            log_error "Invalid IP/CIDR format: $ip_part"
            return 1
        fi
    else
        # IP without CIDR
        if ! validate_ipv4 "$ip_part"; then
            log_error "Invalid IP address: $ip_part"
            return 1
        fi
    fi

    return 0
}

# Check for network conflicts (requires access to existing VMs)
check_network_conflicts() {
    local ip_config="$1"
    local ignore_vmid="$2"  # Optional VM ID to ignore (for updates)

    # Skip check for DHCP
    if [ "$ip_config" = "dhcp" ]; then
        return 0
    fi

    # Extract the IP without CIDR or gateway
    local ip
    if [[ "$ip_config" == */* ]]; then
        ip="${ip_config%%/*}"
    elif [[ "$ip_config" == *,* ]]; then
        ip="${ip_config%%,*}"
    else
        ip="$ip_config"
    fi

    log_debug "Checking for network conflicts with IP: $ip"

    # Query existing VM configs for IP conflicts
    local running_vms
    if ! running_vms=$(qm list 2>/dev/null); then
        log_warning "Could not check for network conflicts - unable to list VMs"
        return 0  # Not fatal, continue anyway
    fi

    # Extract VM IDs (skip header line)
    local vm_ids=()
    while read -r line; do
        [[ "$line" =~ ^[[:space:]]*([0-9]+) ]] && vm_ids+=(${BASH_REMATCH[1]})
    done < <(echo "$running_vms" | tail -n +2)

    # Check each VM config
    for vmid in "${vm_ids[@]}"; do
        # Skip the VM we're updating
        [ -n "$ignore_vmid" ] && [ "$vmid" -eq "$ignore_vmid" ] && continue

        local vm_config
        vm_config=$(qm config "$vmid" 2>/dev/null)

        # Look for ipconfig entries
        while read -r ipconfig_line; do
            local vm_ip

            # Extract IP from ipconfig line
            if [[ "$ipconfig_line" =~ ip=([^, ]+) ]]; then
                vm_ip="${BASH_REMATCH[1]}"

                # Skip DHCP
                [ "$vm_ip" = "dhcp" ] && continue

                # Extract IP part without CIDR or gateway
                if [[ "$vm_ip" == */* ]]; then
                    vm_ip="${vm_ip%%/*}"
                elif [[ "$vm_ip" == *,* ]]; then
                    vm_ip="${vm_ip%%,*}"
                fi

                # Compare IPs
                if [ "$vm_ip" = "$ip" ]; then
                    log_warning "IP conflict detected: $ip is already used by VM $vmid"
                    return 1
                fi
            fi
        done < <(echo "$vm_config" | grep -E 'ipconfig[0-9]+:')
    done

    return 0
}

# Path Validation Functions

# Validate path exists
validate_path_exists() {
    local path="$1"
    local type="$2"  # 'file' or 'directory'

    # Convert relative path to absolute if not starting with /
    if [[ ! "$path" = /* ]]; then
        path="$(pwd)/$path"
        log_debug "Converted relative path to absolute: $path"
    fi

    if [ "$type" = "file" ]; then
        if [ ! -f "$path" ]; then
            log_error "File does not exist: $path"
            return 1
        fi
    elif [ "$type" = "directory" ]; then
        if [ ! -d "$path" ]; then
            log_error "Directory does not exist: $path"
            return 1
        fi
    else
        if [ ! -e "$path" ]; then
            log_error "Path does not exist: $path"
            return 1
        fi
    fi

    return 0
}

# Validate path is readable
validate_path_readable() {
    local path="$1"

    # First check if path exists
    if [ ! -e "$path" ]; then
        log_error "Path does not exist: $path"
        return 1
    fi

    # Check if readable
    if [ ! -r "$path" ]; then
        log_error "Path is not readable: $path"
        return 1
    fi

    return 0
}

# Validate path is writable
validate_path_writable() {
    local path="$1"
    local create_if_missing="$2"  # Optional boolean to create directory

    # If it's a new file, check parent directory
    if [ ! -e "$path" ]; then
        local dir_path
        dir_path="$(dirname "$path")"

        if [ ! -d "$dir_path" ]; then
            if [ "$create_if_missing" = "true" ]; then
                log_debug "Creating directory: $dir_path"
                if ! mkdir -p "$dir_path"; then
                    log_error "Failed to create directory: $dir_path"
                    return 1
                fi
            else
                log_error "Directory does not exist: $dir_path"
                return 1
            fi
        fi

        # Check if directory is writable
        if [ ! -w "$dir_path" ]; then
            log_error "Directory is not writable: $dir_path"
            return 1
        fi
    else
        # Path exists, check if writable
        if [ ! -w "$path" ]; then
            log_error "Path is not writable: $path"
            return 1
        fi
    fi

    return 0
}

# Validate SSH key file
validate_ssh_key() {
    local key_path="$1"

    # Check if file exists and is readable
    if ! validate_path_readable "$key_path"; then
        log_warning "SSH key is not readable: $key_path"
        return 1
    fi

    # Validate it's an SSH public key by checking content format
    local key_content
    key_content=$(cat "$key_path")
    local ssh_key_regex='^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp[0-9]+) [A-Za-z0-9+/]+[=]{0,3}( .+)?$'

    if ! [[ "$key_content" =~ $ssh_key_regex ]]; then
        log_warning "File does not appear to be a valid SSH public key: $key_path"
        return 1
    fi

    return 0
}

# Resource Validation Functions

# Get host resources (CPU, memory)
get_host_resources() {
    local cpu_cores=0
    local memory_kb=0

    # Get CPU cores
    if command -v nproc &>/dev/null; then
        cpu_cores=$(nproc)
    else
        cpu_cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo 1)
    fi

    # Get total memory
    if [ -f "/proc/meminfo" ]; then
        memory_kb=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
    else
        # Fallback to 4GB
        memory_kb=4194304
    fi

    echo "$cpu_cores $memory_kb"
}

# Validate VM resources against host capabilities
validate_vm_resources() {
    local cpu_sockets="$1"
    local cpu_cores="$2"
    local memory_mb="$3"

    # Get host resources
    local host_resources
    host_resources=$(get_host_resources)
    local host_cpu_cores=${host_resources%% *}
    local host_memory_kb=${host_resources##* }
    local host_memory_mb=$((host_memory_kb / 1024))

    local total_vm_cores=$((cpu_sockets * cpu_cores))
    local warnings=0

    # Check CPU cores
    if [ "$total_vm_cores" -gt "$host_cpu_cores" ]; then
        log_warning "VM CPU cores ($total_vm_cores) exceed host CPU cores ($host_cpu_cores). This may cause overcommitment."
        warnings=$((warnings + 1))
    fi

    # Check memory - warn if more than 80% of host memory
    local max_recommended_memory_mb=$((host_memory_mb * 80 / 100))
    if [ "$memory_mb" -gt "$max_recommended_memory_mb" ]; then
        log_warning "VM memory allocation ($memory_mb MB) exceeds 80% of host memory ($max_recommended_memory_mb MB of $host_memory_mb MB total)."
        warnings=$((warnings + 1))
    fi

    return $warnings
}

# Validate that VM resources are sensible
validate_vm_resources_sensible() {
    local cpu_sockets="$1"
    local cpu_cores="$2"
    local memory_mb="$3"

    local warnings=0

    # Validate CPU sockets
    if [ "$cpu_sockets" -lt 1 ]; then
        log_error "CPU sockets must be at least 1"
        return 1
    fi

    if [ "$cpu_sockets" -gt 4 ]; then
        log_warning "CPU sockets ($cpu_sockets) is unusually high. Consider using fewer sockets with more cores."
        warnings=$((warnings + 1))
    fi

    # Validate CPU cores
    if [ "$cpu_cores" -lt 1 ]; then
        log_error "CPU cores must be at least 1"
        return 1
    fi

    # Validate memory
    if [ "$memory_mb" -lt 256 ]; then
        log_error "Memory must be at least 256 MB"
        return 1
    fi

    return $warnings
}

# Hostname/VM Name Validation Functions

# Validate VM name follows naming conventions
validate_vm_name() {
    local vm_name="$1"

    # Check for valid hostname syntax (RFC 1123)
    local hostname_regex='^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$'

    if ! [[ "$vm_name" =~ $hostname_regex ]]; then
        log_error "VM name must contain only alphanumeric characters and hyphens, cannot start or end with a hyphen, and must be between 1-63 characters."
        return 1
    fi

    return 0
}

# Check for duplicate VM names/IDs
check_duplicate_vm_name() {
    local vm_name="$1"
    local ignore_vmid="$2"  # Optional VM ID to ignore (for updates)

    # Query existing VM names
    local existing_vms
    if ! existing_vms=$(qm list 2>/dev/null); then
        log_warning "Could not check for duplicate VM names - unable to list VMs"
        return 0  # Not fatal, continue anyway
    fi

    local found=0
    while read -r line; do
        local vmid name
        # Extract VM ID and name
        if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+([^[:space:]]+) ]]; then
            vmid="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"

            # Skip the VM we're updating
            [ -n "$ignore_vmid" ] && [ "$vmid" -eq "$ignore_vmid" ] && continue

            if [ "$name" = "$vm_name" ]; then
                log_warning "VM name '$vm_name' is already used by VM ID $vmid"
                found=1
                break
            fi
        fi
    done < <(echo "$existing_vms" | tail -n +2)  # Skip header line

    return $found
}

# Check for duplicate VM ID
check_duplicate_vmid() {
    local vmid="$1"

    # Check if VM with this ID already exists
    if qm status "$vmid" &>/dev/null; then
        log_warning "VM ID $vmid is already in use"
        return 1
    fi

    return 0
}

# Generate auto-correction suggestion for invalid name
suggest_valid_vm_name() {
    local vm_name="$1"
    local suggestion

    # Replace invalid characters with hyphens
    suggestion=$(echo "$vm_name" | tr -c '[:alnum:]-' '-')

    # Ensure name starts and ends with alphanumeric character
    suggestion=$(echo "$suggestion" | sed 's/^[-]*//' | sed 's/[-]*$//')

    # Ensure name is not empty (default to "vm")
    if [ -z "$suggestion" ]; then
        suggestion="vm"
    fi

    # Truncate to 63 characters
    if [ ${#suggestion} -gt 63 ]; then
        suggestion="${suggestion:0:63}"
    fi

    echo "$suggestion"
}

# Validate VM ID is in acceptable range
validate_vmid() {
    local vmid="$1"

    # Proxmox typically uses VM IDs from 100 to 999999
    if ! [[ "$vmid" =~ ^[0-9]+$ ]] || [ "$vmid" -lt 100 ] || [ "$vmid" -gt 999999 ]; then
        log_error "VM ID must be a number between 100 and 999999"
        return 1
    fi

    return 0
}

# Get next available VM ID
get_next_vmid() {
    local next_id

    if ! next_id=$(pvesh get /cluster/nextid 2>/dev/null); then
        # Fallback if pvesh command fails
        log_warning "Could not get next VM ID from Proxmox API, using fallback method"

        # Find highest used ID
        local highest_id=100
        local used_ids

        if used_ids=$(qm list 2>/dev/null | tail -n +2 | awk '{print $1}'); then
            while read -r id; do
                if [ "$id" -gt "$highest_id" ]; then
                    highest_id="$id"
                fi
            done < <(echo "$used_ids")

            next_id=$((highest_id + 1))
        else
            next_id=101  # Default starting ID
        fi
    fi

    echo "$next_id"
}
