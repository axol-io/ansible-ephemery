# Ephemery Configuration Guide

This guide explains the available configuration options for Ephemery nodes.

## Inventory Files

Inventory files allow you to customize your Ephemery deployment. They are specified in YAML format.

### Local Inventory

A local inventory file (`local-inventory.yaml`) can include:

```yaml
local:
  base_dir: /path/to/ephemery      # Base directory for all Ephemery files
  data_dir: /path/to/ephemery/data # Data directory
  logs_dir: /path/to/ephemery/logs # Logs directory
  
  geth:
    image: pk910/ephemery-geth:v1.15.3
    cache: 4096
    max_peers: 100
    
  lighthouse:
    image: pk910/ephemery-lighthouse:latest
    target_peers: 100
```

### Remote Inventory

A remote inventory file (`remote-inventory.yaml`) includes server connection details:

```yaml
hosts:
  - host: your-server-ip-or-hostname  # Server IP or hostname
    user: your-username               # SSH username
    port: 22                          # SSH port (default: 22)
```

## Advanced Configuration

### Geth Options

The Geth execution client can be configured with these options:

- `cache`: Memory allocated to the database cache (default: 4096)
- `max_peers`: Maximum number of network peers (default: 100)
- `sync_mode`: Blockchain sync mode (default: snap)

### Lighthouse Options

The Lighthouse consensus client can be configured with:

- `target_peers`: Target number of peers to connect to (default: 100)
- `execution_timeout_multiplier`: Timeout multiplier for execution layer (default: 5)

## Port Usage

The default ports used by Ephemery are:

- 8545: Geth HTTP API
- 8546: Geth WebSocket API
- 8551: Geth Engine API
- 30303: Geth P2P (TCP/UDP)
- 5052: Lighthouse HTTP API
- 9000: Lighthouse P2P (TCP/UDP)

Ensure these ports are available on your machine and not blocked by firewalls. 