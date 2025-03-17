# Setup Scripts

This directory contains scripts for setting up and configuring Ephemery nodes and validators.

## Available Scripts

### Node Setup
- `setup_local_env.sh` - Sets up the local environment for Ephemery
- `install-collections.sh` - Installs required Ansible collections
- `check-yaml-extensions.sh` - Validates YAML file extensions

### Environment Configuration
- `run_ansible.sh` - Runs Ansible playbooks for deployment
- `start-validator-dashboard.sh` - Initializes the validator dashboard

## Usage

Most setup scripts support these common options:
- `-h, --help` - Display help information
- `-v, --verbose` - Enable verbose output
- `-d, --dry-run` - Show what would be done without making changes
- `-f, --force` - Force setup without confirmation

## Features

- Automated environment setup
- Dependency management
- Configuration validation
- Dashboard initialization
- Collection installation
- Environment verification

## Prerequisites

1. Docker installed and running
2. Python 3.8 or higher
3. Ansible 2.9 or higher
4. Git installed
5. Sufficient disk space (at least 10GB)

## Best Practices

1. Verify system requirements before setup
2. Run setup scripts with --dry-run first
3. Keep setup logs for troubleshooting
4. Follow security best practices
5. Test setup in development first

For detailed usage instructions, refer to the main [README.md](../../README.md) or run each script with the `--help` flag. 