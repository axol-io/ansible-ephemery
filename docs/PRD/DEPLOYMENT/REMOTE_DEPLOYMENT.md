# Remote Deployment Guide

This guide explains how to deploy an Ephemery node to a remote server.

## Prerequisites

- SSH access to the target server
- Docker installed on the target server
- Sufficient privileges on the remote server (root or sudo access)

## Setup

1. Generate a remote inventory file:

   ```bash
   ./scripts/utils/generate_inventory.sh --type remote \
     --output my-remote-inventory.yaml \
     --remote-host your-server-ip-or-hostname \
     --remote-user your-username
   ```

2. Edit the inventory file to customize settings if needed:

   ```yaml
   hosts:
     - host: your-server-ip-or-hostname
       user: your-username
       port: 22

   remote:
     base_dir: "/opt/ephemery"
     # ... other settings
   ```

3. Validate your inventory file (recommended):

   ```bash
   ./scripts/utils/validate_inventory.sh my-remote-inventory.yaml
   ```

4. Run the remote deployment script:

   ```bash
   ./scripts/remote/run-ephemery-remote.sh --inventory my-remote-inventory.yaml
   ```

## Advanced Inventory Configuration

The remote inventory file allows you to configure:
- SSH connection details (host, user, port)
- Directory paths for data and logs
- Client versions (Docker images)
- Client-specific settings like cache size and peer counts

For detailed inventory configuration options and examples, see the [Inventory Management Guide](./INVENTORY_MANAGEMENT.md).

## Monitoring and Management

Once deployed, you can monitor your remote Ephemery node:

- Connect to your server via SSH
- Check Docker container status:
  ```bash
  docker ps
  ```
- View logs:
  ```bash
  docker logs -f ephemery-geth
  docker logs -f ephemery-lighthouse
  ```

## Troubleshooting

If you encounter issues, check:

1. SSH connectivity to the remote server
2. Docker service status on the remote server
3. Firewall settings
4. Remote server resource usage

For more help, see the [Configuration Guide](./CONFIGURATION.md) and [Troubleshooting Guide](../OPERATIONS/TROUBLESHOOTING.md).
