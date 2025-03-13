# Supported Client Combinations

This document provides detailed information about the supported client combinations in the Ephemery testnet deployment and their specific configuration requirements.

## Overview

The Ephemery testnet supports multiple Ethereum execution and consensus client combinations, though implementation status varies. This document outlines currently supported clients, planned support for additional clients, and configuration details.

> **IMPORTANT NOTE**: Currently, only the **Geth + Lighthouse** client combination is fully implemented and supported. Other client combinations listed in this document are placeholders for future development and are not yet fully tested or supported.

## Available Clients

### Execution Clients

- **Geth**: Go Ethereum client (default and currently the only fully supported execution client)
- **Besu**: Java-based Ethereum client by Hyperledger (planned for future support)
- **Nethermind**: .NET Core Ethereum client (planned for future support)
- **Reth**: Rust implementation client (planned for future support)
- **Erigon**: Efficiency-focused Ethereum client (planned for future support)

### Consensus Clients

- **Lighthouse**: Rust implementation (default and currently the only fully supported consensus client)
- **Teku**: Java implementation by ConsenSys (planned for future support)
- **Prysm**: Go implementation by Prysmatic Labs (planned for future support)
- **Lodestar**: TypeScript implementation (planned for future support)

## Client Combination Matrix

| Execution Client | Consensus Client | Support Status |
|------------------|------------------|----------------|
| Geth | Lighthouse | ✅ Fully supported and tested |
| Geth | Teku | 🔄 Planned for future support |
| Geth | Prysm | 🔄 Planned for future support |
| Geth | Lodestar | 🔄 Planned for future support |
| Besu | Lighthouse | 🔄 Planned for future support |
| Besu | Teku | 🔄 Planned for future support |
| Besu | Prysm | 🔄 Planned for future support |
| Besu | Lodestar | 🔄 Planned for future support |
| Nethermind | Lighthouse | 🔄 Planned for future support |
| Nethermind | Teku | 🔄 Planned for future support |
| Nethermind | Prysm | 🔄 Planned for future support |
| Nethermind | Lodestar | 🔄 Planned for future support |
| Reth | Lighthouse | 🔄 Planned for future support |
| Reth | Teku | 🔄 Planned for future support |
| Reth | Prysm | 🔄 Planned for future support |
| Reth | Lodestar | 🔄 Planned for future support |
| Erigon | Lighthouse | 🔄 Planned for future support |
| Erigon | Teku | 🔄 Planned for future support |
| Erigon | Prysm | 🔄 Planned for future support |
| Erigon | Lodestar | 🔄 Planned for future support |

## Ephemery-Specific Images

For optimal performance with the Ephemery testnet, this role automatically uses specialized Docker images for certain client combinations:

| Client Type | Standard Selection | Ephemery-Specific Image | Notes |
|-------------|-------------------|-------------------------|-------|
| Execution   | `el: "geth"`      | `pk910/ephemery-geth`   | Pre-configured for Ephemery network |
| Consensus   | `cl: "lighthouse"`| `pk910/ephemery-lighthouse` | Includes built-in testnet configuration |

These specialized images are automatically used when you select the corresponding client in your configuration. For more details, see [Ephemery-Specific Configuration](./EPHEMERY_SPECIFIC.md).

## Client-Specific Configuration

### Geth-specific Configuration

```yaml
# Add to host_vars/<hostname>.yaml when using Geth
el: "geth"
# Optional Geth-specific settings:
geth_cache: 1024  # Cache size in MB
geth_maxpeers: 50 # Maximum number of peers
```

When `el: "geth"` is selected, the role automatically uses the `pk910/ephemery-geth` image which is pre-configured for the Ephemery network. This image includes a wrapper script that handles Ephemery-specific initialization and network resets.

### Besu-specific Configuration

```yaml
# Add to host_vars/<hostname>.yaml when using Besu
el: "besu"
# Optional Besu-specific settings:
besu_tx_pool_size: 2048  # Transaction pool size
```

### Nethermind-specific Configuration

```yaml
# Add to host_vars/<hostname>.yaml when using Nethermind
el: "nethermind"
# Optional Nethermind-specific settings:
nethermind_pruning: "memory"  # Pruning mode
```

### Lighthouse-specific Configuration

```yaml
# Add to host_vars/<hostname>.yaml when using Lighthouse
cl: "lighthouse"
# Optional Lighthouse-specific settings:
lighthouse_target_peers: 60
```

When `cl: "lighthouse"` is selected, the role automatically uses the `pk910/ephemery-lighthouse` image which is pre-configured for the Ephemery network. This image includes the necessary testnet configuration and handles network resets automatically.

### Teku-specific Configuration

```yaml
# Add to host_vars/<hostname>.yaml when using Teku
cl: "teku"
# Teku requires more memory than other clients
cl_memory_limit: '{{ ((ansible_memory_mb.real.total * 0.90 * 0.5) | round | int) }}M"
# Optional Teku-specific settings:
teku_validators_per_node: 1000
```

### Prysm-specific Configuration

```yaml
# Add to host_vars/<hostname>.yaml when using Prysm
cl: "prysm"
# Additional ports need to be opened for Prysm
prysm_additional_ports:
  - 13000  # Prysm P2P port
  - 3500   # Validator API
```

## Recommended Hardware Requirements by Combination

| Combination | CPU | RAM | Disk |
|-------------|-----|-----|------|
| Geth + Lighthouse | 4 cores | 8 GB | 500 GB SSD |
| Nethermind + Teku | 8 cores | 16 GB | 1 TB SSD |
| Erigon + Prysm | 8 cores | 16 GB | 2 TB SSD |
| Besu + Lodestar | 4 cores | 8 GB | 500 GB SSD |

## Testing Client Combinations

You can test different client combinations using the provided Molecule scenarios:

```bash
# Test Geth + Prysm combination
molecule/shared/scripts/demo_scenario.sh -e geth -c prysm

# Test Nethermind + Lighthouse combination
molecule/shared/scripts/demo_scenario.sh -e nethermind -c lighthouse
```

## Related Documentation

- [Ephemery-Specific Configuration](./EPHEMERY_SPECIFIC.md)
- [Client Optimization](../OPERATIONS/CLIENT_OPTIMIZATION.md)
- [Lighthouse Optimization](../OPERATIONS/LIGHTHOUSE_OPTIMIZATION.md)
- [Deployment Configuration](../DEPLOYMENT/CONFIGURATION.md) 