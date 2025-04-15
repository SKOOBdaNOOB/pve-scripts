# Rocky Linux VM Creation Script for Proxmox

A simple, streamlined script for creating Rocky Linux VMs in Proxmox VE with cloud-init support. This script provides a straightforward way to deploy Rocky Linux cloud images with minimal effort.

## Features

- **Simple Execution**: Run with a single command
- **Default & Advanced Modes**: Choose between quick setup or detailed configuration
- **Cloud-Init Integration**: Automatic configuration of user accounts, SSH keys, and networking
- **EFI Support**: Properly configured EFI boot for modern compatibility
- **Network Configuration**: Support for both DHCP and static IP addressing
- **Storage Flexibility**: Works with various Proxmox storage types

## Quick Start

Run the script directly on your Proxmox server:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/your-repo/main/rocky-vm.sh)"
```

Or download and run locally:

```bash
wget https://raw.githubusercontent.com/your-repo/main/rocky-vm.sh
chmod +x rocky-vm.sh
./rocky-vm.sh
```

## Default Settings

When using the default mode, the script will create a VM with:

- Rocky Linux 9 cloud image
- 2 CPU cores
- 2048 MB RAM
- 32GB disk
- DHCP networking on vmbr0
- Username: rocky
- Password: rockylinux

## Advanced Configuration

The advanced mode allows you to customize:

- VM ID
- Machine type (i440fx/q35)
- Disk cache settings
- Hostname
- CPU model and core count
- RAM allocation
- Network bridge
- MAC address
- VLAN settings
- MTU size
- Cloud-init username and password
- SSH key
- Network configuration (DHCP/static)
- Auto-start option

## Requirements

- Proxmox VE 7.0+
- Root privileges
- Internet connection (to download the Rocky Linux cloud image)
- Available storage in Proxmox

## Storage Considerations

The script automatically detects available storage pools and allows you to select where to store the VM. It handles different storage types appropriately, including:

- Directory storage
- LVM
- ZFS
- NFS

## Cloud-Init Configuration

The script configures cloud-init for the VM, which allows for:

- Setting the default username and password
- Adding SSH keys for passwordless authentication
- Configuring network settings (DHCP or static IP)
- Setting DNS servers

## Troubleshooting

If you encounter issues:

1. Ensure you're running the script as root
2. Verify your Proxmox server has internet access
3. Check that you have sufficient storage space
4. For network issues, verify your bridge configuration

## Extending the Script

This script can be used as a base for creating other distribution-specific VM creation scripts. The core functionality can be adapted for Ubuntu, Debian, Fedora, or other cloud-init compatible images.

## License

MIT License
