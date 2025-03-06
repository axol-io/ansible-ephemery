# Getting Started with ansible-ephemery

This guide provides step-by-step instructions for deploying Ephemery nodes, especially for those new to Ansible.

## Prerequisites

- A Linux server (Ubuntu 20.04+ recommended) with:
  - At least 4 CPU cores
  - 8+ GB RAM
  - 100+ GB storage
  - SSH access with sudo privileges
- Ansible 2.10+ installed on your local machine

## 1. Clone the Repository

```bash
git clone https://github.com/hydepwns/ansible-ephemery.git
cd ansible-ephemery
```

## 2. Install Requirements

```bash
# Install Ansible collections and Python dependencies
ansible-galaxy collection install -r requirements.yaml
pip install -r requirements.txt
```

## 3. Configure Your Inventory

The inventory file tells Ansible which servers to manage and which roles they should play.

1. Copy the example inventory:
   ```bash
   cp example-inventory.yaml inventory.yaml
   ```

2. Edit the inventory file:
   ```bash
   nano inventory.yaml
   ```

3. Replace the example values with your own:
   ```yaml
   ephemery:
     children:
       geth_lighthouse:  # You can rename this group
         hosts:
           your-node-name:  # Replace with your preferred hostname
             ansible_host: 192.168.1.101  # Your server's IP address
             ansible_user: ubuntu  # Your SSH username
             el: geth  # Execution client
             cl: lighthouse  # Consensus client
   ```

## 4. Configure Host Variables (Optional but Recommended)

Host variables allow more detailed configuration for each node.

1. Create a host variable file:
   ```bash
   mkdir -p host_vars
   cp host_vars/example-host.yaml host_vars/your-node-name.yaml
   ```

   Note: The filename must match the hostname in your inventory.

2. Edit the host variables:
   ```bash
   nano host_vars/your-node-name.yaml
   ```

3. Configure essential settings:
   ```yaml
   ---
   # Connection settings
   ansible_host: 192.168.1.101  # Your server's IP address
   ansible_user: ubuntu  # Your SSH username

   # Client selection
   el: geth  # Execution client: geth, besu, nethermind, reth, erigon
   cl: lighthouse  # Consensus client: lighthouse, teku, prysm, lodestar

   # Feature flags
   monitoring_enabled: true  # Enable monitoring stack
   validator_enabled: false  # Set to true to run a validator

   # Automatic reset (recommended for Ephemery nodes)
   ephemery_automatic_reset: true  # Enable automatic reset
   ephemery_reset_frequency: "0 0 * * *"  # Reset daily at midnight
   ```

## 5. Run the Playbook

Deploy your Ephemery node:

```bash
ansible-playbook -i inventory.yaml ephemery.yaml
```

This command will install and configure:
- Docker
- Selected Ethereum clients
- Monitoring tools (if enabled)
- Validator (if enabled)

## 6. Access Your Ephemery Node

After deployment completes, you can access:

- Execution API: `http://your-server-ip:8545`
- Consensus API: `http://your-server-ip:5052`
- Grafana (if monitoring enabled): `http://your-server-ip:3000`
  - Default login: admin / admin (change on first login)

## 7. Troubleshooting

- Check logs on your server:
  ```bash
  # Execution client logs
  docker logs ephemery-geth

  # Consensus client logs
  docker logs ephemery-lighthouse
  ```

- If your deployment fails, run with verbose output:
  ```bash
  ansible-playbook -i inventory.yaml ephemery.yaml -vv
  ```

## Next Steps

- Set up a [validator](VALIDATOR_README.md)
- Configure [monitoring](MONITORING.md)
- Explore [client combinations](CLIENT_COMBINATIONS.md)
