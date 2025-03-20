# Validator Role

The Validator role manages the setup, configuration, and operation of Ethereum validators. This role handles validator key management, validator client setup, and integration with consensus clients.

## Role Overview

This role performs the following tasks:

- Validator client installation and configuration
- Validator key management and import
- Validator monitoring setup
- Integration with consensus clients
- Systemd service creation and management
- Fee recipient configuration
- MEV-boost integration (optional)

## Supported Validator Clients

The validator role supports various validator client implementations based on the selected consensus client:

| Consensus Client | Validator Implementation | Notes |
|------------------|--------------------------|-------|
| Lighthouse | Integrated validator | Same binary as the consensus client |
| Prysm | Separate validator | Dedicated validator process |
| Teku | Integrated validator | Same binary as the consensus client |
| Nimbus | Integrated validator | Same binary as the consensus client |
| Lodestar | Integrated validator | Same binary as the consensus client |

## Variables

### Required Variables

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `is_validator` | Whether to set up this node as a validator | `false` |
| `validator_client` | Validator client to use (follows `cl_client` if unset) | `{{ cl_client }}` |
| `validator_data_dir` | Directory for validator data | `/opt/ethereum/validator` |
| `validator_keys_dir` | Directory for validator keys | `{{ validator_data_dir }}/keys` |

### Optional Variables

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `validator_graffiti` | Validator graffiti text | `"ephemery"` |
| `validator_fee_recipient` | Address to receive transaction fees | `"0x0000000000000000000000000000000000000000"` |
| `validator_metrics_port` | Metrics port | `8009` |
| `validator_service_enabled` | Whether to enable and start the service | `true` |
| `validator_log_dir` | Directory for validator logs | `/var/log/ethereum` |
| `validator_import_keys` | Whether to import keys from local directory | `false` |
| `validator_keys_source` | Path to validator keys on control node | `./validator_keys` |

### MEV-Boost Variables

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `mev_boost_enabled` | Whether to enable MEV-Boost | `false` |
| `mev_boost_port` | MEV-Boost port | `18550` |
| `mev_boost_relays` | List of MEV-Boost relays | `[]` |
| `mev_boost_version` | MEV-Boost version to install | `"v1.5"` |

### Client-Specific Variables

#### Lighthouse Validator

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `lighthouse_validator_port` | Validator API port | `5062` |
| `lighthouse_validator_graffiti` | Validator graffiti | `{{ validator_graffiti }}` |

#### Prysm Validator

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `prysm_validator_port` | Validator API port | `7000` |
| `prysm_wallet_password_file` | Wallet password file path | `{{ validator_data_dir }}/password.txt` |
| `prysm_wallet_dir` | Wallet directory | `{{ validator_data_dir }}/wallet` |

#### Teku Validator

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `teku_validator_keys` | Path to validator keys | `{{ validator_keys_dir }}` |
| `teku_validator_jvm_options` | JVM options for Teku validator | `-Xmx2g` |

#### Nimbus Validator

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `nimbus_validator_keys` | Path to validator keys | `{{ validator_keys_dir }}` |
| `nimbus_validator_log_level` | Log level | `INFO` |

#### Lodestar Validator

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `lodestar_validator_port` | Validator API port | `7500` |
| `lodestar_validator_keys` | Path to validator keys | `{{ validator_keys_dir }}` |

## Example Usage

```yaml
# Basic validator setup with Lighthouse
- name: Deploy validator node
  hosts: validator_nodes
  roles:
    - role: common
    - role: execution_client
      vars:
        el_client: geth
    - role: consensus_client
      vars:
        cl_client: lighthouse
    - role: validator
      vars:
        is_validator: true
        validator_client: lighthouse
        validator_graffiti: "ephemery-validator"
        validator_fee_recipient: "0x1234567890123456789012345678901234567890"

# Advanced validator setup with MEV-Boost
- name: Deploy validator node with MEV-Boost
  hosts: validator_nodes
  roles:
    - role: validator
      vars:
        is_validator: true
        validator_client: teku
        validator_graffiti: "ephemery-mev"
        validator_fee_recipient: "0x1234567890123456789012345678901234567890"
        mev_boost_enabled: true
        mev_boost_relays:
          - "https://mainnet-relay.securerpc.com"
          - "https://boost-relay.flashbots.net"
```

