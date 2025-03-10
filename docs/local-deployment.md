# Local Deployment Guide

This guide explains how to deploy an Ephemery node locally with advanced options.

## Quick Start

For a simple demo deployment, use the script in the root directory:

```bash
./run-ephemery-demo.sh
```

## Advanced Local Deployment

For more control over your local deployment, use the local deployment script:

```bash
./scripts/local/run-ephemery-local.sh
```

### Using a Custom Inventory

You can customize your deployment using an inventory file:

1. Generate a local inventory file:
   ```bash
   ./scripts/utils/generate_inventory.sh --type local --output my-local-inventory.yaml
   ```

2. Edit the file to customize directories and other settings

3. Validate your inventory file (recommended):
   ```bash
   ./scripts/utils/validate_inventory.sh my-local-inventory.yaml
   ```

4. Run with the custom inventory:
   ```bash
   ./scripts/local/run-ephemery-local.sh --inventory my-local-inventory.yaml
   ```

### Advanced Inventory Configuration

The local inventory file allows you to configure:
- Directory paths for data and logs
- Client versions (Docker images)
- Client-specific settings like cache size and peer counts

For detailed inventory configuration options and examples, see the [Inventory Management Guide](inventory-management.md).

## Monitoring

Once deployed, you can monitor your Ephemery node:

- Check Docker container status:
  ```bash
  docker ps
  ```
- View logs:
  ```bash
  docker logs -f ephemery-geth
  docker logs -f ephemery-lighthouse
  ```

## Cleanup

To stop containers and optionally remove data:

```bash
# Stop containers only
./scripts/utils/cleanup.sh

# Stop containers and remove data
./scripts/utils/cleanup.sh --data
```

For more configuration options, see the [Configuration Guide](configuration.md).
