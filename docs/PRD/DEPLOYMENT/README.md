# Ansible Ephemery Deployment

This directory contains documentation for deploying Ephemery nodes using Ansible, including local development environments, remote deployments, and custom configurations.

## Deployment Types

- [Local Deployment](./LOCAL_DEPLOYMENT.md) - Setting up Ephemery on a local development machine
- [Remote Deployment](./REMOTE_DEPLOYMENT.md) - Deploying Ephemery to remote servers
- [Unified Deployment](./UNIFIED_DEPLOYMENT.md) - Deploying multiple components together
- [Mainnet Deployment](./MAINNET_DEPLOYMENT.md) - Guide for production mainnet deployments with fixes for common issues
- [Production Deployment Findings](./PRODUCTION_DEPLOYMENT_FINDINGS.md) - Findings and next steps from our production deployment

## Configuration Management

- [Inventory Management](./INVENTORY_MANAGEMENT.md) - Managing host inventories and configuration
- [Variable Management](./VARIABLE_MANAGEMENT.md) - Configuring and overriding variables
- [Configuration Guide](./CONFIGURATION.md) - General configuration guidelines

## Deployment Lifecycle

1. **Preparation** - Set up inventory and configuration
2. **Validation** - Verify configuration and prerequisites
3. **Deployment** - Run playbooks to deploy components
4. **Verification** - Confirm deployment success
5. **Maintenance** - Update and manage deployed systems

## Related Documentation

- [Architecture Documentation](../ARCHITECTURE/README.md)
- [Operations Documentation](../OPERATIONS/README.md) 