## Dependencies

- Requires the `common` role for foundational setup
- Requires a consensus client to be set up (consensus_client role)
- Requires an execution client to be set up (execution_client role)
- Requires Ansible 2.9 or higher

## Validators on Separate Nodes

For production setups, it's recommended to separate validator clients from the consensus nodes:

1. Set up execution and consensus clients on beacon nodes
2. Set up validator clients on separate validator nodes
3. Configure the validator clients to connect to the beacon nodes via their API endpoints

Example:
```yaml
# On validator node
- name: Set up validator on separate node
  hosts: validator_nodes
  roles:
    - role: validator
      vars:
        is_validator: true
        validator_client: lighthouse
        cl_api_endpoint: "http://beacon-node:5052"  # Remote beacon node API
```

## Key Management

The validator role provides several options for key management:

1. **Local Import**: Set `validator_import_keys: true` and specify `validator_keys_source` to import keys from the control node
2. **Manual Management**: Manage keys outside of Ansible and place them in `validator_keys_dir`
3. **CLI Tools**: Use client-specific tools for key generation and management

### Key Import Process

If `validator_import_keys` is enabled, the role will:

1. Copy validator keys from the control node to the target node
2. Import the keys to the client-specific format if needed
3. Set appropriate permissions for the key files
4. Clean up temporary files after import

## File Structure

```
validator/
├── defaults/
│   └── main.yml         # Default variable values
├── tasks/
│   ├── main.yml         # Main task entry point
│   ├── directories.yml  # Directory setup
│   ├── keys.yml         # Key management
│   ├── lighthouse.yml   # Lighthouse-specific tasks
│   ├── prysm.yml        # Prysm-specific tasks
│   ├── teku.yml         # Teku-specific tasks
│   ├── nimbus.yml       # Nimbus-specific tasks
│   ├── lodestar.yml     # Lodestar-specific tasks
│   ├── mev_boost.yml    # MEV-Boost setup
│   └── service.yml      # Service configuration
├── handlers/
│   └── main.yml         # Handlers for the role
└── templates/
    ├── lighthouse_validator.service.j2  # Lighthouse service
    ├── prysm_validator.service.j2       # Prysm service
    ├── teku_validator.service.j2        # Teku service
    ├── nimbus_validator.service.j2      # Nimbus service
    ├── lodestar_validator.service.j2    # Lodestar service
    └── mev_boost.service.j2             # MEV-Boost service
```

## Security Considerations

Running validators requires careful security considerations:

1. **Key Security**: Validator keys control your staked ETH. Secure them properly!
2. **Separate Nodes**: Consider running validators on separate machines from beacon nodes
3. **Firewall Configuration**: Validator nodes do not need to accept inbound connections
4. **Regular Backups**: Backup validator keys and slashing protection data regularly
5. **Monitoring**: Set up alerts for validator performance and issues

## Monitoring

The validator role includes basic monitoring setup:

1. Metrics exposition on `validator_metrics_port`
2. Log management in `validator_log_dir`
3. Service status monitoring via systemd

For comprehensive monitoring, integrate with the monitoring setup playbook.

## Troubleshooting

### Common Issues

1. **Key Import Problems**:
   - Check file permissions on key directories
   - Verify key format matches expected client format
   - Look for key-specific errors in logs

2. **Connection Issues with Beacon Node**:
   - Ensure beacon API endpoint is accessible
   - Check network connectivity between validator and beacon nodes
   - Verify that the beacon node API is enabled and running

3. **Missed Attestations**:
   - Check time synchronization on all nodes
   - Ensure beacon node is fully synced
   - Look for errors in validator logs

4. **MEV-Boost Issues**:
   - Verify MEV-Boost service is running
   - Check connectivity to relays
   - Look for timeout or connection errors in logs

## Related Documentation

- [Ethereum Staking Documentation](https://ethereum.org/en/staking/)
- [Client Migration Guide](../CLIENT_MIGRATION_GUIDE.md)
- [MEV-Boost Documentation](https://boost.flashbots.net/)
