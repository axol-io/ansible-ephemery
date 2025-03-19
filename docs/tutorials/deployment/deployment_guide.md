# Tutorial: Deploying Your First Ephemery Node

## Overview

This tutorial walks you through the process of deploying an Ethereum node using Ephemery. By the end, you'll have a functioning Ethereum node with both execution and consensus clients.

## Prerequisites

- A Linux server (Ubuntu 20.04 LTS or later recommended)
- SSH access to the server
- At least 8GB RAM and 200GB disk space
- Python 3.8 or later
- Ansible 2.12 or later

## Estimated Time: 30 minutes

## Steps

### Step 1: Clone the Repository

Begin by cloning the Ephemery repository to your local machine.

```bash
git clone https://github.com/yourusername/ephemery.git
cd ephemery
```

### Step 2: Install Dependencies

Install the required Ansible collections and roles.

```bash
./scripts/utilities/install_dependencies.sh
```

Expected output:

```
Installing Ansible collections...
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix
Collections installed successfully.
```

### Step 3: Create Inventory File

Create an inventory file that defines your target nodes. You can use the example inventory as a starting point.

```bash
cp inventory/example.yml inventory/my_nodes.yml
```

Edit the inventory file to reflect your server details:

```yaml
all:
  children:
    ephemery_nodes:
      hosts:
        my-ethereum-node:
          ansible_host: 192.168.1.100
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
          el_client_name: geth
          cl_client_name: lighthouse
```

### Step 4: Configure Client Variables

You can customize client settings by creating a variables file:

```bash
mkdir -p inventory/group_vars/ephemery_nodes
cp inventory/example_vars.yml inventory/group_vars/ephemery_nodes/vars.yml
```

Edit the variables file as needed:

```yaml
# Client selection
el_client_name: geth
cl_client_name: lighthouse

# Network configuration
network_id: 11155111  # Sepolia
chain_id: 11155111

# Resource limits
el_memory_limit: 4G
cl_memory_limit: 4G

# JWT secret
jwt_secret_path: /etc/ethereum/jwt.hex
```

### Step 5: Run the Deployment Playbook

Deploy your node with the main deployment playbook:

```bash
ansible-playbook -i inventory/my_nodes.yml playbooks/deploy_ephemery.yaml
```

The playbook will perform the following steps:
1. Apply the common role to configure the base system
2. Deploy the selected execution client (Geth in this example)
3. Deploy the selected consensus client (Lighthouse in this example)
4. Configure clients to communicate with each other

### Step 6: Verify the Deployment

Check that your clients are running properly:

```bash
./scripts/utilities/check_node_status.sh -h 192.168.1.100
```

Expected output:

```
✓ Execution client (geth) is running
✓ Consensus client (lighthouse) is running
✓ Clients are communicating properly
✓ Node is syncing with the network
```

## Troubleshooting

### Client Not Starting

**Symptoms**:
- Service is not running
- Error messages in logs about failed to start

**Solution**:

1. Check system resources:
   ```bash
   df -h
   free -m
   ```

2. Check log files:
   ```bash
   sudo journalctl -u geth
   sudo journalctl -u lighthouse
   ```

3. Restart the service:
   ```bash
   sudo systemctl restart geth
   sudo systemctl restart lighthouse
   ```

### Clients Not Communicating

**Symptoms**:
- Error messages about failing to connect to the other client
- "Missing latest block" errors

**Solution**:

1. Verify JWT secret is correctly configured:
   ```bash
   ./scripts/utilities/check_jwt_secret.sh -h 192.168.1.100
   ```

2. Check client API endpoints:
   ```bash
   curl -s http://localhost:8545 -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}'
   ```

## Next Steps

- [Configure Monitoring](monitoring_setup.md)
- [Validator Setup](validator_setup.md)
- [Performance Tuning](performance_tuning.md)

## Additional Resources

- [Ethereum Node Documentation](https://ethereum.org/en/developers/docs/nodes-and-clients/)
- [Geth Documentation](https://geth.ethereum.org/docs/)
- [Lighthouse Documentation](https://lighthouse-book.sigmaprime.io/)

## Feedback

If you encountered any issues with this tutorial, please [open an issue](https://github.com/yourusername/ephemery/issues/new) with a description of the problem. 