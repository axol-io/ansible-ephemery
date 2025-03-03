# ansible-ephemery

An Ansible role for deploying [Ephemery](https://ephemery.dev/) Ethereum testnet nodes using [ephemery-client-wrapper](https://github.com/pk910/ephemery-client-wrapper) Docker images.

## Overview

- Deploys Ephemery testnet nodes with Docker
- Supports multiple execution and consensus client combinations
- Includes health checks, monitoring, and Grafana integration
- Features comprehensive testing framework with Molecule

## Prerequisites

- Ansible on control machine
- Docker on target hosts
- SSH access to targets
- Python 3.11+ for tests and development

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

Default configuration uses Geth (execution client) and Lighthouse (consensus client):

```yaml
# Client selection
el: "geth"             # Options: geth, besu, nethermind, reth, erigon
cl: "lighthouse"       # Options: lighthouse, teku, prysm, lodestar
```

See [docs/CLIENT_COMBINATIONS.md](docs/CLIENT_COMBINATIONS.md) for details on supported combinations.

## Testing

Run quick tests with the demo script:

```bash
# Run test with automatic cleanup
molecule/shared/scripts/demo_scenario.sh --execution geth --consensus prysm

# Keep the scenario after testing
molecule/shared/scripts/demo_scenario.sh -e nethermind -c lodestar --keep
```

For detailed testing information, see [docs/TESTING.md](docs/TESTING.md).

## Running Molecule Tests on macOS

If using macOS with Docker Desktop:

```bash
# Run all tests
./run-molecule.sh test

# Run a specific scenario
./run-molecule.sh test -s validator
```

The helper script sets the correct Docker context and socket path for macOS.

### Troubleshooting Tests

If encountering Docker connection issues:

1. Ensure Docker Desktop is running
2. Check your Docker socket path:
   ```bash
   ls -la /Users/yourusername/.docker/run/docker.sock
   ```
3. Switch to the correct Docker context:
   ```bash
   docker context use desktop-linux
   ```

For detailed troubleshooting, see [docs/MOLECULE_TROUBLESHOOTING.md](docs/MOLECULE_TROUBLESHOOTING.md).

## Documentation

The `docs/` directory contains detailed documentation:

- [Repository Structure](docs/REPOSITORY_STRUCTURE.md) - Repository organization
- [Requirements](docs/REQUIREMENTS.md) - Dependencies and requirements
- [Security](docs/SECURITY.md) - Security considerations
- [Testing](docs/TESTING.md) - Comprehensive testing guide
- [CI/CD](docs/CI_CD.md) - CI/CD pipeline information
- [Variable Structure](docs/VARIABLE_STRUCTURE.md) - Variable organization
- [Client Combinations](docs/CLIENT_COMBINATIONS.md) - Supported client combinations
- [Linting](docs/LINTING.md) - YAML linting guidelines
- [Coding Standards](docs/CODING_STANDARDS.md) - Coding standards

## Coding Standards

This project follows specific coding standards:

- YAML files use `.yaml` extension (except in `molecule/` directory which uses `.yml`)
- Ansible variables use snake_case naming
- Docker images specify version tags, not 'latest'
- YAML formatting: 2-space indentation, lines under 100 characters

See [docs/CODING_STANDARDS.md](docs/CODING_STANDARDS.md) for complete standards.

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Resources

- [Official ephemery resources](https://github.com/ephemery-testnet/ephemery-resources)
- [ephemery-scripts](https://github.com/ephemery-testnet/ephemery-scripts)
- [ephemery-client-wrapper](https://github.com/pk910/ephemery-client-wrapper)

## License

MIT
