# Ephemery Ansible Repository

This repository contains Ansible roles and playbooks for deploying and managing Ephemery nodes.

## Repository Structure

```bash
ephemery-ansible/
├── ansible/                # Ansible configuration and roles
│   ├── roles/              # Role-based configuration
│   │   ├── common/         # Base configuration for all nodes
│   │   ├── execution_client/ # Execution client configuration
│   │   ├── consensus_client/ # Consensus client configuration
│   │   └── validator/      # Validator client configuration
│   ├── handlers/           # Shared handlers
│   └── templates/          # Shared templates
├── playbooks/              # Main playbooks
│   ├── deploy_ephemery.yaml  # Main deployment playbook
│   ├── fix_ephemery_node.yaml # Node fixing playbook
│   ├── setup_monitoring.yml   # Monitoring setup playbook
│   ├── status_check.yml       # Status check playbook
│   ├── backup_ephemery.yml    # Backup playbook
│   ├── update_ephemery.yml    # Update playbook
│   └── setup_validator.yml    # Validator setup playbook
├── scripts/                # Helper scripts
│   ├── identify_legacy_files.sh # File pruning helper
│   └── utilities/          # Utility scripts
├── config/                 # Configuration files
│   └── vars/               # Variable files
├── docs/                   # Documentation
│   ├── CLIENT_MIGRATION_GUIDE.md # Guide for migrating to the new structure
│   ├── roles/              # Role documentation
│   ├── playbooks/          # Playbook documentation
│   └── troubleshooting/    # Common issues and solutions
└── templates/              # Global templates
```

## Quick Start

### Prerequisites

- Ansible 2.9+
- Python 3.6+
- SSH access to target nodes
- Target nodes with Ubuntu 20.04+ or similar

### Basic Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/your-org/ephemery-ansible.git
   cd ephemery-ansible
   ```

2. Create an inventory file:

   ```bash
   cp ansible/example-inventory.yaml ansible/inventory.yaml
   # Edit the inventory file to include your nodes
   ```

3. Run the deployment playbook:

   ```bash
   ansible-playbook playbooks/deploy_ephemery.yaml -i ansible/inventory.yaml
   ```

### Advanced Installation

To specify client combinations:

```bash
ansible-playbook playbooks/deploy_ephemery.yaml -i ansible/inventory.yaml \
  -e "el_client=geth cl_client=lighthouse \
      el_data_dir=/data/ethereum/execution cl_data_dir=/data/ethereum/consensus"
```

## Supported Client Combinations

| Execution Client | Consensus Client | Status |
|------------------|------------------|--------|
| Geth             | Lighthouse       | ✅     |
| Geth             | Prysm            | 🔜     |
| Geth             | Teku             | 🔜     |
| Geth             | Nimbus           | 🔜     |
| Geth             | Lodestar         | 🔜     |
| Nethermind       | Lighthouse       | 🔜     |
| Nethermind       | Prysm            | 🔜     |
| Nethermind       | Teku             | 🔜     |
| Nethermind       | Nimbus           | 🔜     |
| Nethermind       | Lodestar         | 🔜     |
| Besu             | Lighthouse       | 🔜     |
| Besu             | Prysm            | 🔜     |
| Besu             | Teku             | 🔜     |
| Besu             | Nimbus           | 🔜     |
| Besu             | Lodestar         | 🔜     |
| Erigon           | Lighthouse       | 🔜     |
| Erigon           | Prysm            | 🔜     |
| Erigon           | Teku             | 🔜     |
| Erigon           | Nimbus           | 🔜     |
| Erigon           | Lodestar         | 🔜     |

## Key Features

- **Role-Based Architecture**: Modular, reusable configurations
- **Standardized JWT Management**: Consistent and secure JWT handling
- **Consolidated Playbooks**: Uniform deployment and maintenance
- **Client Flexibility**: Support for all major Ethereum client combinations
- **Monitoring Integration**: Built-in monitoring setup with Prometheus and Grafana
- **Backup & Update Utilities**: Streamlined maintenance operations
- **Validator Support**: Integrated validator management

## Available Playbooks

- **deploy_ephemery.yaml**: Deploy a complete Ethereum node
- **fix_ephemery_node.yaml**: Fix common issues with nodes
- **setup_monitoring.yml**: Set up Prometheus, Grafana, and Node Exporter
- **status_check.yml**: Check the status of Ethereum nodes
- **backup_ephemery.yml**: Back up node data and configurations
- **update_ephemery.yml**: Update node software and configurations
- **setup_validator.yml**: Set up a validator node

## Client Migration

If you're migrating from the legacy configuration structure to the new role-based approach, please see our [Client Migration Guide](./docs/CLIENT_MIGRATION_GUIDE.md).

## Troubleshooting

For common issues and solutions, run the status check playbook:

```bash
ansible-playbook playbooks/status_check.yml -i ansible/inventory.yaml
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## Security

For security issues, please see [SECURITY.md](./SECURITY.md).
