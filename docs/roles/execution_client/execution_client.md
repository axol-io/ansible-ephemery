# Execution Client Role

The Execution Client role manages the setup, configuration, and operation of Ethereum execution layer clients (formerly known as Eth1 clients). This role supports multiple execution clients including Geth, Nethermind, Besu, and Erigon.

## Role Overview

This role performs the following tasks:

- Installation of the selected execution client
- Configuration of client-specific settings
- Creation of systemd services
- Directory structure setup
- Optimized configuration for Ephemery networks
- Client version management and updates

## Supported Clients

| Client | Status | Description |
|--------|--------|-------------|
| Geth | ✅ | Go Ethereum, the official Go implementation |
| Nethermind | ✅ | .NET Core implementation focused on performance |
| Besu | ✅ | Java implementation by Hyperledger |
| Erigon | ✅ | Efficiency-focused Go implementation with fast sync |

## Variables

### Required Variables

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `el_client` | Execution client to use (geth, nethermind, besu, or erigon) | `geth` |
| `el_data_dir` | Directory for execution client data | `/opt/ethereum/execution` |
| `jwt_secret_path` | Path to JWT secret file | `{{ config_dir }}/jwt-secret` |

### Optional Variables

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `ethereum_network` | Ethereum network to connect to | `goerli` |
| `el_http_port` | HTTP RPC port | `8545` |
| `el_ws_port` | WebSocket port | `8546` |
| `el_p2p_port` | P2P port | `30303` |
| `el_metrics_port` | Metrics port | `6060` |
| `el_authrpc_port` | Auth RPC port | `8551` |
| `el_service_enabled` | Whether to enable and start the service | `true` |
| `el_log_dir` | Directory for client logs | `/var/log/ethereum` |

### Client-Specific Variables

#### Geth

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `geth_data_dir` | Geth-specific data directory | `{{ el_data_dir }}/geth` |
| `geth_cache_size` | Memory allocated for internal caching (MB) | `2048` |
| `geth_tx_pool_size` | Maximum number of executable transaction slots | `5000` |

#### Nethermind

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `nethermind_data_dir` | Nethermind-specific data directory | `{{ el_data_dir }}/nethermind` |
| `nethermind_memory_hint` | Memory hint for Nethermind in MB | `4000` |
| `nethermind_pruning_mode` | Database pruning mode | `archive` |

#### Besu

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `besu_data_dir` | Besu-specific data directory | `{{ el_data_dir }}/besu` |
| `besu_sync_mode` | Synchronization mode | `FAST` |
| `besu_jvm_options` | JVM options for Besu | `-Xmx4g` |

#### Erigon

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `erigon_data_dir` | Erigon-specific data directory | `{{ el_data_dir }}/erigon` |
| `erigon_sync_mode` | Synchronization mode | `snap` |
| `erigon_prune_mode` | Database pruning mode | `full` |

## Example Usage

```yaml
# Basic usage with Geth
- name: Deploy execution client
  hosts: ethereum_nodes
  roles:
    - role: execution_client
      vars:
        el_client: geth
        el_data_dir: /data/ethereum/execution
        ethereum_network: goerli
        
# Advanced usage with Nethermind
- name: Deploy execution client with custom settings
  hosts: ethereum_nodes
  roles:
    - role: execution_client
      vars:
        el_client: nethermind
        el_data_dir: /data/ethereum/execution
        el_http_port: 8645
        el_ws_port: 8646
        ethereum_network: sepolia
        nethermind_memory_hint: 8000
        nethermind_pruning_mode: full
```

## Dependencies

- Requires the `common` role for foundational setup
- Requires Ansible 2.9 or higher
- Specific OS package dependencies vary by client:
  - Geth: No special dependencies
  - Nethermind: Requires .NET runtime
  - Besu: Requires Java 11+
  - Erigon: No special dependencies

## Handlers

| Handler Name | Description |
|--------------|-------------|
| `restart geth` | Restart the Geth service |
| `restart nethermind` | Restart the Nethermind service |
| `restart besu` | Restart the Besu service |
| `restart erigon` | Restart the Erigon service |

## File Structure

```
execution_client/
├── defaults/
│   └── main.yml         # Default variable values
├── tasks/
│   ├── main.yml         # Main task entry point
│   ├── directories.yml  # Directory setup
│   ├── geth.yml         # Geth-specific tasks
│   ├── nethermind.yml   # Nethermind-specific tasks
│   ├── besu.yml         # Besu-specific tasks
│   ├── erigon.yml       # Erigon-specific tasks
│   └── service.yml      # Service configuration
├── handlers/
│   └── main.yml         # Handlers for the role
└── templates/
    ├── geth.service.j2             # Geth systemd service
    ├── nethermind.service.j2       # Nethermind systemd service
    ├── besu.service.j2             # Besu systemd service
    ├── erigon.service.j2           # Erigon systemd service
    ├── geth_config.j2              # Geth configuration
    ├── nethermind_config.j2        # Nethermind configuration
    ├── besu_config.j2              # Besu configuration
    └── erigon_config.j2            # Erigon configuration
```

## Notes

- Different clients have different hardware requirements and performance characteristics
- Not all features are equally supported across all clients
- JWT authentication is used for secure communication with consensus clients
- For high-security environments, consider additional network isolation
- Client metrics are exposed for monitoring and should be secured appropriately

## Troubleshooting

### Common Issues

1. **Port Conflicts**: If services fail to start due to port conflicts, check for other services using the defined ports and adjust the port variables accordingly.

2. **Service Failures**: Check service logs with `journalctl -u <client_name>` to diagnose issues.

3. **JWT Authentication Failures**: Ensure the JWT secret is properly configured and accessible by both execution and consensus clients.

4. **Data Directory Permissions**: Verify the appropriate permissions and ownership on the data directories with `ls -la {{ el_data_dir }}`.

### Version Management

To update client versions, either:

1. Use the `update_ephemery.yml` playbook which handles updates gracefully
2. Manually update by setting specific version variables and re-running the role

## Related Documentation

- [Ethereum Execution Clients](https://ethereum.org/en/developers/docs/nodes-and-clients/#execution-clients)
- [Client Migration Guide](../CLIENT_MIGRATION_GUIDE.md) 