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

## Testing

```bash
# Run test with automatic cleanup
molecule/shared/scripts/demo_scenario.sh --execution geth --consensus prysm

# Keep the scenario after testing
molecule/shared/scripts/demo_scenario.sh -e nethermind -c lodestar --keep
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
- [Linting](docs/LINTING.md)
- [Coding Standards](docs/CODING_STANDARDS.md)

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md).

## Resources

- [Ephemery resources](https://github.com/ephemery-testnet/ephemery-resources)
- [ephemery-scripts](https://github.com/ephemery-testnet/ephemery-scripts)
- [ephemery-client-wrapper](https://github.com/pk910/ephemery-client-wrapper)

## License

MIT
