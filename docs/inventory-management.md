# Inventory Management

This guide explains how to manage inventory files for Ephemery deployments.

## Understanding Inventory Files

Inventory files in YAML format define the configuration for your Ephemery node deployment. There are two types of inventory files:

1. **Local Inventory**: For deploying on the local machine
2. **Remote Inventory**: For deploying to a remote server

## Using the Inventory Utilities

The Ephemery project includes utilities to help manage inventory files:

### Generating Inventory Files

You can generate inventory files from templates using the `generate_inventory.sh` utility:

```bash
./scripts/utils/generate_inventory.sh --type local --output my-inventory.yaml
```

Common options:
- `--type`: Specify `local` or `remote` (default: `local`)
- `--output`: Path to the output file (required)
- `--base-dir`: Base directory for Ephemery (default: `$HOME/ephemery`)
- `--data-dir`: Data directory (default: `$BASE_DIR/data`)
- `--logs-dir`: Logs directory (default: `$BASE_DIR/logs`)

For local inventory:
- `--geth-image`: Geth Docker image (default: `ethereum/client-go:latest`)
- `--geth-cache`: Geth cache size in MB (default: `4096`)
- `--geth-max-peers`: Geth max peers (default: `25`)
- `--lighthouse-image`: Lighthouse Docker image (default: `sigp/lighthouse:latest`)
- `--lighthouse-peers`: Lighthouse target peers (default: `30`)

For remote inventory:
- `--remote-host`: Remote host (required for remote type)
- `--remote-user`: Remote user (required for remote type)
- `--remote-port`: Remote SSH port (default: `22`)

### Validating Inventory Files

Before deployment, you can validate your inventory files using the `validate_inventory.sh` utility:

```bash
./scripts/utils/validate_inventory.sh my-inventory.yaml
```

This will check:
- YAML syntax
- Required fields
- Configuration structure

If you know the inventory type, you can specify it explicitly:

```bash
./scripts/utils/validate_inventory.sh my-inventory.yaml --type local
```

## Inventory Structure

### Local Inventory

```yaml
# Local Ephemery Node Configuration
local:
  # Base directory for Ephemery
  base_dir: "/path/to/ephemery"
  
  # Directory for node data
  data_dir: "/path/to/ephemery/data"
  
  # Directory for logs
  logs_dir: "/path/to/ephemery/logs"
  
  # Geth Configuration
  geth:
    image: "ethereum/client-go:latest"
    cache: 4096
    max_peers: 25
  
  # Lighthouse Configuration
  lighthouse:
    image: "sigp/lighthouse:latest"
    target_peers: 30
```

### Remote Inventory

```yaml
# Remote Ephemery Node Configuration
hosts:
  - host: example.com
    user: admin
    port: 22

# Node Configuration
remote:
  # Base directory for Ephemery
  base_dir: "/opt/ephemery"
  
  # Directory for node data
  data_dir: "/opt/ephemery/data"
  
  # Directory for logs
  logs_dir: "/opt/ephemery/logs"
  
  # Geth Configuration
  geth:
    image: "ethereum/client-go:latest"
    cache: 4096
    max_peers: 25
  
  # Lighthouse Configuration
  lighthouse:
    image: "sigp/lighthouse:latest"
    target_peers: 30
```

## Advanced Configuration Examples

### High-Performance Configuration

```yaml
local:
  base_dir: "/data/ephemery"
  data_dir: "/data/ephemery/data"
  logs_dir: "/data/ephemery/logs"
  
  geth:
    image: "ethereum/client-go:v1.12.0"
    cache: 8192
    max_peers: 50
  
  lighthouse:
    image: "sigp/lighthouse:v4.1.0"
    target_peers: 60
```

### Low-Resource Configuration

```yaml
local:
  base_dir: "/home/user/ephemery"
  data_dir: "/home/user/ephemery/data"
  logs_dir: "/home/user/ephemery/logs"
  
  geth:
    image: "ethereum/client-go:latest"
    cache: 2048
    max_peers: 10
  
  lighthouse:
    image: "sigp/lighthouse:latest"
    target_peers: 15
```

### Multi-Host Remote Configuration

For more complex setups, you can define multiple hosts in your remote inventory:

```yaml
hosts:
  - host: eth1.example.com
    user: admin
    port: 22
    role: execution
  - host: eth2.example.com
    user: admin
    port: 22
    role: consensus

remote:
  base_dir: "/opt/ephemery"
  data_dir: "/opt/ephemery/data"
  logs_dir: "/opt/ephemery/logs"
  
  geth:
    image: "ethereum/client-go:latest"
    cache: 4096
    max_peers: 25
  
  lighthouse:
    image: "sigp/lighthouse:latest"
    target_peers: 30
```

## Using Inventory Files with Deployment Scripts

To use your inventory file with deployment scripts:

### Local Deployment

```bash
./scripts/local/run-ephemery-local.sh --inventory my-local-inventory.yaml
```

### Remote Deployment

```bash
./scripts/remote/run-ephemery-remote.sh --inventory my-remote-inventory.yaml
``` 