# ansible-ephemery

A comprehensive Ansible playbook for deploying and managing [Ephemery](https://ephemery.dev/) Ethereum testnet nodes using Docker containers.

## What is Ephemery?

Ephemery is a short-lived Ethereum testnet that automatically resets every 24 hours. This provides a clean testing environment for developers, researchers, and node operators without the resource requirements of permanent testnets.

## Key Features

- **Multi-client support**: Deploy various execution and consensus client combinations
  - Execution clients: Geth, Besu, Nethermind, Reth, Erigon
  - Consensus clients: Lighthouse, Teku, Prysm, Lodestar
- **Specialized Ephemery images**: Uses optimized Docker images with built-in genesis configuration and automatic reset handling
- **Comprehensive monitoring**: Grafana, Prometheus, Node Exporter, and cAdvisor integration
- **Security-focused**: Firewall configuration, JWT secret management, and secure defaults
- **Automated operations**: Backup, health checks, and resource management
- **Validator support**: Optional validator deployment and management
- **Extensive testing**: Includes Molecule testing framework for reliable deployments
- **Resource-efficient**: Configurable memory allocation for different clients

## Prerequisites

- Ansible 2.10+ on the control machine
- Target hosts with:
  - Docker installed (or enable auto-installation)
  - SSH access
  - Sufficient resources (4+ CPU cores, 8+ GB RAM recommended)

## Quick Start

```bash
# Clone repository
git clone https://github.com/yourusername/ansible-ephemery.git
cd ansible-ephemery

# Install requirements
ansible-galaxy collection install -r requirements.yaml
pip install -r requirements.txt

# Configure inventory
cp inventory.yaml.example inventory.yaml
# Edit inventory.yaml with your target hosts and configuration

# Run the playbook
ansible-playbook -i inventory.yaml ephemery.yaml
```

## Configuration

The playbook provides extensive configuration options:

### Basic Configuration

```yaml
# Client selection
el: "geth"             # Execution client
cl: "lighthouse"       # Consensus client

# Feature toggles
validator_enabled: false
monitoring_enabled: true
backup_enabled: true
firewall_enabled: true
```

### Resource Management

The playbook automatically configures resource limits based on available system memory:

```yaml
# Total allocation is 90% of system memory
el_memory_percentage: 0.5    # 50% for execution client
cl_memory_percentage: 0.4    # 40% for consensus client
validator_memory_percentage: 0.1  # 10% for validator (if enabled)
```

### Directory Structure

```bash
/opt/ephemery/
├── data/              # Node data
│   ├── el/            # Execution client data
│   └── cl/            # Consensus client data
├── logs/              # Log files
├── scripts/           # Operational scripts
└── backups/           # Backup files
```

## Client Combinations

This playbook is designed to support multiple client combinations. Ephemery-specific Docker images are used when available, with standard images and custom configuration for other combinations.

### Ephemery-Specific Images

- `pk910/ephemery-geth`: Preconfigured Geth for Ephemery network
- `pk910/ephemery-lighthouse`: Preconfigured Lighthouse for Ephemery network

See [docs/CLIENT_COMBINATIONS.md](docs/CLIENT_COMBINATIONS.md) for detailed compatibility information.

## Monitoring

The playbook includes comprehensive monitoring tools:

- **Grafana**: Visualize metrics via dashboards
- **Prometheus**: Collect and store metrics
- **Node Exporter**: System metrics collection
- **cAdvisor**: Container metrics

## Testing

The repository includes a comprehensive Molecule testing framework:

```bash
# Run test with automatic cleanup
molecule/shared/scripts/demo_scenario.sh --execution geth --consensus prysm

# Keep the scenario after testing
molecule/shared/scripts/demo_scenario.sh -e nethermind -c lodestar
```

For more details on testing and verification, see [docs/TESTING.md](docs/TESTING.md) and [docs/VERIFICATION_TESTS.md](docs/VERIFICATION_TESTS.md).

## Development and Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

To set up a development environment:

```bash
# Clone repository
git clone https://github.com/yourusername/ansible-ephemery.git
cd ansible-ephemery

# Install development requirements
pip install -r requirements-dev.txt

# Set up pre-commit hooks
pre-commit install

# Run linting
ansible-lint
yamllint .
```

## Utility Scripts

The repository includes several utility scripts to simplify common tasks:

- **dev-env-manager.sh**: Development environment setup
- **molecule-manager.sh**: Test management
- **yaml-lint-fixer.sh**: YAML linting and formatting
- **repo-standards.sh**: Repository structure validation
- **validator.sh**: Documentation and code validation

Each script provides help information via the `--help` flag.

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- [Repository Structure](docs/REPOSITORY_STRUCTURE.md)
- [Requirements](docs/REQUIREMENTS.md)
- [Security](docs/SECURITY.md)
- [Testing](docs/TESTING.md)
- [Verification Tests](docs/VERIFICATION_TESTS.md)
- [CI/CD](docs/CI_CD.md)
- [Client Combinations](docs/CLIENT_COMBINATIONS.md)
- [Coding Standards](docs/CODING_STANDARDS.md)

## Additional Resources

- [Ephemery Website](https://ephemery.dev/)
- [Ephemery Resources](https://github.com/ephemery-testnet/ephemery-resources)
- [Ephemery Scripts](https://github.com/ephemery-testnet/ephemery-scripts)
- [Ephemery Client Wrapper](https://github.com/pk910/ephemery-client-wrapper)

## License

MIT
