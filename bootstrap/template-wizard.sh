#!/bin/bash
#
# Proxmox VM Template Wizard Bootstrap
# Run directly with: curl -sSL https://raw.githubusercontent.com/SKOOBdaNOOB/pve-scripts/main/bootstrap/template-wizard.sh | bash
#

set -e  # Exit on any error

# Configuration
REPO_URL="https://raw.githubusercontent.com/SKOOBdaNOOB/pve-scripts/main"
TEMP_DIR=$(mktemp -d)
CLEANUP_ON_EXIT=true

# Text formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

echo -e "${BLUE}${BOLD}Proxmox VM Template Wizard${RESET}"
echo -e "${BLUE}===========================${RESET}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}⚠ This script should be run as root for full functionality.${RESET}"
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Exiting.${RESET}"
        exit 1
    fi
fi

# Check for required commands
echo -e "${BLUE}Checking prerequisites...${RESET}"
required_commands=("qm" "pvesh" "wget" "sha256sum")
missing_commands=()

for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        missing_commands+=("$cmd")
    fi
done

if [ ${#missing_commands[@]} -gt 0 ]; then
    echo -e "${RED}✗ Missing required commands: ${missing_commands[*]}${RESET}"
    echo -e "${BLUE}ℹ Please install the required packages and try again.${RESET}"
    exit 1
else
    echo -e "${GREEN}✓ All required commands are available.${RESET}"
fi

# Check if running on a Proxmox server
if [ ! -f "/etc/pve/qemu-server" ] && [ ! -d "/etc/pve" ]; then
    echo -e "${YELLOW}⚠ This doesn't appear to be a Proxmox server.${RESET}"
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Exiting.${RESET}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Running on a Proxmox server.${RESET}"
fi

# Download required files
echo -e "${BLUE}Downloading required files...${RESET}"

# Function to download a file
download_file() {
    local path=$1
    local output_file=$2
    echo -e "  ${YELLOW}Downloading ${path}...${RESET}"

    if ! wget -q "$REPO_URL/$path" -O "$output_file"; then
        echo -e "${RED}✗ Failed to download $path${RESET}"
        return 1
    fi

    return 0
}

# Create directories
mkdir -p "$TEMP_DIR/lib/core"
mkdir -p "$TEMP_DIR/lib/distributions"
mkdir -p "$TEMP_DIR/lib/storage"
mkdir -p "$TEMP_DIR/lib/network"
mkdir -p "$TEMP_DIR/lib/vm"

# Download core library files
echo -e "${BLUE}Downloading core library files...${RESET}"
download_file "lib/core/ui.sh" "$TEMP_DIR/lib/core/ui.sh"
download_file "lib/core/logging.sh" "$TEMP_DIR/lib/core/logging.sh"
download_file "lib/core/config.sh" "$TEMP_DIR/lib/core/config.sh"
download_file "lib/core/validation.sh" "$TEMP_DIR/lib/core/validation.sh"

# Download module files
echo -e "${BLUE}Downloading module files...${RESET}"
download_file "lib/distributions/distro_info.sh" "$TEMP_DIR/lib/distributions/distro_info.sh"
download_file "lib/storage/storage.sh" "$TEMP_DIR/lib/storage/storage.sh"
download_file "lib/network/network.sh" "$TEMP_DIR/lib/network/network.sh"
download_file "lib/vm/vm.sh" "$TEMP_DIR/lib/vm/vm.sh"

# Download main script
echo -e "${BLUE}Downloading main script...${RESET}"
mkdir -p "$TEMP_DIR/bin"
download_file "bin/pve-template-wizard.sh" "$TEMP_DIR/bin/pve-template-wizard.sh"
chmod +x "$TEMP_DIR/bin/pve-template-wizard.sh"

# Set up trap for cleanup
if [ "$CLEANUP_ON_EXIT" = true ]; then
    trap 'echo -e "${BLUE}Cleaning up temporary files...${RESET}"; rm -rf "$TEMP_DIR"' EXIT
fi

# Run the template wizard
echo -e "${GREEN}Starting Proxmox VM Template Wizard...${RESET}"
cd "$TEMP_DIR"
"$TEMP_DIR/bin/pve-template-wizard.sh" "$@"

echo -e "\n${GREEN}${BOLD}Thank you for using the Proxmox VM Template Wizard!${RESET}"
echo -e "${BLUE}If you'd like to install this tool permanently, clone the repository:${RESET}"
echo -e "  git clone https://github.com/SKOOBdaNOOB/pve-scripts.git"
