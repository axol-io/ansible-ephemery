---
title: Molecule Testing for Ansible-Ephemery
---

# Molecule Testing Framework for Ansible-Ephemery

This directory contains the Molecule testing infrastructure for the ansible-ephemery role. It provides a structured approach to testing various client combinations and configurations.

## Directory Structure

```
molecule/
├── [client-scenarios]/      # Client combination scenarios (e.g., geth-prysm)
├── clients/                 # Client combination test templates
├── default/                 # Main scenario with default clients
├── backup/                  # Backup functionality testing
├── monitoring/              # Monitoring functionality testing
├── resource-limits/         # Resource limitation testing
├── security/                # Security configuration testing
├── validator/               # Validator node testing
├── shared/                  # Shared resources across scenarios
│   ├── scripts/             # Utility scripts
│   │   ├── generate_scenario.sh  # Script for generating new scenarios
│   │   └── demo_scenario.sh      # Script for demo scenarios (create, test, clean up)
│   └── templates/           # Templates for scenario generation
├── README.md                # This file
├── requirements.yml         # Dependencies for tests
├── run-tests.sh             # Wrapper script for running tests
└── cleanup.yml              # Cleanup playbook
```

## Quick Start

### Running a Demo Test

To quickly demonstrate a working scenario without cluttering your environment:

```bash
# Create a scenario, run tests, and clean up automatically
molecule/shared/scripts/demo_scenario.sh --execution geth --consensus prysm

# Create and test a scenario, but keep it after testing
molecule/shared/scripts/demo_scenario.sh -e nethermind -c lodestar --keep
```

### Creating a Scenario

You can create test scenarios for different client combinations or custom configurations:

```bash
# Create a client combination scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution geth --consensus lighthouse

# Create a temporary scenario that can be easily cleaned up
molecule/shared/scripts/generate_scenario.sh --type clients --execution nethermind --consensus lodestar --temp

# Create a custom scenario
molecule/shared/scripts/generate_scenario.sh --type custom --name high-memory --var memory=8192M --var cpu=2.0
```

### Cleaning Up Scenarios

To clean up a scenario after testing:

```bash
# Clean up a previously created scenario
molecule/shared/scripts/generate_scenario.sh --cleanup geth-lighthouse
```

### Running Tests

To run tests on a specific scenario:

```bash
# Run the full test sequence
molecule test -s geth-lighthouse

# Run only the converge step (for development)
molecule converge -s geth-lighthouse

# Run only the verify step
molecule verify -s geth-lighthouse
```

## Scenario Types

### Client Combination Scenarios

These scenarios test specific execution and consensus client combinations:

```bash
# Create a client combination scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution geth --consensus lighthouse
```

Each client scenario includes:
- Configuration for the specific client combination
- Client-specific verification tests
- Resource allocation appropriate for the client pair

### Custom Scenarios

These scenarios test specific configurations or features:

```bash
# Create a custom scenario
molecule/shared/scripts/generate_scenario.sh --type custom --name high-memory --var memory=8192M --var cpu=2.0
```

Custom scenarios can test:
- Resource limitations
- Security configurations
- Backup functionality
- Monitoring setups
- Validator configurations

## Advanced Usage

### Temporary Scenarios

For demonstration or quick testing, create temporary scenarios that can be easily cleaned up:

```bash
# Create a temporary scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution geth --consensus prysm --temp

# Clean up when finished
molecule/shared/scripts/generate_scenario.sh --cleanup geth-prysm
```

### Demo Script

The demo script provides a convenient way to create, test, and clean up a scenario in one command:

```bash
# Run the full process: create, test, clean up
molecule/shared/scripts/demo_scenario.sh --execution geth --consensus prysm

# Run the process but keep the scenario afterward
molecule/shared/scripts/demo_scenario.sh -e nethermind -c lodestar --keep
```

## Scenario Structure

Each scenario directory contains:

- `molecule.yml`: Configuration for the scenario
- `converge.yml`: Playbook to apply the role
- `verify.yml`: Tests to verify the configuration

## Best Practices

1. **Keep scenarios minimal**: Only include what's different from the default configuration.
2. **Use temporary scenarios** for quick tests and demos to avoid cluttering your workspace.
3. **Clean up after testing** to maintain a clean testing environment.
4. **Standardize verification** to ensure consistent testing across scenarios.
5. **Parameterize tests** to test various configurations without duplicating code.

## Troubleshooting

### Common Issues

#### Molecule Can't Find Scenario

```
CRITICAL 'molecule/scenario-name/molecule.yml' glob failed. Exiting.
```

Ensure the scenario directory exists and is correctly structured.

#### Docker Connection Issues

```
Error while fetching server API version: ('Connection aborted.', FileNotFoundError(2, 'No such file or directory'))
```

Make sure Docker is running before executing Molecule tests.

#### Python Environment Issues

If you encounter Python module errors, ensure all dependencies are installed:

```bash
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

## Test Coverage

Our test framework covers:

1. **Client Compatibility**: Testing various execution and consensus client combinations
2. **Resource Management**: Testing with different resource limits
3. **Security**: Testing with various security configurations
4. **Backup & Recovery**: Testing backup functionality
5. **Monitoring**: Testing monitoring implementations
6. **Validator**: Testing validator node configurations

For detailed information about the verification tests performed in each scenario, see [VERIFICATION_TESTS.md](VERIFICATION_TESTS.md).

## CI/CD Integration

Molecule tests are integrated with our CI/CD pipeline to ensure consistent testing on all changes:

1. **Pull Request Testing**: Basic scenarios run on all PRs
2. **Scheduled Testing**: Comprehensive testing runs on a schedule
3. **Release Testing**: All scenarios tested before releases

## Contributing New Scenarios

When contributing new scenarios:

1. Follow the established pattern for scenario files
2. Include clear verification steps specific to your scenario
3. Document any unusual configurations or requirements
4. Use the provided generator scripts to ensure consistency

## Future Enhancements

Planned improvements to our testing framework:

1. **Matrix Testing**: Enhanced testing across multiple OS versions
2. **Parallelization**: Improved parallel test execution
3. **Test Reporting**: Better visualization of test results
4. **Integration Testing**: Expanded integration test coverage with other systems
