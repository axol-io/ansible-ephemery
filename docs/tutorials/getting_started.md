# Getting Started with Ephemery Node

This guide provides step-by-step instructions for deploying Ephemery nodes, especially for those new to the project.

## What is Ephemery?

Ephemery is an Ethereum testnet that restarts weekly, providing a clean environment for testing and development. This project provides Ansible playbooks and tools to easily deploy and maintain Ephemery nodes.

## Prerequisites

- A Linux server (Ubuntu 20.04+ recommended) with:
  - At least 4 CPU cores
  - 8+ GB RAM
  - 100+ GB storage
  - SSH access with sudo privileges
- Ansible 2.10+ installed on your local machine

## Quick Start

For a simple local demo:

```bash
./run-ephemery-demo.sh
```

This will start a local Ephemery node with Geth and Lighthouse in Docker containers.

## Guided Deployment

For production deployments, use our unified deployment system:

```bash
# Start the guided deployment process
./scripts/deployment/deploy-ephemery.sh
```

## Detailed Deployment Steps

### 1. Clone the Repository

```bash
git clone https://github.com/hydepwns/ansible-ephemery.git
cd ansible-ephemery
```

### 2. Install Requirements

```bash
# Install Ansible collections and Python dependencies
ansible-galaxy collection install -r requirements.yaml
pip install -r requirements.txt
```

### 3. Configure Your Inventory

The inventory file tells Ansible which servers to manage and which roles they should play.

1. Copy the example inventory:

```bash
cp ansible/example-inventory.yaml ansible/inventory.yaml
```

2. Edit the inventory file:

```bash
nano ansible/inventory.yaml
```

3. Configure your nodes with client combinations:

```yaml
ephemery:
  children:
    geth_lighthouse:
      hosts:
        ephemery-node1:
          ansible_host: 192.168.1.101
          el: geth
          cl: lighthouse
```

4. Set up validator configuration if needed:

```yaml
validators:
  hosts:
    ephemery-node1:
      validator_enabled: true
```

### 4. Run the Playbook

Deploy your Ephemery node:

```bash
ansible-playbook -i ansible/inventory.yaml playbooks/deploy_ephemery.yaml
```

This command will install and configure:
- Docker
- Selected Ethereum clients
- Monitoring tools (if enabled)
- Validator (if enabled)

## Genesis Validator Setup

To participate as a genesis validator (starting from genesis):

1. Enable the validator option in your inventory:
   ```yaml
   validators:
     hosts:
       ephemery-node1:
         validator_enabled: true
   ```

2. Run the deployment with the validator option:
   ```bash
   ./scripts/deployment/deploy-ephemery.sh --validator
   ```

For more details, see the [Genesis Validator Guide](./OPERATIONS/GENESIS_VALIDATOR.md).

## Optimized Sync

For optimal sync performance, add these parameters to your inventory:

```yaml
all:
  children:
    ephemery:
      vars:
        checkpoint_sync_enabled: true
        checkpoint_sync_url: "https://ephemery.dev/checkpoint"
```

For more sync options, see the [Checkpoint Sync Guide](./FEATURES/CHECKPOINT_SYNC.md).

## Access Your Ephemery Node

After deployment completes, you can access:

- Execution API: `http://your-server-ip:8545`
- Consensus API: `http://your-server-ip:5052`
- Grafana (if monitoring enabled): `http://your-server-ip:3000`
  - Default login: admin / admin (change on first login)

## Troubleshooting

- Check logs on your server:
  ```bash
  # Execution client logs
  docker logs ephemery-geth

  # Consensus client logs
  docker logs ephemery-lighthouse
  ```

- If your deployment fails, run with verbose output:
  ```bash
  ansible-playbook -i ansible/inventory.yaml playbooks/deploy_ephemery.yaml -vv
  ```

- For checkpoint sync issues, try our enhanced checkpoint sync tool:
  ```bash
  ./scripts/maintenance/enhanced_checkpoint_sync.sh --apply
  ```

## Next Steps

- [Architecture Overview](./ARCHITECTURE/ARCHITECTURE.md)
- [Development Setup](./DEVELOPMENT/DEVELOPMENT_SETUP.md)
- [Deployment Guide](./DEPLOYMENT/DEPLOYMENT.md)
- [Feature Documentation](./FEATURES/)
- [Project Roadmap](./PROJECT_MANAGEMENT/ROADMAP.md)
