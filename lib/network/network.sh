#!/bin/bash
#
# Network Configuration for Proxmox VM Template Wizard
# Handles IP configuration, network interfaces, VLANs, and bridges
#

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../core/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/validation.sh"

# Default network configuration
NET_DHCP=true
NET_IP=""
NET_GATEWAY=""
NET_NETMASK="24"
NET_NAMESERVER="1.1.1.1"
NET_SEARCHDOMAIN="example.com"
NET_BRIDGE="vmbr0"
NET_VLAN=""
NET_MODEL="virtio"
NET_FIREWALL=false
NET_INTERFACES=1

# Get list of available bridges on the host
get_available_bridges() {
    local bridges=()
    local output

    if output=$(ip link show type bridge 2>/dev/null); then
        while read -r line; do
            if [[ "$line" =~ ^[0-9]+:\ ([^:@]+) ]]; then
                bridges+=("${BASH_REMATCH[1]}")
            fi
        done < <(echo "$output")

        if [ ${#bridges[@]} -eq 0 ]; then
            # Fallback to common bridge names in Proxmox
            bridges=("vmbr0" "vmbr1" "vmbr2")
            log_debug "No bridges found, using fallback: ${bridges[*]}"
        else
            log_debug "Found bridges: ${bridges[*]}"
        fi
    else
        # Fallback to common bridge names in Proxmox
        bridges=("vmbr0" "vmbr1" "vmbr2")
        log_debug "Failed to get bridges, using fallback: ${bridges[*]}"
    fi

    echo "${bridges[@]}"
}

# Convert IP configuration to Proxmox format
format_ip_config() {
    local dhcp="$1"
    local ip="$2"
    local netmask="$3"
    local gateway="$4"

    if [ "$dhcp" = true ]; then
        echo "dhcp"
    else
        local result="$ip/$netmask"
        [ -n "$gateway" ] && result="${result},gw=${gateway}"
        echo "$result"
    fi
}

# Configure IP settings
configure_ip() {
    section_header "IP Configuration"

    # DHCP or Static
    local ip_options=("DHCP" "Static IP")
    show_menu "Choose IP Configuration Method" "${ip_options[@]}"

    if [ "$MENU_SELECTION" -eq 0 ]; then
        NET_DHCP=true
        show_success "Using DHCP for IP configuration"
    else
        NET_DHCP=false

        # IP Address
        while true; do
            NET_IP=$(prompt_value "Enter IP address" "$NET_IP")
            if validate_ipv4 "$NET_IP"; then
                break
            else
                show_error "Invalid IP address format. Please use format: xxx.xxx.xxx.xxx"
            fi
        done

        # Netmask
        while true; do
            NET_NETMASK=$(prompt_value "Enter netmask (CIDR notation, e.g. 24 for /24)" "$NET_NETMASK")
            if [[ "$NET_NETMASK" =~ ^[0-9]+$ ]] && [ "$NET_NETMASK" -ge 0 ] && [ "$NET_NETMASK" -le 32 ]; then
                break
            else
                show_error "Invalid netmask. Please enter a number between 0 and 32."
            fi
        done

        # Gateway
        while true; do
            NET_GATEWAY=$(prompt_value "Enter gateway IP" "$NET_GATEWAY")
            if [ -z "$NET_GATEWAY" ] || validate_ipv4 "$NET_GATEWAY"; then
                break
            else
                show_error "Invalid gateway IP format. Please use format: xxx.xxx.xxx.xxx"
            fi
        done

        # Check for conflicts
        local ip_config=$(format_ip_config false "$NET_IP" "$NET_NETMASK" "$NET_GATEWAY")
        if ! check_network_conflicts "$ip_config"; then
            show_warning "IP conflict detected. This IP may already be in use on your network."
            if ! prompt_yes_no "Continue with this IP anyway?" "N"; then
                configure_ip
                return
            fi
        fi

        show_success "Static IP configuration set: $ip_config"
    fi

    # DNS settings
    section_header "DNS Configuration"

    # Nameserver
    NET_NAMESERVER=$(prompt_value "Enter DNS nameserver" "$NET_NAMESERVER")

    # Search domain
    NET_SEARCHDOMAIN=$(prompt_value "Enter search domain" "$NET_SEARCHDOMAIN")

    show_success "DNS configuration set: Nameserver: $NET_NAMESERVER, Search domain: $NET_SEARCHDOMAIN"
}

# Configure network interface settings
configure_network_interface() {
    local interface_num="$1"
    local bridge=""
    local vlan=""
    local model=""

    section_header "Network Interface $interface_num Configuration"

    # Network bridge
    local bridges=($(get_available_bridges))
    local bridge_options=()

    for bridge in "${bridges[@]}"; do
        bridge_options+=("$bridge")
    done
    bridge_options+=("Other (specify manually)")

    show_menu "Select network bridge" "${bridge_options[@]}"

    if [ "$MENU_SELECTION" -eq "${#bridges[@]}" ]; then
        bridge=$(prompt_value "Enter bridge name" "vmbr0")
    else
        bridge="${bridges[$MENU_SELECTION]}"
    fi

    # VLAN
    if prompt_yes_no "Use VLAN tag for this interface?" "N"; then
        while true; do
            vlan=$(prompt_value "Enter VLAN ID (1-4094)" "")
            if [[ "$vlan" =~ ^[0-9]+$ ]] && [ "$vlan" -ge 1 ] && [ "$vlan" -le 4094 ]; then
                break
            else
                show_error "Invalid VLAN ID. Please enter a number between 1 and 4094."
            fi
        done
    fi

    # Network model
    local model_options=("virtio (best performance)" "e1000 (better compatibility)" "rtl8139 (legacy compatibility)")
    show_menu "Select network adapter model" "${model_options[@]}"

    case $MENU_SELECTION in
        0) model="virtio" ;;
        1) model="e1000" ;;
        2) model="rtl8139" ;;
    esac

    # MAC address (auto-generated or specific)
    local mac=""
    if prompt_yes_no "Specify a MAC address? (Default: auto-generate)" "N"; then
        while true; do
            mac=$(prompt_value "Enter MAC address (format: xx:xx:xx:xx:xx:xx)" "")
            if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                break
            else
                show_error "Invalid MAC address format. Please use format: xx:xx:xx:xx:xx:xx"
            fi
        done
    fi

    # Store the interface configuration
    eval "NET_BRIDGE_$interface_num=\"$bridge\""
    eval "NET_VLAN_$interface_num=\"$vlan\""
    eval "NET_MODEL_$interface_num=\"$model\""
    eval "NET_MAC_$interface_num=\"$mac\""

    show_success "Network interface $interface_num configured: Bridge: $bridge, Model: $model${vlan:+, VLAN: $vlan}${mac:+, MAC: $mac}"

    # Firewall
    if prompt_yes_no "Configure firewall for this interface?" "N"; then
        configure_firewall "$interface_num"
    fi
}

