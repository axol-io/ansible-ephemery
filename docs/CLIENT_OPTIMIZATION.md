# Ethereum Client Optimization Guide

This guide provides optimization strategies for Ethereum clients in the Ephemery network environment, with focus on sync strategies, resource allocation, and client-specific configurations.

## Table of Contents

- [Sync Strategies](#sync-strategies)
- [Resource Optimization](#resource-optimization)
- [Client-Specific Optimizations](#client-specific-optimizations)
- [Troubleshooting](#troubleshooting)

## Sync Strategies

### Checkpoint Sync (Recommended)

Checkpoint sync provides the fastest initial sync for Ephemery nodes, leveraging our enhanced checkpoint sync system.

**Recommended Checkpoint Sync Parameters:**

```yaml
use_checkpoint_sync: true
# Lighthouse optimization parameters
cl_extra_opts: "--target-peers=100 --execution-timeout-multiplier=5"
# Geth optimization parameters
el_extra_opts: "--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100"
```

### Genesis Sync

Genesis sync can be used as a fallback when checkpoint sync is not working in your environment.

```yaml
use_checkpoint_sync: false
# Lighthouse optimization parameters for genesis sync
cl_extra_opts: "--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting --disable-deposit-contract-sync"
# Geth optimization parameters
el_extra_opts: "--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100"
```

## Resource Optimization

Properly allocate system resources for optimal performance:

```yaml
# Memory allocation by percentage of total system memory
el_memory_percentage: 0.5      # Execution client (50%)
cl_memory_percentage: 0.4      # Consensus client (40%)
validator_memory_percentage: 0.1  # Validator (10%)
```

**System Recommendations:**

- Minimum 4 CPU cores (2 for execution, 2 for consensus)
- Minimum 8GB RAM
- 100GB+ SSD storage

## Client-Specific Optimizations

### Lighthouse

```yaml
# Optimized Lighthouse parameters for checkpoint sync
--target-peers=100
--execution-timeout-multiplier=5

# Additional parameters for genesis sync
--allow-insecure-genesis-sync
--genesis-backfill
--disable-backfill-rate-limiting
--disable-deposit-contract-sync

# Common configuration
--boot-nodes="/ip4/157.90.35.151/tcp/9000/udp/9000/p2p/16Uiu2HAmVZnsqvTNQ2ya1YG2qi6DQchqX57jF9zN2CukZnQY84wJ,/ip4/136.243.15.66/tcp/9000/udp/9000/p2p/16Uiu2HAmAwGWqGShumBQeUuivDyRMmCZjvbZsQwcEWYYLDVKvFjG,/ip4/88.198.2.150/tcp/9000/udp/9000/p2p/16Uiu2HAm8cEfaKtweXbT4koAuifKKJPm8q7TdpaVfWk9j5E5L2m3,/ip4/135.181.91.151/tcp/9000/udp/9000/p2p/16Uiu2HAmEP7X3JDcdAYLagNQxpJ24n3HDwLGxVVsWyv2aUHrXA5b"
```

**Parameter Explanation:**

- **target-peers=100**: Increases peer connections for faster block retrieval
- **execution-timeout-multiplier=5**: Extends timeout for execution client interactions
- **allow-insecure-genesis-sync**: Enables genesis sync optimizations (only for genesis sync)
- **genesis-backfill**: Improves genesis sync performance (only for genesis sync)
- **disable-backfill-rate-limiting**: Removes throttling during backfill (only for genesis sync)
- **disable-deposit-contract-sync**: Removes unnecessary deposit contract operations
- **boot-nodes**: Specific Ephemery bootstrap nodes for improved connectivity

### Geth

```yaml
# Optimized Geth parameters
--cache=4096
--txlookuplimit=0
--syncmode=snap
--maxpeers=100
```

**Parameter Explanation:**

- **cache=4096**: Allocates 4GB of memory for database caching
- **txlookuplimit=0**: Disables transaction lookup index for faster sync
- **syncmode=snap**: Uses snap sync for faster initial sync
- **maxpeers=100**: Increases peer connections for better block discovery

## Troubleshooting

### Common Sync Issues

1. **Checkpoint Sync Not Working**
   - Solution: Run the enhanced checkpoint sync tool to automatically test and select the best URL:
     ```bash
     ./scripts/maintenance/enhanced_checkpoint_sync.sh --apply
     ```

2. **Slow Genesis Sync**
   - Solution: Verify all optimization flags are applied, check peer connectivity, ensure SSD storage is used

3. **Execution Client Connection Issues**
   - Solution: Check JWT authentication, verify execution client is fully synced, increase timeout parameter

4. **Client Crashes After Network Reset**
   - Solution: Clear data directories and restart the containers:

     ```bash
     docker rm -f ephemery-geth ephemery-lighthouse
     rm -rf /root/ephemery/data/geth/* /root/ephemery/data/lighthouse/*
     # Restart containers
     ```

### Monitoring Sync Progress

```bash
# Check Lighthouse sync status
curl -s http://localhost:5052/eth/v1/node/syncing | jq

# Check Geth sync status
curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545

# Monitor system resources
docker stats
```

## Conclusion

Optimizing Ethereum clients requires balancing sync speed, resource usage, and reliability. Our current recommendation is to use checkpoint sync with the enhanced checkpoint sync tool for the best experience.

For additional client-specific information, refer to the official documentation:

- [Lighthouse Documentation](https://lighthouse-book.sigmaprime.io/)
- [Geth Documentation](https://geth.ethereum.org/docs)
- [Ephemery Network Information](./PRD/FEATURES/EPHEMERY_SPECIFIC.md)
- [Checkpoint Sync Documentation](./PRD/FEATURES/CHECKPOINT_SYNC.md)
- [Enhanced Checkpoint Sync](./PRD/FEATURES/CHECKPOINT_SYNC_FIX.md)
