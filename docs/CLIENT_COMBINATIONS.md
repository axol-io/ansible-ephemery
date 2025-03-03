# Supported Client Combinations

This document provides detailed information about the supported client combinations in the Ephemery testnet deployment and their specific configuration requirements.

## Available Clients

### Execution Clients

- **Geth**: Go Ethereum client (default)
- **Besu**: Java-based Ethereum client by Hyperledger
- **Nethermind**: .NET Core Ethereum client
- **Reth**: Rust implementation client
- **Erigon**: Efficiency-focused Ethereum client

### Consensus Clients

- **Lighthouse**: Rust implementation (default)
- **Teku**: Java implementation by ConsenSys
- **Prysm**: Go implementation by Prysmatic Labs
- **Lodestar**: TypeScript implementation

## Client Combination Matrix

| Execution Client | Consensus Client | Notes |
|------------------|------------------|-------|
| Geth | Lighthouse | Default combination, well-tested |
| Geth | Teku | Higher memory requirements for Teku |
| Geth | Prysm | Requires additional port configurations |
| Geth | Lodestar | Lightweight combination, good for testing |
| Besu | Lighthouse | Good stability, higher CPU usage |
| Besu | Teku | All-Java stack, consistent memory profile |
| Besu | Prysm | Mixed language stack |
| Besu | Lodestar | Experimental combination |
| Nethermind | Lighthouse | Good performance combination |
| Nethermind | Teku | Higher memory requirements |
| Nethermind | Prysm | Mixed language stack |
| Nethermind | Lodestar | Experimental combination |
| Reth | Lighthouse | Fast sync capabilities |
| Reth | Teku | Experimental combination |
| Reth | Prysm | Experimental combination |
| Reth | Lodestar | Experimental combination |
| Erigon | Lighthouse | Fast sync, larger disk requirements |
| Erigon | Teku | Experimental combination |
| Erigon | Prysm | Experimental combination |
| Erigon | Lodestar | Experimental combination |

## Client-Specific Configuration

### Geth-specific Configuration

```yaml
# Add to host_vars/<hostname>.yaml when using Geth
el: "geth"
# Optional Geth-specific settings:
geth_cache: 1024  # Cache size in MB
geth_maxpeers: 50 # Maximum number of peers
```

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

### Teku-specific Configuration

```yaml
# Add to host_vars/<hostname>.yaml when using Teku
cl: "teku"
# Teku requires more memory than other clients
cl_memory_limit: "{{ ((ansible_memory_mb.real.total * 0.90 * 0.5) | round | int) }}M"
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
