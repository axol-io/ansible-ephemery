# Testing Guide

This document outlines the testing practices, principles, and procedures for the Ephemery Node project. Comprehensive testing is essential for ensuring reliability and stability of the system.

## Overview

The Ephemery Node testing strategy encompasses multiple levels of testing, from unit tests to integration tests to end-to-end deployment tests. This multi-layered approach helps catch issues at different stages of development.

## Molecule Testing Framework

We use Molecule for testing our Ansible roles and playbooks. Molecule provides a standardized way to test Ansible code across different environments.

### Test Structure

The tests are organized into scenarios, each with its own directory:

```bash
molecule/
├── clients/               # Client combination scenarios
│   ├── <client-pair>/     # e.g., geth-lighthouse
│   │   ├── converge.yml   # Playbook to apply the role
│   │   ├── molecule.yml   # Molecule configuration
│   │   └── verify.yml     # Tests to verify the role applied correctly
├── <special-scenario>/    # e.g., default, validator, etc.
├── shared/                # Shared resources across scenarios
└── run-tests.sh           # Helper script to run tests locally
```

### Molecule Drivers

The test infrastructure supports multiple drivers for running Molecule tests:

#### Docker Driver (Default)

By default, Molecule uses the Docker driver. The Docker socket path is automatically detected or can be specified with an environment variable:

```bash
# Use default detection (recommended)
./run-tests.sh

# Or specify a custom Docker socket path
DOCKER_HOST_SOCK="/path/to/docker.sock" ./run-tests.sh
```

#### Delegated Driver (No Docker Required)

For environments where Docker isn't available or when you want to test directly on the local system, you can use the delegated driver:

```bash
# Run tests with the delegated driver
MOLECULE_DRIVER=delegated ./run-tests.sh
```

When using the delegated driver, tests will be executed on the local machine without requiring Docker containers.

#### Converting Scenarios to Use the Delegated Driver

You can convert all Docker-based scenarios to use the delegated driver with:

```bash
./molecule/convert-to-delegated.sh
```

This script will:
1. Create backups of your existing molecule.yml files
2. Replace them with delegated driver configurations
3. Preserve your test logic while changing only the execution environment

### Running Tests Locally

To run tests locally:

```bash
# Run all tests with the default driver
./molecule/run-tests.sh

# Run a specific test scenario
./molecule/run-tests.sh <scenario-name>

# Run tests with the delegated driver
MOLECULE_DRIVER=delegated ./molecule/run-tests.sh
```

### CI/CD Integration

Our GitHub Actions workflow automatically runs Molecule tests on pull requests and pushes to main branches. See the [CI/CD documentation](./CI_CD.md) for more details.

## Test Verification

The verification phase checks that:

1. Required services are running
2. Necessary ports are open
3. Configuration files exist and have correct permissions
4. Components can communicate with each other

## Troubleshooting Tests

If tests fail, check:

1. Docker is running and accessible (if using Docker driver)
2. The Docker socket is available at the expected location
3. You have sufficient permissions to access the Docker socket
4. For Mac users: ensure Docker Desktop is running and properly configured
5. For environments without Docker: use the delegated driver instead

If you encounter Docker-related issues, try:
1. Using the delegated driver: `MOLECULE_DRIVER=delegated ./run-tests.sh`
2. Specifying a custom Docker socket path: `DOCKER_HOST_SOCK="/path/to/docker.sock" ./run-tests.sh`
3. Running with increased verbosity: `MOLECULE_VERBOSITY=2 ./run-tests.sh`

## Related Documents

- [Development Setup](./DEVELOPMENT_SETUP.md)
- [Contributing](./CONTRIBUTING.md)
- [Troubleshooting](./TROUBLESHOOTING.md)
- [CI/CD](./CI_CD.md)

*Note: This document is a placeholder based on the existing TESTING.md file and will be fully migrated with comprehensive content in a future update.*
