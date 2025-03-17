# Deployment Scripts

This directory contains scripts for deploying and managing Ephemery nodes and validators in various environments.

## Available Scripts

### Node Deployment
- `deploy_enhanced_validator_dashboard.sh` - Deploys the enhanced validator monitoring dashboard
- `fix_mainnet_deployment.sh` - Fixes common mainnet deployment issues

### Validator Deployment
- `deploy-validator.sh` - Deploys a new validator node
- `deploy-monitoring.sh` - Sets up monitoring for deployed validators

## Usage

Most deployment scripts support these common options:
- `-h, --help` - Display help information
- `-v, --verbose` - Enable verbose output
- `-d, --dry-run` - Show what would be done without making changes
- `-f, --force` - Force deployment without confirmation

## Features

- Automated deployment processes
- Environment-specific configurations
- Monitoring setup
- Error handling and recovery
- Deployment verification
- Rolling updates support

## Prerequisites

1. Ansible installed and configured
2. Required collections installed
3. SSH access to target hosts
4. Sufficient permissions
5. Network connectivity

## Best Practices

1. Test deployments in staging first
2. Use version control for configurations
3. Maintain deployment documentation
4. Monitor deployment progress
5. Have rollback procedures ready

## Security Considerations

- Use secure communication channels
- Follow least privilege principle
- Protect sensitive configuration data
- Regular security audits
- Monitor for unauthorized access

For detailed usage instructions, refer to the main [README.md](../../README.md) or run each script with the `--help` flag.
