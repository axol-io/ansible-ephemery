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
# 1. Clone repository
git clone https://github.com/yourusername/ansible-ephemery.git
cd ansible-ephemery

# 2. Install requirements
ansible-galaxy collection install -r requirements.yaml

# 3. Configure inventory
cp inventory.yaml.example inventory.yaml
# Edit inventory.yaml for your environment

# 4. Run the playbook
ansible-playbook -i inventory.yaml main.yaml
```

## Configuration

Default configuration uses Geth (execution client) and Lighthouse (consensus client). Configure in your variables:

```yaml
# Client selection
el: "geth"             # Options: geth, besu, nethermind, reth, erigon
cl: "lighthouse"       # Options: lighthouse, teku, prysm, lodestar
```

All client combinations are supported and tested. See [docs/TESTING.md](docs/TESTING.md) for details.

## Testing

Run quick tests with the demo script:

```bash
# Run test with automatic cleanup
molecule/shared/scripts/demo_scenario.sh --execution geth --consensus prysm

# Keep the scenario after testing
molecule/shared/scripts/demo_scenario.sh -e nethermind -c lodestar --keep
```

## Documentation

The `docs/` directory contains detailed documentation:

- [Repository Structure](docs/REPOSITORY_STRUCTURE.md) - Repository organization
- [Requirements](docs/REQUIREMENTS.md) - Dependencies and requirements
- [Security](docs/SECURITY.md) - Security considerations
- [Testing](docs/TESTING.md) - Comprehensive testing guide
- [CI/CD](docs/CI_CD.md) - CI/CD pipeline information
- [Variable Structure](docs/VARIABLE_STRUCTURE.md) - Variable organization
- [Client Combinations](docs/CLIENT_COMBINATIONS.md) - Detailed information about supported client combinations

## Variable Organization

- **defaults/main.yaml**: Default values (can be overridden)
- **vars/main.yaml**: Hardcoded variables
- **group_vars/all.yaml**: Variables for all hosts
- **host_vars/<hostname>.yaml**: Host-specific configurations
- **host_vars/secrets.yaml**: Sensitive information (encrypt with Ansible Vault)

## Repository Structure

The repository follows standard Ansible role structure with Ephemery-specific additions. For details, see [docs/REPOSITORY_STRUCTURE.md](docs/REPOSITORY_STRUCTURE.md).

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Resources

- [Official ephemery resources](https://github.com/ephemery-testnet/ephemery-resources)
- [ephemery-scripts](https://github.com/ephemery-testnet/ephemery-scripts)
- [ephemery-client-wrapper](https://github.com/pk910/ephemery-client-wrapper)

## License

MIT
