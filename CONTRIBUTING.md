# Contributing to Proxmox VM Template Wizard

Thank you for your interest in contributing to the Proxmox VM Template Wizard! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Documentation](#documentation)
- [Project Priorities](#project-priorities)
- [Communication](#communication)

## Code of Conduct

Please be respectful and considerate in all interactions. We aim to foster an inclusive and welcoming community.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Add the original repository as an upstream remote
4. Create a branch for your changes

```bash
# Fork on GitHub first, then:
git clone https://github.com/YOUR-USERNAME/pve-scripts.git
cd pve-scripts
git remote add upstream https://github.com/SKOOBdaNOOB/pve-scripts.git
git checkout -b feature/your-feature-name
```

## Development Environment

### Prerequisites

- Bash 4.0+
- A Proxmox VE environment (or a simulated environment for testing)
- Git

### Setup

1. Make script files executable:
   ```bash
   chmod +x bin/pve-template-wizard.sh
   chmod +x tests/run_tests.sh
   ```

2. Set up test environment:
   ```bash
   chmod +x tests/unit/*.sh tests/integration/*.sh tests/mock/*.sh
   ```

## Testing

All contributions should include tests to ensure functionality and prevent regressions.

### Running Tests

```bash
# Run all tests
./tests/run_tests.sh

# Run only unit tests
./tests/run_tests.sh unit

# Run only integration tests
./tests/run_tests.sh integration
```

### Writing Tests

- **Unit Tests**: Place in `tests/unit/` directory with a descriptive name (e.g., `network_validation_tests.sh`)
- **Integration Tests**: Place in `tests/integration/` directory
- Use the provided testing framework with `assert_equals` and `assert_return_code` functions
- Mock functions are available in `tests/mock/mock_functions.sh`

Example of a test function:

```bash
test_validate_ip_address() {
    # Test valid IP
    validate_ip_address "192.168.1.1"
    assert_return_code 0 $? "Valid IP should be accepted"

    # Test invalid IP
    validate_ip_address "300.168.1.1"
    assert_return_code 1 $? "Invalid IP should be rejected"
}
```

## Submitting Changes

1. Ensure your code passes all tests
2. Update documentation if needed
3. Update the `template-wizard-improvements.md` checklist if you've implemented a feature
4. Commit your changes with clear, descriptive messages
5. Push to your fork
6. Create a Pull Request

### Commit Messages

Write clear commit messages that explain the what and why of your changes. Format:

```
Component: Brief description of change

More detailed explanation if needed.

Resolves: #issue-number (if applicable)
```

## Pull Request Process

1. Create a pull request from your feature branch to the original repository's main branch
2. Fill out the pull request template with all required information
3. Wait for the automated tests to pass
4. Respond to any feedback or review comments
5. Once approved, your changes will be merged

## Coding Standards

### Bash Style

- Use 4 spaces for indentation
- Use meaningful variable and function names
- Add comments to explain complex logic
- Quote variables using double quotes where appropriate
- Use `[[ ]]` for condition testing rather than `[ ]`
- Prefix function-local variables with `local`

### File Organization

- Keep files organized according to the project structure
- Place new functionality in the appropriate module directory
- Create new modules when functionality doesn't fit existing categories

## Documentation

- Update README.md for user-facing changes
- Document functions with comments describing:
  - Purpose
  - Parameters
  - Return values
  - Examples (if helpful)
- Keep documentation in sync with code changes

## Project Priorities

The `template-wizard-improvements.md` file contains a checklist of planned improvements. Please refer to this document to understand project priorities and to mark off completed items.

## Communication

- Use GitHub Issues for bug reports, feature requests, and discussions
- Tag issues appropriately (bug, enhancement, question, etc.)
- For major changes, please open an issue first to discuss what you would like to change

Thank you for contributing to the Proxmox VM Template Wizard!