# Configure multiple network interfaces
configure_multiple_interfaces() {
    section_header "Multiple Network Interfaces"

    # Ask how many interfaces
    while true; do
        NET_INTERFACES=$(prompt_value "Enter number of network interfaces (1-4)" "1")
        if [[ "$NET_INTERFACES" =~ ^[0-9]+$ ]] && [ "$NET_INTERFACES" -ge 1 ] && [ "$NET_INTERFACES" -le 4 ]; then
            break
        else
            show_error "Invalid number. Please enter a number between 1 and 4."
        fi
    done

    # Configure each interface
    for (( i=0; i<$NET_INTERFACES; i++ )); do
        configure_network_interface "$i"
    done

    show_success "Configured $NET_INTERFACES network interfaces"
}

# Generate network configuration string for qm command
get_net_config_string() {
    local interface_num="$1"
    local bridge=""
    local vlan=""
    local model=""
    local mac=""

    # Get interface configuration
    eval "bridge=\$NET_BRIDGE_$interface_num"
    eval "vlan=\$NET_VLAN_$interface_num"
    eval "model=\$NET_MODEL_$interface_num"
    eval "mac=\$NET_MAC_$interface_num"

    # Default bridge if not set
    bridge="${bridge:-vmbr0}"

    # Build the config string
    local config="$model,bridge=$bridge"
    [ -n "$vlan" ] && config="$config,tag=$vlan"
    [ -n "$mac" ] && config="$config,macaddr=$mac"

    echo "$config"
}

# Generate network configuration for all interfaces
get_all_net_configs() {
    local configs=()

    for (( i=0; i<$NET_INTERFACES; i++ )); do
        configs+=("$(get_net_config_string $i)")
    done

    echo "${configs[@]}"
}

# Get IP configuration string for qm command
get_ipconfig_string() {
    local interface_num="$1"

    if [ "$interface_num" -eq 0 ]; then
        # Only configure IP for the first interface
        if [ "$NET_DHCP" = true ]; then
            echo "ip=dhcp"
        else
            local config="ip=$NET_IP/$NET_NETMASK"
            [ -n "$NET_GATEWAY" ] && config="$config,gw=$NET_GATEWAY"
            echo "$config"
        fi
    else
        # Return empty for additional interfaces (no IP config)
        echo ""
    fi
}

