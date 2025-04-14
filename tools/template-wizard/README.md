# Proxmox VM Template Wizard - Self-contained Version

This is a standalone version of the Proxmox VM Template Wizard that can be run directly without requiring the full repository structure. It contains all the necessary functionality to create, manage, and clone VM templates in Proxmox.

## Features

- Create templates from various Linux distributions
- Clone VMs from templates
- Modify template settings
- Delete templates
- Batch operations for multiple template/VM management
- Configuration profiles for frequently used settings

## Usage

1. Make the script executable:
   ```bash
   chmod +x run.sh
   ```

2. Run the script:
   ```bash
   ./run.sh
   ```

Note: This script should be run on a Proxmox VE server. It requires root privileges for full functionality.

## Requirements

- Proxmox VE 7.0+
- Bash 4.0+
- Required commands: `qm`, `pvesh`, `wget`, `sha256sum`

## Configuration

The script creates configuration files in the following locations:

- Main configuration: `$HOME/.pve-template-wizard.conf`
- Profiles: `$HOME/.pve-template-wizard/profiles/`

## One-line Execution

You can also run this script directly from GitHub without downloading the repository:

```bash
curl -sSL https://raw.githubusercontent.com/SKOOBdaNOOB/pve-scripts/main/bootstrap/template-wizard.sh | bash
```

This will download and run the script in a temporary directory, with no installation required.
