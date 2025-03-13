# Ephemery Node Deployment

This document provides detailed information on deploying Ephemery nodes in various environments.

## Deployment Methods

Ephemery nodes can be deployed using several methods:

1. **Unified Deployment System** (Recommended): Our guided deployment system with interactive setup
2. **Manual Deployment**: Using Ansible playbooks directly
3. **Local Demo Deployment**: For testing and development

## Unified Deployment System

The Unified Deployment System is the recommended way to deploy Ephemery nodes. It provides a guided process with automated verification.

### Prerequisites

- Ansible 2.10+ installed
- SSH access to target servers (for remote deployment)
- Python 3.6+ on target servers
- sudo privileges on target servers

### Deployment Steps

1. **Start the Guided Deployment Process**

   ```bash
   ./scripts/deploy-ephemery.sh
   ```

2. **Choose Deployment Type**

   ```bash
   # Local deployment with guided setup
   ./scripts/deploy-ephemery.sh --type local

   # Remote deployment with guided setup
   ./scripts/deploy-ephemery.sh --type remote --host your-server
   ```

3. **Follow the Setup Wizard**

   The wizard will guide you through:
   - Selecting Ethereum clients
   - Configuring network settings
   - Setting up monitoring
   - Configuring validators (optional)
   - Setting up automatic Ephemery resets

4. **Verify Deployment**

   After deployment completes, the system will run verification tests to ensure everything is working correctly.

### Custom Configuration

For customized deployments:

```bash
# Deploy with custom inventory file
./scripts/deploy-ephemery.sh --inventory custom-inventory.yaml

# Non-interactive deployment with default settings
./scripts/deploy-ephemery.sh --yes
```

### Using the Configuration Wizard

```bash
./scripts/utils/guided_config.sh --output my-inventory.yaml
```

## Manual Deployment

For advanced users who want direct control over the deployment process.

### Creating an Inventory File

1. Copy the example inventory:

   ```bash
   cp example-inventory.yaml my-inventory.yaml
   ```

2. Edit the inventory to configure hosts and variables:

   ```yaml
   ephemery:
     children:
       geth_lighthouse:
         hosts:
           my-ephemery-node:
             ansible_host: 192.168.1.100
             ansible_user: ubuntu
             el: geth
             cl: lighthouse
             validator_enabled: false
             monitoring_enabled: true
             ephemery_automatic_reset: true
   ```

### Running the Playbook

```bash
ansible-playbook -i my-inventory.yaml ephemery.yaml
```

### Specifying Tags

You can deploy specific components using tags:

```bash
ansible-playbook -i my-inventory.yaml ephemery.yaml --tags "docker,execution,consensus"
```

Available tags include:
- `docker`: Docker installation
- `execution`: Execution client deployment
- `consensus`: Consensus client deployment
- `validator`: Validator client deployment
- `monitoring`: Monitoring stack deployment
- `ephemery_reset`: Ephemery reset mechanism

## Local Demo Deployment

For local testing and development:

```bash
./run-ephemery-demo.sh
```

This will:
1. Set up Docker containers for Geth and Lighthouse
2. Configure them for the Ephemery testnet
3. Connect them to the network
4. Set up basic monitoring

## Server Requirements

| Component | Minimum Requirements | Recommended |
|-----------|----------------------|------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8+ GB |
| Storage | 50 GB | 100+ GB SSD |
| Network | 10 Mbps | 25+ Mbps |

## Post-Deployment Configuration

### Accessing Nodes

- **Execution API**: `http://your-server:8545`
- **Consensus API**: `http://your-server:5052`
- **Monitoring Dashboard**: `http://your-server:3000`

### Configuring Validators

To add validators after deployment:

```bash
./scripts/deploy-validators.sh --keys=/path/to/validator_keys --password=/path/to/password.txt
```

### Enabling Ephemery Automatic Reset

To enable automatic detection and handling of Ephemery network resets:

```bash
./scripts/deploy_ephemery_retention.sh
```

## Troubleshooting

### Common Issues

1. **Connection Problems**:
   - Check SSH connectivity
   - Verify target server's network configuration
   - Ensure firewall allows required ports

2. **Permission Issues**:
   - Ensure user has sudo access
   - Check file permissions

3. **Client Synchronization Problems**:
   - Verify network connectivity
   - Check client logs for errors
   - Try using checkpoint sync

### Logs and Debugging

```bash
# View Execution Client logs
docker logs ephemery-geth

# View Consensus Client logs
docker logs ephemery-lighthouse

# Check Ephemery reset service logs
journalctl -u ephemery-reset -f
```

## Related Documentation

- [Local Deployment Guide](../DEVELOPMENT/local-deployment.md)
- [Remote Deployment Guide](../DEVELOPMENT/remote-deployment.md)
- [Inventory Management](../DEVELOPMENT/inventory-management.md)
- [Monitoring Configuration](../FEATURES/MONITORING.md)
- [Validator Setup](../FEATURES/VALIDATOR_SETUP.md)
