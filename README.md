# Linux Cloudinit VM Creation Scripts for Proxmox

This is a handy script for spinning up Rocky Linux VMs in Proxmox VE with cloud-init support. Inspired by the infamous [haos-vm.sh](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/vm/haos-vm.sh) in [@community-scripts](https://github.com/community-scripts/ProxmoxVE) **ProxmoxVE**  repo. Wanted something simple that could be replicated for all kinds of Linux distro's generic cloud images.

## Features

- **Cloud-Init ready** - Sets up user accounts, SSH keys, and networking automatically
- **Run it and forget it** - Just one command to get things rolling
- **Modern boot support** - Properly configured EFI boot so everything plays nice
- **Flexible networking** - DHCP for simplicity or static IPs when you need them
- **Storage that works** - Compatible with whatever Proxmox storage you've got handy

## Quick Start (Rocky9 Example)

Run the script directly on your Proxmox server:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/SKOOBdaNOOB/pve-scripts/main/rocky-vm.sh)"
```

Or download and run locally:

```bash
wget https://raw.githubusercontent.com/SKOOBdaNOOB/pve-scripts/main/rocky-vm.sh
chmod +x rocky-vm.sh
./rocky-vm.sh
```

## Default Settings

When you go with the default mode, you'll get a VM with:

- Rocky Linux 9 cloud image
- 2 CPU cores
- 2048 MB RAM
- 32GB disk
- DHCP networking on vmbr0
- Username: rocky
- Password: rockylinux

## Advanced Configuration

Want to customize things? The advanced mode lets you tweak:

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

You'll need:
- Proxmox VE 7.0 or newer
- Root access
- Internet connection to grab the Rocky Linux cloud image
- Some free storage space in Proxmox

## Storage Considerations

Don't worry about storage types - the script has you covered! It'll detect what you have available and handle the details for:

- Directory storage
- LVM
- ZFS
- NFS

## Cloud-Init Configuration

The script takes care of cloud-init setup, so you can:

- Set your preferred username and password
- Add your SSH keys for passwordless login
- Configure networking just how you like it
- Set up your DNS servers

## Troubleshooting

Running into issues? Here are some quick fixes:

1. Make sure you're running as root
2. Check that your Proxmox server can reach the internet
3. Verify you've got enough storage space
4. For network hiccups, double-check your bridge setup

## Extending the Script

Feel free to use this script as a starting point for other distros! The core functionality works great for Ubuntu, Debian, Fedora, or any other cloud-init compatible images. And check out []

## License

GNU GENERAL PUBLIC LICENSE
