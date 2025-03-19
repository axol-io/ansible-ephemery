# Consensus Client Role

The Consensus Client role manages the setup, configuration, and operation of Ethereum consensus layer clients (formerly known as Eth2 clients). This role supports multiple consensus clients including Lighthouse, Prysm, Teku, Nimbus, and Lodestar.

## Role Overview

This role performs the following tasks:

- Installation of the selected consensus client
- Configuration of client-specific settings
- Creation of systemd services
- Directory structure setup
- Beacon node configuration and management
- Client version management and updates
- Integration with execution clients via JWT authentication

## Supported Clients

| Client | Status | Description |
|--------|--------|-------------|
| Lighthouse | ✅ | Rust implementation by Sigma Prime |
| Prysm | ✅ | Go implementation by Prysmatic Labs |
| Teku | ✅ | Java implementation by ConsenSys |
| Nimbus | ✅ | Nim implementation by Status |
| Lodestar | ✅ | TypeScript implementation by ChainSafe |

## Variables

### Required Variables

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `cl_client` | Consensus client to use (lighthouse, prysm, teku, nimbus, lodestar) | `lighthouse` |
| `cl_data_dir` | Directory for consensus client data | `/opt/ethereum/consensus` |
| `jwt_secret_path` | Path to JWT secret file | `{{ config_dir }}/jwt-secret` |

### Optional Variables

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `ethereum_network` | Ethereum network to connect to | `goerli` |
| `cl_p2p_port` | P2P port | `9000` |
| `cl_metrics_port` | Metrics port | `8008` |
| `cl_http_port` | HTTP API port | `5052` |
| `cl_service_enabled` | Whether to enable and start the service | `true` |
| `cl_log_dir` | Directory for client logs | `/var/log/ethereum` |
| `el_http_endpoint` | Execution client HTTP endpoint | `http://localhost:{{ el_http_port | default('8545') }}` |
| `el_ws_endpoint` | Execution client WebSocket endpoint | `ws://localhost:{{ el_ws_port | default('8546') }}` |
| `el_authrpc_endpoint` | Execution client Auth RPC endpoint | `http://localhost:{{ el_authrpc_port | default('8551') }}` |

### Client-Specific Variables

#### Lighthouse

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `lighthouse_data_dir` | Lighthouse-specific data directory | `{{ cl_data_dir }}/lighthouse` |
| `lighthouse_target_peers` | Number of target peers | `70` |
| `lighthouse_max_peers` | Maximum number of peers | `100` |
| `lighthouse_execution_timeout` | Execution timeout in seconds | `60` |

#### Prysm

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `prysm_data_dir` | Prysm-specific data directory | `{{ cl_data_dir }}/prysm` |
| `prysm_p2p_max_peers` | Maximum number of P2P peers | `45` |
| `prysm_rpc_host` | RPC host | `127.0.0.1` |
| `prysm_rpc_port` | RPC port | `4000` |

#### Teku

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `teku_data_dir` | Teku-specific data directory | `{{ cl_data_dir }}/teku` |
| `teku_network_interface` | Network interface | `0.0.0.0` |
| `teku_jvm_options` | JVM options for Teku | `-Xmx4g` |
| `teku_log_destination` | Log destination | `CONSOLE` |

#### Nimbus

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `nimbus_data_dir` | Nimbus-specific data directory | `{{ cl_data_dir }}/nimbus` |
| `nimbus_max_peers` | Maximum number of peers | `160` |
| `nimbus_web3_url` | Web3 URL for execution client | `{{ el_ws_endpoint }}` |
| `nimbus_log_level` | Log level | `INFO` |

#### Lodestar

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `lodestar_data_dir` | Lodestar-specific data directory | `{{ cl_data_dir }}/lodestar` |
| `lodestar_max_peers` | Maximum number of peers | `50` |
| `lodestar_execution_urls` | Execution client URLs | `[{{ el_http_endpoint }}]` |
| `lodestar_log_level` | Log level | `info` |

## Example Usage

