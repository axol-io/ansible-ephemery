# ansible-ephemery

An Ansible role for deploying [Ephemery](https://ephemery.dev/) Ethereum testnet nodes using Docker containers.

## Overview

- Deploys and configures Ephemery testnet nodes with Docker
- Supports multiple execution and consensus client combinations
- Provides monitoring, backup, and validator configuration
- Includes comprehensive Molecule testing framework

## Prerequisites

- Ansible 2.10+ on control machine
- Docker on target hosts
- SSH access to targets

## Quick Start

```bash
# Clone repository
git clone https://github.com/yourusername/ansible-ephemery.git
cd ansible-ephemery

# Install requirements
ansible-galaxy collection install -r requirements.yaml

# Configure inventory
cp inventory.yaml.example inventory.yaml
# Edit inventory.yaml for your environment

# Run the playbook
ansible-playbook -i inventory.yaml main.yaml
```

## Configuration

Default configuration:

```yaml
# Client selection
el: "geth"             # Execution client options: geth, besu, nethermind, reth, erigon
cl: "lighthouse"       # Consensus client options: lighthouse, teku, prysm, lodestar
```

See [docs/CLIENT_COMBINATIONS.md](docs/CLIENT_COMBINATIONS.md) for details.

### Ephemery-Specific Images

This role automatically uses Ephemery-specific Docker images for certain clients:

- When `el: "geth"` is selected, the role uses `pk910/ephemery-geth` instead of the standard Geth image
- When `cl: "lighthouse"` is selected, the role uses `pk910/ephemery-lighthouse` instead of the standard Lighthouse image

These Ephemery-specific images include:
- Pre-configured settings for the Ephemery network
- Built-in genesis configuration
- Automatic network reset handling

For other client combinations, the role uses standard Docker images with custom configuration.

## Testing

```bash
# Run test with automatic cleanup
molecule/shared/scripts/demo_scenario.sh --execution geth --consensus prysm

# Keep the scenario after testing
molecule/shared/scripts/demo_scenario.sh -e nethermind -c lodestar
```

For details, see [docs/TESTING.md](docs/TESTING.md).

## Documentation

- [Repository Structure](docs/REPOSITORY_STRUCTURE.md)
- [Requirements](docs/REQUIREMENTS.md)
- [Security](docs/SECURITY.md)
- [Testing](docs/TESTING.md)
- [CI/CD](docs/CI_CD.md)
- [Variable Structure](docs/VARIABLE_STRUCTURE.md)
- [Client Combinations](docs/CLIENT_COMBINATIONS.md)
- [Ephemery-Specific Configuration](docs/EPHEMERY_SPECIFIC.md)
- [Linting](docs/LINTING.md)
- [Coding Standards](docs/CODING_STANDARDS.md)

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md).

## Development

To set up a development environment:

```bash
# Clone repository
git clone https://github.com/yourusername/ansible-ephemery.git
cd ansible-ephemery

# Run the setup script
./scripts/dev-env-manager.sh setup

# To run linting manually
ansible-lint
# Or run all pre-commit hooks
pre-commit run --all-files
```

### Repository Management Scripts

This repository includes several consolidated utility scripts to simplify common tasks:

- **dev-env-manager.sh** - Development environment setup and collection management
- **molecule-manager.sh** - Testing with Molecule scenarios
- **yaml-lint-fixer.sh** - YAML linting and formatting
- **yaml-extension-manager.sh** - YAML file extension standardization
- **repo-standards.sh** - Repository structure and standardization
- **validator.sh** - Documentation and code validation

For details, see [Script Management](docs/SCRIPT_MANAGEMENT.md).

## Utility Scripts

The repository includes several consolidated utility scripts to help with common development and maintenance tasks:

- **yaml-lint-fixer.sh** - Check and fix YAML linting issues
- **molecule-manager.sh** - Run and update Molecule tests
- **yaml-extension-manager.sh** - Manage YAML file extensions (.yaml vs .yml)
- **dev-env-manager.sh** - Set up development environment and manage collections
- **repo-standards.sh** - Maintain repository standards and structure
- **validator.sh** - Validate documentation, variables, and conditionals

Each script provides help information via the `--help` flag. For detailed documentation, see [Script Management](docs/SCRIPT_MANAGEMENT.md).

## Resources

- [Ephemery resources](https://github.com/ephemery-testnet/ephemery-resources)
- [ephemery-scripts](https://github.com/ephemery-testnet/ephemery-scripts)
- [ephemery-client-wrapper](https://github.com/pk910/ephemery-client-wrapper)

## License

MIT
