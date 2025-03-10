# Ephemery Node

Ephemery is an Ethereum testnet that restarts weekly, providing a clean environment for testing and development.

## Quick Start

To run a simple local demo of an Ephemery node:

```bash
./run-ephemery-demo.sh
```

This will start a local Ephemery node with Geth and Lighthouse in Docker containers.

## Validator Support

The playbook now includes improved validator support with:

- Automatic validator key detection and mounting
- Support for compressed validator key archives
- Enhanced security and permission handling
- Robust validation of key files

For detailed validator setup instructions, see:

- [Validator Guide](docs/VALIDATOR_README.md)
- [Validator Key Management](docs/VALIDATOR_KEY_MANAGEMENT.md)

## Directory Structure

- `run-ephemery-demo.sh` - Main demo script for local testing
- `scripts/` - Advanced deployment scripts
  - `local/` - Scripts for local deployment
  - `remote/` - Scripts for remote deployment
  - `utils/` - Utility scripts for inventory management, cleanup, and more
- `config/` - Configuration files and templates
- `docs/` - Detailed documentation

## Advanced Usage

For more advanced deployments, including remote server deployment and custom configurations, see the documentation in the `docs/` directory:

- [Local Deployment](docs/local-deployment.md)
- [Remote Deployment](docs/remote-deployment.md)
- [Configuration](docs/configuration.md)
- [Inventory Management](docs/inventory-management.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## Inventory Management

Ephemery uses YAML inventory files to configure deployments. The project includes utilities to:

- Generate inventory files from templates: `scripts/utils/generate_inventory.sh`
- Validate inventory files before deployment: `scripts/utils/validate_inventory.sh`

For more information on inventory management, see the [Inventory Management Guide](docs/inventory-management.md).

## Requirements

- Docker and Docker Compose
- Bash shell
- For remote deployment: SSH access to target server
