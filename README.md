# Proxmox VM Template Creation Wizard

A modular, feature-rich tool for creating and managing VM templates in Proxmox VE. This project enhances the template creation workflow with comprehensive validation, intelligent defaults, and advanced management options.

## Features

- **Comprehensive Input Validation**: Validates IP addresses, paths, resources, and hostnames
- **Advanced Storage Management**: Storage pool selection, custom disk paths, and flexible configuration
- **Enhanced Network Setup**: Support for VLANs, multiple interfaces, and firewall rule suggestions
- **Template Management**: List, modify, delete, and clone templates with safeguards
- **Batch Operations**: Create multiple templates or VMs in a single operation
- **Resource Allocation Controls**: Fine-grained CPU and memory configuration
- **Configuration Profiles**: Save and load named profiles for repeated use
- **Robust Error Handling**: Detailed error messages, input validation feedback, and recovery mechanisms
- **Security Enhancements**: Secure configuration storage and SSH key management
- **Automated Testing**: Comprehensive unit and integration test suite with CI/CD integration

## Prerequisites

- Proxmox VE 7.0+ environment
- Bash 4.0+
- Required commands: `qm`, `pvesh`, `wget`, `sha256sum`
- Root privileges (for full functionality)

## Installation

### Option 1: Quick Install (No Git Required)

Run the following command on your Proxmox server:

```bash
curl -sSL https://raw.githubusercontent.com/SKOOBdaNOOB/pve-scripts/main/bootstrap/template-wizard.sh | bash
```

This will download and run the script without installing anything permanently.

### Option 2: Full Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/SKOOBdaNOOB/pve-scripts.git
   cd pve-scripts
   ```

2. Make the main script executable:
   ```bash
   chmod +x bin/pve-template-wizard.sh
   ```

3. Run the script:
   ```bash
   ./bin/pve-template-wizard.sh
   ```

## Usage

### Creating a New Template

1. Select "Create New Template" from the main menu
2. Choose your Linux distribution from the available options
3. Configure storage, resources, network, and cloud-init settings
4. Review settings and confirm to create the template

Example:
```bash
# Run the wizard
./bin/pve-template-wizard.sh

# Select option 1 for "Create New Template"
# Select Ubuntu 23.04 from the distribution list
# Configure with 2 vCPUs, 2GB RAM, 20GB disk
# Set cloud-init username and password
# Review and confirm creation
```

### Cloning from a Template

1. Select "Clone from Template" from the main menu
2. Choose a template from the list of available templates
3. Enter a name for the new VM
4. The VM will be created and started automatically

Example:
```bash
# Run the wizard
./bin/pve-template-wizard.sh

# Select option 2 for "Clone from Template"
# Select your template from the list
# Enter "web-server-01" as the VM name
# The new VM will be created from the template
```

### Managing Templates

1. Select "Manage Templates" from the main menu
2. Choose to modify or delete a template
3. For modifications, select which aspect to modify (resources, cloud-init, network)
4. Changes are applied while preserving the template status

### Batch Operations

1. Select "Batch Operations" from the main menu
2. Choose between creating multiple templates, cloning to multiple VMs, or deleting multiple templates
3. Configure the batch operation parameters
4. Review and execute the batch operation

## Project Structure

```
pve-scripts/
├── bin/
│   └── pve-template-wizard.sh     # Main executable script
├── lib/
│   ├── core/                      # Core functionality modules
│   │   ├── ui.sh                  # User interface elements
│   │   ├── config.sh              # Configuration management
│   │   ├── logging.sh             # Logging system
│   │   └── validation.sh          # Input validation
│   ├── distributions/             # Distribution-specific modules
│   │   └── distro_info.sh         # Linux distribution information
│   ├── storage/                   # Storage management modules
│   │   └── storage.sh             # Storage pool and disk management
│   ├── network/                   # Network configuration modules
│   │   └── network.sh             # Network setup and validation
│   └── vm/                        # VM and template operations
│       └── vm.sh                  # VM creation and template management
├── config/                        # Configuration file storage
├── docs/                          # Documentation
└── tests/                         # Test files
    ├── run_tests.sh               # Test runner script
    ├── mock/                      # Mock functions for testing
    ├── unit/                      # Unit tests
    └── integration/               # Integration tests
```

## Configuration

The wizard automatically creates configuration files in the following locations:

- Main configuration: `$HOME/.pve-template-wizard.conf`
- Profiles: `$HOME/.pve-template-wizard/profiles/`
- Logs: `$HOME/.pve-template-wizard/logs/wizard.log`

## Supported Linux Distributions

- Alma Linux 9
- Amazon Linux 2
- CentOS 9 Stream
- Fedora 38
- Oracle Linux 9
- Rocky Linux 9
- Ubuntu 23.04 Lunar Lobster

## Advanced Features

### Custom Cloud-init Configuration

The wizard allows for advanced cloud-init configuration, including:

- Custom user data scripts
- SSH key management
- Network configuration
- Package installation
- Service configuration

To use custom cloud-init configuration:

1. Select "Create New Template" or "Modify Template"
2. Navigate to the cloud-init configuration section
3. Choose "Advanced Configuration"
4. Enter your custom cloud-init data or specify a file path

### Resource Allocation Options

Fine-grained control over VM resources:

- CPU type selection (host, kvm64, etc.)
- CPU flags (AES, AVX, etc.)
- Memory management (ballooning, shares)
- CPU pinning options
- NUMA configuration

### Network Configuration

Advanced network setup options:

- Multiple network interfaces
- VLAN tagging
- Bridge configuration
- Firewall rule suggestions
- Custom MAC addresses

## Testing

The project includes a comprehensive test suite:

```bash
# Run all tests
./tests/run_tests.sh

# Run only unit tests
./tests/run_tests.sh unit

# Run only integration tests
./tests/run_tests.sh integration
```

## Troubleshooting

### Common Issues

- **Permission Denied**: Ensure you're running with sufficient privileges
  ```bash
  sudo ./bin/pve-template-wizard.sh
  ```

- **Missing Dependencies**: Install required packages
  ```bash
  apt-get install wget curl qemu-guest-agent
  ```

- **Download Errors**: Check your internet connection and ensure the Proxmox server can reach external sites

- **Storage Issues**: Verify your storage pools are properly configured in Proxmox

### Logs

Check the logs for detailed error information:
```bash
cat $HOME/.pve-template-wizard/logs/wizard.log
```

## Contributing

Contributions to the Proxmox VM Template Wizard are welcome! Please follow these guidelines:

### Getting Started

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run the tests to ensure nothing broke (`./tests/run_tests.sh`)
5. Commit your changes (`git commit -m 'Add some amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Standards

- Follow the existing code style
- Write descriptive commit messages
- Update documentation for any new features
- Add tests for new functionality
- Check the template-wizard-improvements.md checklist for project priorities

### Testing

All code should be tested:

1. Write unit tests for individual functions
2. Add integration tests for new workflows
3. Ensure all existing tests pass before submitting pull requests

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- The Proxmox community for inspiration and support
- Contributors who have helped improve this tool
- Open source projects that made this possible
