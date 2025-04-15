#!/bin/bash

# Make scripts executable
chmod +x rocky-vm.sh
chmod +x ubuntu-vm.sh

echo "Scripts are now executable."
echo ""
echo "To create a Rocky Linux VM, run:"
echo "  ./rocky-vm.sh"
echo ""
echo "To create an Ubuntu VM, run:"
echo "  ./ubuntu-vm.sh"
echo ""
echo "Or run them directly on your Proxmox server with:"
echo "  bash -c \"\$(wget -qLO - https://raw.githubusercontent.com/pve-scripts/main/rocky-vm.sh)\""
echo "  bash -c \"\$(wget -qLO - https://raw.githubusercontent.com/pve-scripts/main/ubuntu-vm.sh)\""
