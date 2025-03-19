# Ephemery Documentation Index

This document provides a complete index of all documentation in the Ephemery Ansible repository.

## Getting Started

- [Quick Start Guide](tutorials/quick_start.md) - Deploy your first Ephemery node
- [Installation Guide](tutorials/installation.md) - Comprehensive installation instructions
- [Client Combinations](reference/client_combinations.md) - Overview of supported client combinations

## Architecture

- [Architecture Overview](architecture/overview.md) - High-level architecture of Ephemery
- [Role-Based Design](architecture/role_based_design.md) - Explanation of the role-based architecture
- [Consolidation Plan](../CONSOLIDATION.md) - Details of the repository consolidation efforts

## Roles

### Common Role

- [Common Role Overview](roles/common.md) - Base configuration for all nodes
- [JWT Management](roles/common/jwt_management.md) - JWT secret handling
- [Directory Structure](roles/common/directory_structure.md) - Standard directory layout

### Execution Client Role

- [Execution Client Role Overview](roles/execution_client.md) - Configuration for execution clients
- [Geth Client](roles/execution_client/geth.md) - Geth-specific configuration
- [Nethermind Client](roles/execution_client/nethermind.md) - Nethermind-specific configuration
- [Besu Client](roles/execution_client/besu.md) - Besu-specific configuration

### Consensus Client Role

- [Consensus Client Role Overview](roles/consensus_client.md) - Configuration for consensus clients
- [Lighthouse Client](roles/consensus_client/lighthouse.md) - Lighthouse-specific configuration
- [Prysm Client](roles/consensus_client/prysm.md) - Prysm-specific configuration
- [Teku Client](roles/consensus_client/teku.md) - Teku-specific configuration

## Playbooks

- [Deploy Ephemery](playbooks/deploy_ephemery.md) - Main deployment playbook
- [Fix Ephemery Node](playbooks/fix_ephemery_node.md) - Playbook for fixing common issues
- [Fix Container Configurations](playbooks/fix_container_configurations.md) - Container-specific fixes

## Tutorials

- [Quick Start](tutorials/quick_start.md) - Deploy your first node
- [Client Migration](tutorials/client_migration.md) - Migrate between clients
- [Monitoring Setup](tutorials/monitoring_setup.md) - Set up monitoring
- [Validator Deployment](tutorials/validator_deployment.md) - Deploy validators
- [Network Customization](tutorials/network_customization.md) - Customize network parameters

## Troubleshooting

- [Common Issues](troubleshooting/common_issues.md) - Frequently encountered problems
- [Sync Issues](troubleshooting/sync_issues.md) - Problems with node synchronization
- [Connection Problems](troubleshooting/connection_problems.md) - Network and connection issues
- [JWT Authentication](troubleshooting/jwt_authentication.md) - Issues with JWT authentication
- [Log Analysis](troubleshooting/log_analysis.md) - How to analyze client logs

## Reference

- [Variable Reference](reference/variables.md) - Complete variable documentation
- [Client Configurations](reference/client_configurations.md) - Client-specific configuration options
- [Script Usage](reference/script_usage.md) - Documentation for helper scripts
- [Inventory Examples](reference/inventory_examples.md) - Example inventory configurations
- [Command Reference](reference/commands.md) - Common commands and operations

## Development

- [Development Setup](development/setup.md) - Setting up a development environment
- [Testing](development/testing.md) - Running and writing tests
- [Contribution Guidelines](development/contributing.md) - How to contribute to the project
- [Coding Standards](development/coding_standards.md) - Standards for code contributions

## Documentation Templates

- [Role Documentation Template](templates/role_template.md)
- [Tutorial Template](templates/tutorial_template.md)
- [Troubleshooting Template](templates/troubleshooting_template.md)

## Scripts Documentation

- [Scripts Overview](../scripts/README.md)
- [Script Utilities](../scripts/utilities/)
- [Deployment Scripts](../scripts/deployment/)
- [Maintenance Scripts](../scripts/maintenance/)
- [Monitoring Scripts](../scripts/monitoring/)
- [Testing Scripts](../scripts/testing/)

## Core Documentation

- [Security Guidelines](SECURITY.md)

## Directory-Specific Documentation

- [scripts](scripts/README.md)
- [lib](scripts/lib/README.md)
- [utilities](scripts/utilities/README.md)
- [core](scripts/core/README.md)
- [validator](scripts/validator/README.md)
- [monitoring](scripts/monitoring/README.md)
- [deployment](scripts/deployment/README.md)
- [testing](scripts/testing/README.md)
- [ansible](ansible/README.md)
- [playbooks](playbooks/README.md)
- [dashboard](dashboard/README.md)

## Developer Documentation

- [Coding Standards for ansible-ephemery](docs/dev/CODING_STANDARDS.md)
- [Linting in ansible-ephemery](docs/dev/LINTING.md)
- [Requirements](docs/dev/REQUIREMENTS.md)
- [Secure Development Guide for Ephemery Ansible](docs/dev/SECURE_DEVELOPMENT.md)
- [Security Considerations](docs/dev/SECURITY.md)
- [Managing Ansible Output in Ephemery](docs/dev/managing_ansible_output.md)

## Usage Documentation
