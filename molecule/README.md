---
title: Molecule Testing for Ansible-Ephemery
---

# Molecule Testing Framework

## Directory Structure

```plaintext
molecule/
├── clients/              # Client combination scenarios
├── default/              # Main scenario with default clients
├── backup/               # Backup functionality testing
├── monitoring/           # Monitoring functionality testing
├── resource-limits/      # Resource limitation testing
├── security/             # Security configuration testing
├── validator/            # Validator node testing
├── shared/               # Shared resources across scenarios
└── requirements.yml      # Dependencies for tests
```

## Quick Start

### Running Tests

```bash
# Run demo with auto-cleanup
molecule/shared/scripts/demo_scenario.sh --execution geth --consensus prysm

# Keep scenario after testing
molecule/shared/scripts/demo_scenario.sh -e nethermind -c lodestar --keep

# Run a specific scenario
molecule test -s geth-lighthouse

# Run only converge step (for development)
molecule converge -s geth-lighthouse

# Run only verify step
molecule verify -s geth-lighthouse

# MacOS specific - Run tests on macOS with Docker Desktop
./scripts/run-molecule-tests-macos.sh default
```

### macOS Compatibility

For macOS users with Docker Desktop, we provide a helper script to handle Docker socket connections:

```bash
# Run a specific scenario on macOS
./scripts/run-molecule-tests-macos.sh default

# Run client combination scenario on macOS
./scripts/run-molecule-tests-macos.sh geth-lighthouse
```

This script dynamically detects the Docker socket path and configures Molecule to use it correctly, avoiding common connectivity issues on macOS.

### Creating Scenarios

```bash
# Create client combination scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution geth --consensus lighthouse

# Create temporary scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution nethermind --consensus lodestar --temp

# Create custom scenario
molecule/shared/scripts/generate_scenario.sh --type custom --name high-memory --var memory=8192M --var cpu=2.0
```

## Scenario Types

### Client Combinations

Test specific client combinations:

```bash
# Create a client combination scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution geth --consensus lighthouse
```

### Custom Scenarios

Test specific configurations:

```bash
# Create a custom scenario
molecule/shared/scripts/generate_scenario.sh --type custom --name high-memory --var memory=8192M --var cpu=2.0
```

### Temporary Scenarios

For quick testing:

```bash
# Create temporary scenario
molecule/shared/scripts/generate_scenario.sh --type clients --execution geth --consensus prysm --temp

# Clean up when finished
molecule/shared/scripts/generate_scenario.sh --cleanup geth-prysm
```

## Structure

Each scenario contains:
- `molecule.yaml`: Configuration
- `converge.yaml`: Playbook to apply the role
- `verify.yaml`: Tests to verify configuration

## Best Practices

1. Keep scenarios minimal
2. Use temporary scenarios for quick tests
3. Clean up after testing
4. Standardize verification
5. Parameterize tests
6. Use the macOS helper script on Apple computers

## Common Issues and Solutions

### Docker Connectivity Issues on macOS

If you encounter Docker connection errors on macOS, use the helper script:

```bash
./scripts/run-molecule-tests-macos.sh <scenario>
```

### Ansible Conditional Errors

When writing verification tasks:

- Always quote string literals in conditionals: `when: "'docker.service' in ansible_facts.services"`
- Add existence checks for dictionary keys: `when: ansible_facts.services is defined and ...`
- Always quote default values: `ephemery_base_dir | default("/home/ubuntu/ephemery")`

### Validation Script

Run our conditional verification script to check for common issues:

```bash
./scripts/verify-ansible-conditionals.sh
```

## Troubleshooting

See [MOLECULE_TROUBLESHOOTING.md](../docs/MOLECULE_TROUBLESHOOTING.md) for guidance.

## Test Coverage

- Client Compatibility
- Resource Management
- Security
- Backup & Recovery
- Monitoring
- Validator Configurations

## CI/CD Integration

- Pull Request Testing: Basic scenarios
- Scheduled Testing: Comprehensive tests
- Release Testing: All scenarios

See [TESTING.md](../docs/TESTING.md) for details.