# Configure firewall for an interface
configure_firewall() {
    local interface_num="$1"

    section_header "Firewall Configuration for Interface $interface_num"

    # Enable firewall
    if prompt_yes_no "Enable firewall for this interface?" "N"; then
        eval "NET_FIREWALL_ENABLED_$interface_num=true"

        # Predefined security levels
        local security_levels=("High Security (Web Server)" "Medium Security (General Purpose)" "Low Security (Development)")
        show_menu "Select security level" "${security_levels[@]}"

        case $MENU_SELECTION in
            0) # High security - Web server
                # Allow only HTTP/HTTPS and SSH
                eval "NET_FIREWALL_RULES_$interface_num=\"ssh,http,https\""
                show_info "Applied High Security firewall preset:"
                show_info "- Allow SSH (port 22)"
                show_info "- Allow HTTP (port 80)"
                show_info "- Allow HTTPS (port 443)"
                ;;
            1) # Medium security - General purpose
                # Allow common services
                eval "NET_FIREWALL_RULES_$interface_num=\"ssh,http,https,dns\""
                show_info "Applied Medium Security firewall preset:"
                show_info "- Allow SSH (port 22)"
                show_info "- Allow HTTP (port 80)"
                show_info "- Allow HTTPS (port 443)"
                show_info "- Allow DNS (port 53)"
                ;;
            2) # Low security - Development
                # Allow most common ports
                eval "NET_FIREWALL_RULES_$interface_num=\"ssh,http,https,dns,smtp,imap,pop3,ftp\""
                show_info "Applied Low Security firewall preset:"
                show_info "- Allow SSH (port 22)"
                show_info "- Allow HTTP/HTTPS (ports 80/443)"
                show_info "- Allow Email (SMTP/IMAP/POP3)"
                show_info "- Allow FTP (port 21)"
                show_info "- Allow DNS (port 53)"
                ;;
        esac

        # Custom ports
        if prompt_yes_no "Add custom port rules?" "N"; then
            local custom_ports=""
            custom_ports=$(prompt_value "Enter comma-separated port numbers to allow" "")

            if [ -n "$custom_ports" ]; then
                eval "local current_rules=\$NET_FIREWALL_RULES_$interface_num"
                eval "NET_FIREWALL_RULES_$interface_num=\"$current_rules,$custom_ports\""
                show_info "Added custom ports: $custom_ports"
            fi
        fi

        show_success "Firewall configured for interface $interface_num"
    else
        eval "NET_FIREWALL_ENABLED_$interface_num=false"
    fi
}

# Suggest firewall rules based on VM type
suggest_firewall_rules() {
    local vm_type="$1"

    section_header "Firewall Recommendations"

    case "$vm_type" in
        webserver)
            show_info "Web Server Firewall Recommendations:"
            show_info "- Allow SSH (port 22) for management"
            show_info "- Allow HTTP (port 80) for web traffic"
            show_info "- Allow HTTPS (port 443) for secure web traffic"
            ;;
        database)
            show_info "Database Server Firewall Recommendations:"
            show_info "- Allow SSH (port 22) for management"
            show_info "- Allow specific database ports (e.g., MySQL: 3306, PostgreSQL: 5432)"
            show_info "- Consider restricting database access to specific IPs/subnets"
            ;;
        mailserver)
            show_info "Mail Server Firewall Recommendations:"
            show_info "- Allow SSH (port 22) for management"
            show_info "- Allow SMTP (port 25) for outgoing mail"
            show_info "- Allow IMAP (port 143/993) for mail retrieval"
            show_info "- Allow POP3 (port 110/995) for mail retrieval"
            show_info "- Allow HTTP/HTTPS (ports 80/443) for webmail interfaces"
            ;;
        fileserver)
            show_info "File Server Firewall Recommendations:"
            show_info "- Allow SSH (port 22) for management"
            show_info "- Allow SMB/CIFS (ports 139/445) for Windows file sharing"
            show_info "- Allow NFS (port 2049) for Unix/Linux file sharing"
            show_info "- Allow FTP (ports 20/21) if needed"
            ;;
        *)
            show_info "General Server Firewall Recommendations:"
            show_info "- Allow SSH (port 22) for management"
            show_info "- Only open ports for services this VM will provide"
            show_info "- Consider using a separate management network for SSH"
            ;;
    esac

    if prompt_yes_no "Apply these recommended firewall rules?" "Y"; then
        case "$vm_type" in
            webserver)
                NET_FIREWALL=true
                NET_FIREWALL_ENABLED_0=true
                NET_FIREWALL_RULES_0="ssh,http,https"
                ;;
            database)
                NET_FIREWALL=true
                NET_FIREWALL_ENABLED_0=true
                NET_FIREWALL_RULES_0="ssh,3306,5432"
                ;;
            mailserver)
                NET_FIREWALL=true
                NET_FIREWALL_ENABLED_0=true
                NET_FIREWALL_RULES_0="ssh,25,143,993,110,995,80,443"
                ;;
            fileserver)
                NET_FIREWALL=true
                NET_FIREWALL_ENABLED_0=true
                NET_FIREWALL_RULES_0="ssh,139,445,2049,20,21"
                ;;
            *)
                NET_FIREWALL=true
                NET_FIREWALL_ENABLED_0=true
                NET_FIREWALL_RULES_0="ssh"
                ;;
        esac
        show_success "Applied recommended firewall rules for $vm_type"
    fi
}

# Main network configuration function
configure_network() {
    # Configure IP settings
    configure_ip

    # Configure network interfaces
    if prompt_yes_no "Configure multiple network interfaces?" "N"; then
        configure_multiple_interfaces
    else
        NET_INTERFACES=1
        configure_network_interface 0
    fi

    show_success "Network configuration complete"
}