```yaml
# Basic usage with Lighthouse
- name: Deploy consensus client
  hosts: ethereum_nodes
  roles:
    - role: consensus_client
      vars:
        cl_client: lighthouse
        cl_data_dir: /data/ethereum/consensus
        ethereum_network: goerli
        
# Advanced usage with Teku
- name: Deploy consensus client with custom settings
  hosts: ethereum_nodes
  roles:
    - role: consensus_client
      vars:
        cl_client: teku
        cl_data_dir: /data/ethereum/consensus
        cl_p2p_port: 9100
        cl_metrics_port: 8018
        ethereum_network: sepolia
        teku_jvm_options: "-Xmx8g"
```

## Dependencies

- Requires the `common` role for foundational setup
- Requires Ansible 2.9 or higher
- Specific OS package dependencies vary by client:
  - Lighthouse: No special dependencies
  - Prysm: No special dependencies
  - Teku: Requires Java 11+
  - Nimbus: No special dependencies
  - Lodestar: Requires Node.js and NPM

## Handlers

| Handler Name | Description |
|--------------|-------------|
| `restart lighthouse` | Restart the Lighthouse service |
| `restart prysm` | Restart the Prysm service |
| `restart teku` | Restart the Teku service |
| `restart nimbus` | Restart the Nimbus service |
| `restart lodestar` | Restart the Lodestar service |

## File Structure

```
consensus_client/
├── defaults/
│   └── main.yml         # Default variable values
├── tasks/
│   ├── main.yml         # Main task entry point
│   ├── directories.yml  # Directory setup
│   ├── lighthouse.yml   # Lighthouse-specific tasks
│   ├── prysm.yml        # Prysm-specific tasks
│   ├── teku.yml         # Teku-specific tasks
│   ├── nimbus.yml       # Nimbus-specific tasks
│   ├── lodestar.yml     # Lodestar-specific tasks
│   └── service.yml      # Service configuration
├── handlers/
│   └── main.yml         # Handlers for the role
└── templates/
    ├── lighthouse.service.j2       # Lighthouse systemd service
    ├── prysm.service.j2            # Prysm systemd service
    ├── teku.service.j2             # Teku systemd service
    ├── nimbus.service.j2           # Nimbus systemd service
    ├── lodestar.service.j2         # Lodestar systemd service
    ├── lighthouse_config.j2        # Lighthouse configuration
    ├── prysm_config.j2             # Prysm configuration
    ├── teku_config.j2              # Teku configuration
    ├── nimbus_config.j2            # Nimbus configuration
    └── lodestar_config.j2          # Lodestar configuration
```

## Notes

- Different clients have different hardware requirements and performance characteristics
- Consensus clients require connection to an execution client via JWT authentication
- Initial sync may take significant time depending on the network and client used
- Consider disk space requirements carefully, especially for testnets with long history
- Metrics are exposed for monitoring and should be secured appropriately

## Troubleshooting

### Common Issues

1. **Connection Issues with Execution Client**:
   - Check that both execution and consensus clients are running
   - Verify JWT secret is accessible to both clients
   - Ensure ports are correctly configured and not blocked by firewall

2. **Sync Issues**:
   - Initial sync may take many hours depending on network and hardware
   - Check client logs with `journalctl -u <client_name>` for errors
   - Ensure sufficient disk space and I/O performance

3. **Service Failures**:
   - Check for port conflicts with other services
   - Verify permissions on data directories
   - Check system resource limits (RAM, open files)

4. **Client-Specific Issues**:
   - Lighthouse: May require more RAM during initial sync
   - Prysm: Requires separate beacon and validator processes for validators
   - Teku: Java heap size may need adjustment for different hardware
   - Nimbus: Efficient on lower-powered hardware but sync may be slower
   - Lodestar: May require Node.js version management

### Version Management

To update client versions, either:

1. Use the `update_ephemery.yml` playbook which handles updates gracefully
2. Manually update by setting specific version variables and re-running the role

## Related Documentation

- [Ethereum Consensus Clients](https://ethereum.org/en/developers/docs/nodes-and-clients/#consensus-clients)
- [Client Migration Guide](../CLIENT_MIGRATION_GUIDE.md) 