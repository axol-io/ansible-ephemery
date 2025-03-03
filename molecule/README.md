---
title: Molecule Testing for Ansible-Ephemery
---

# Molecule Testing Framework for Ansible-Ephemery

This directory contains the Molecule testing infrastructure for the ansible-ephemery role.

## Directory Structure

```plaintext
molecule/
├── [client-scenarios]/   # Client combination scenarios
├── clients/              # Client combination templates
├── default/              # Main scenario with default clients
├── backup/               # Backup functionality testing
├── monitoring/           # Monitoring functionality testing
├── resource-limits/      # Resource limitation testing
├── security/             # Security configuration testing
├── validator/            # Validator node testing
├── shared/               # Shared resources across scenarios
│   ├── scripts/          # Utility scripts
│   │   ├── generate_scenario.sh  # Scenario generator
│   │   └── demo_scenario.sh      # Demo scenario runner
│   └── templates/        # Templates for scenario generation
├── README.md             # This file
└── requirements.yml      # Dependencies for tests
```

## Quick Start

### Running a Demo Test

```bash
# Create, test, and clean up automatically
molecule/shared/scripts/demo_scenario.sh --execution geth --consensus prysm

# Keep the scenario after testing
molecule/shared/scripts/demo_scenario.sh -e nethermind -c lodestar --keep
```

### Creating a Scenario

```bash
# Create a client combination scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution geth --consensus lighthouse

# Create a temporary scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution nethermind --consensus lodestar --temp

# Create a custom scenario
molecule/shared/scripts/generate_scenario.sh --type custom --name high-memory --var memory=8192M --var cpu=2.0
```

### Running Tests

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

Test specific execution and consensus client combinations:

```bash
# Create a client combination scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution geth --consensus lighthouse
```

Each client scenario includes:
- Client-specific configuration
- Client-specific verification tests
- Appropriate resource allocation

### Custom Scenarios

Test specific configurations or features:

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

## Temporary Scenarios

For quick testing, create temporary scenarios:

```bash
# Create a temporary scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution geth --consensus prysm --temp

# Clean up when finished
molecule/shared/scripts/generate_scenario.sh --cleanup geth-prysm
```

## Scenario Structure

Each scenario directory contains:

- `molecule.yml`: Configuration for the scenario
- `converge.yml`: Playbook to apply the role
- `verify.yml`: Tests to verify the configuration

## Best Practices

1. **Keep scenarios minimal**: Only include what differs from the default
2. **Use temporary scenarios** for quick tests to avoid clutter
3. **Clean up after testing** to maintain a clean environment
4. **Standardize verification** for consistent testing
5. **Parameterize tests** to reduce code duplication

## Troubleshooting

See [MOLECULE_TROUBLESHOOTING.md](../docs/MOLECULE_TROUBLESHOOTING.md) for detailed guidance.

## Test Coverage

Our test framework covers:

1. **Client Compatibility**: Testing client combinations
2. **Resource Management**: Testing resource limits
3. **Security**: Testing security configurations
4. **Backup & Recovery**: Testing backup functionality
5. **Monitoring**: Testing monitoring implementations
6. **Validator**: Testing validator node configurations

## CI/CD Integration

Tests are integrated with our CI/CD pipeline:

1. **Pull Request Testing**: Basic scenarios run on all PRs
2. **Scheduled Testing**: Comprehensive testing runs on a schedule
3. **Release Testing**: All scenarios tested before releases

For detailed information about testing, see [TESTING.md](../docs/TESTING.md).

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
