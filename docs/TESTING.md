# Testing Framework

This document provides information about the testing framework used in the ansible-ephemery project.

## Overview

The ansible-ephemery project uses [Molecule](https://molecule.readthedocs.io/) for testing. The framework:

1. Verifies functionality across different client combinations
2. Tests specific features (backup, monitoring, security)
3. Validates resource constraints and performance
4. Ensures consistent behavior across environments

## Prerequisites

- Python 3.11+ (recommended)
- Docker running on the local machine
- Required Python packages (install with `pip install -r requirements.txt -r requirements-dev.txt`)

## Test Organization

Tests are organized into scenarios within the `molecule/` directory:

```bash
molecule/
├── [client-scenarios]/   # Client combination scenarios
├── clients/              # Client combination templates
├── default/              # Default scenario
├── backup/               # Backup functionality tests
├── monitoring/           # Monitoring functionality tests
├── resource-limits/      # Resource limitation tests
├── security/             # Security configuration tests
├── validator/            # Validator functionality tests
└── shared/               # Shared resources
```

## Running Tests

### Quick Demo

```bash
# Create, test, and clean up automatically
molecule/shared/scripts/demo_scenario.sh --execution geth --consensus prysm

# Keep the scenario after testing
molecule/shared/scripts/demo_scenario.sh -e nethermind -c lodestar --keep
```

### macOS Compatibility

For macOS users with Docker Desktop, we provide a dedicated helper script to resolve common Docker connectivity issues:

```bash
# Run a specific scenario on macOS
./scripts/run-molecule-tests-macos.sh default

# Run client combination scenario on macOS
./scripts/run-molecule-tests-macos.sh geth-lighthouse
```

This script:

- Automatically detects the correct Docker socket path on macOS
- Updates the molecule.yml configuration with the correct path
- Sets the necessary environment variables
- Handles the different `sed` syntax in macOS
- Restores original configuration after testing

### Creating and Running Specific Scenarios

To create a test scenario:

```bash
# Client combination scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution geth --consensus lighthouse

# Custom scenario
molecule/shared/scripts/generate_scenario.sh --type custom --name high-memory --var memory=8192M --var cpu=2.0
```

To run a scenario:

```bash
# Run full test sequence
molecule test -s geth-lighthouse

# Run only converge step
molecule converge -s geth-lighthouse

# Run only verify step
molecule verify -s geth-lighthouse
```

### Temporary Scenarios and Cleanup

For testing without cluttering your workspace:

```bash
# Create temporary scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution geth --consensus prysm --temp

# Clean up when finished
molecule/shared/scripts/generate_scenario.sh --cleanup geth-prysm
```

## Test Lifecycle

Each Molecule test progresses through these phases:

1. **Dependency**: Pull required dependencies
2. **Create**: Create test infrastructure (Docker containers)
3. **Prepare**: Prepare infrastructure for testing
4. **Converge**: Apply the Ansible role
5. **Verify**: Run verification tests
6. **Cleanup**: Clean up test resources
7. **Destroy**: Destroy test infrastructure

## Test Matrix

The following client combinations are tested:

| Execution Client | Consensus Client | Status |
|------------------|------------------|--------|
| geth             | lighthouse       | ✅     |
| geth             | prysm           | ✅     |
| geth             | teku            | ✅     |
| geth             | lodestar        | ✅     |
| nethermind       | lighthouse      | ✅     |
| nethermind       | prysm           | ✅     |
| nethermind       | teku            | ✅     |
| nethermind       | lodestar        | ✅     |
| besu             | lighthouse      | ✅     |
| besu             | prysm           | ✅     |
| besu             | teku            | ✅     |
| besu             | lodestar        | ✅     |
| reth             | lighthouse      | ✅     |
| reth             | prysm           | ✅     |
| reth             | teku            | ✅     |
| reth             | lodestar        | ✅     |
| erigon           | lighthouse      | ✅     |
| erigon           | prysm           | ✅     |
| erigon           | teku            | ✅     |
| erigon           | lodestar        | ✅     |

## Feature Tests

In addition to client combinations, we test specific features:

| Feature          | Description                                  | Scenario           |
|------------------|----------------------------------------------|-------------------|
| Backup           | Tests backup functionality                    | `backup/`         |
| Monitoring       | Tests monitoring stack                       | `monitoring/`     |
| Resource Limits  | Tests with different resource constraints    | `resource-limits/` |
| Security         | Tests security configurations                | `security/`       |
| Validator        | Tests validator node setup                   | `validator/`      |

## Verification Tests

Each scenario includes verification tests that check:

1. **Service Health**: Verifying that services are running correctly
2. **Network Connectivity**: Checking network connectivity between clients
3. **Configuration**: Validating that configuration files are correct
4. **Resource Usage**: Checking resource usage is within expected bounds
5. **Client-Specific Checks**: Tests specific to each client combination

## CI/CD Integration

Our tests are integrated with the CI/CD pipeline. For details, see [CI_CD_UPDATES.md](CI_CD_UPDATES.md).

The CI pipeline runs:

- Basic tests on every PR
- Client matrix tests on merge to main
- Full test suite on a scheduled basis

## Extending the Testing Framework

### Creating a New Scenario Type

To create a new type of test scenario:

1. Add templates to `molecule/shared/templates/`
2. Update `generate_scenario.sh` to support the new type
3. Document the new scenario type

### Customizing Verification Tests

To add custom verification tests:

1. Create verification tasks in your scenario's `verify.yml`
2. For reusable tests, add them to the shared templates

## Troubleshooting

### Common Issues

#### Docker Connectivity on macOS

```bash
Error while fetching server API version: ('Connection aborted.', FileNotFoundError(2, 'No such file or directory'))
```

**Solution**: Use our macOS helper script instead of running molecule directly:

```bash
./scripts/run-molecule-tests-macos.sh <scenario-name>
```

#### Ansible Conditional Errors

```bash
The conditional check 'docker.service in ansible_facts.services' failed. The error was: error while evaluating conditional (docker.service in ansible_facts.services): 'docker' is undefined
```

**Solution**: Always use quotes for string literals in conditionals and check for definition:

```yaml
# Incorrect
when: docker.service in ansible_facts.services

# Correct
when: "'docker.service' in ansible_facts.services"

# Even better
when: ansible_facts.services is defined and "'docker.service' in ansible_facts.services"
```

#### Missing Quotes in Default Values

```bash
The error appears to be in '...': line XX, column 3, but may be elsewhere in the file depending on the exact syntax problem.
```

**Solution**: Always quote string values in default() filters:

```yaml
# Incorrect
ephemery_base_dir | default(/home/ubuntu/ephemery)

# Correct
ephemery_base_dir | default("/home/ubuntu/ephemery")
```

#### Docker Not Running

```bash
Error while fetching server API version: ('Connection aborted.', FileNotFoundError(2, 'No such file or directory'))
```

Solution: Start Docker Desktop or the Docker daemon.

#### Missing Molecule.yml

```bash
CRITICAL 'molecule/scenario-name/molecule.yml' glob failed. Exiting.
```

Solution: Ensure the scenario directory exists and has a correctly structured `molecule.yml` file.

#### Python Environment Issues

If you encounter Python module errors, ensure all dependencies are installed:

```bash
pip install -r requirements.txt -r requirements-dev.txt
```

For Python version issues, ensure you're using Python 3.11+.

## Best Practices

1. **Keep Tests Focused**: Each test should focus on a specific aspect
2. **Clean Up After Testing**: Use temporary scenarios or clean up after tests
3. **Parameterize Tests**: Use variables rather than hardcoding values
4. **Test All Client Combinations**: Ensure all supported client combinations are tested
5. **Verify All Key Functionality**: Include verification for all critical functionality
6. **Proper Conditionals**: Always use quotes for string literals in conditionals
7. **Check Dictionary Keys**: Always check if a dictionary key exists before accessing it
8. **Quote Default Values**: Always use quotes for string values in default() filters
9. **Use Helper Scripts**: Use platform-specific helper scripts (like our macOS script)
10. **Pre-commit Validation**: Run `./scripts/verify-ansible-conditionals.sh` to check for common issues

## Verification Task Best Practices

When writing verification tasks, follow these guidelines to avoid common pitfalls:

### String Literals in Conditionals

```yaml
# Good
when: "'docker.service' in ansible_facts.services"

# Bad
when: docker.service in ansible_facts.services
```

### Existence Checks

```yaml
# Good
when: ansible_facts.services is defined and "'docker.service' in ansible_facts.services"

# Bad
when: "'docker.service' in ansible_facts.services"
```

### Default Values

```yaml
# Good
ephemery_base_dir | default("/home/ubuntu/ephemery")

# Bad
ephemery_base_dir | default(/home/ubuntu/ephemery)
```

### Consistent Formatting

```yaml
# Good
when: >
  ansible_facts.services is defined and
  "'docker.service' in ansible_facts.services" and
  docker_containers.rc == 0

# Bad
when: ansible_facts.services is defined and "'docker.service' in ansible_facts.services" and docker_containers.rc == 0
```

## Future Enhancements

Planned improvements to our testing framework:

1. **Matrix Testing**: Enhanced testing across multiple OS versions
2. **Parallelization**: Improved parallel test execution
3. **Test Reporting**: Better visualization of test results
4. **Integration Testing**: Expanded integration test coverage with other systems
