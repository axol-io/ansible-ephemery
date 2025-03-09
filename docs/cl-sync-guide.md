# Ephemery Consensus Layer (CL) and Execution Layer (EL) Sync Optimization Guide

This guide provides instructions to help you optimize your Consensus Layer and Execution Layer client sync for Ephemery. Follow these steps for the fastest possible sync.

## Prerequisites

- Docker installed and running on your server
- SSH access to your Ephemery node
- At least 8GB RAM and 4+ CPU cores recommended

## Quick Start

For the fastest possible sync, use the Ansible playbook with these optimized parameters in your inventory file:

```yaml
cl_extra_opts: "--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"
el_extra_opts: "--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100"
```

When using the playbook:
- Choose to clear your database for a fresh start (recommended): `clear_database: true`
- Use genesis sync instead of checkpoint sync if issues occur: `use_checkpoint_sync: false`

## Optimization Principles

Our optimization approach applies these key principles:

1. **Client Selection**:
   - Lighthouse for CL (fastest for genesis sync when checkpoint sync fails)
   - Geth for EL (optimized with snap sync mode)

2. **Memory Allocation**:
   - Execution client: 50% of available memory
   - Consensus client: 40% of available memory
   - Validator (if enabled): 10% of available memory

3. **Network Optimization**:
   - Increased peer limits for both clients
   - Proper execution timeout multiplier to prevent timeouts

4. **Bootstrap Nodes**:
   - Uses properly formatted bootstrap nodes with UDP ports

5. **Performance Flags**:
   - CL: Genesis backfill with rate limiting disabled
   - EL: Large cache, optimized transaction lookup, snap sync

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Checkpoint sync fails | Use genesis sync with `--allow-insecure-genesis-sync` flag |
| Low peer count | Ensure P2P ports are open and increase `--target-peers` and `--maxpeers` |
| Stuck at genesis | Clear database and try again with `clear_database: true` |
| Slow progress | Increase RAM allocation and cache size |
| Forkchoice errors | Ensure both EL and CL are running with proper JWT authentication |

## Manual Optimization

If you prefer to manually optimize:

1. **Stop and remove existing containers**:
   ```bash
   docker stop ephemery-lighthouse ephemery-geth
   docker rm ephemery-lighthouse ephemery-geth
   ```

2. **Clear databases** (optional but recommended):
   ```bash
   sudo rm -rf /opt/ephemery/data/lighthouse/*
   sudo rm -rf /opt/ephemery/data/geth/*
   ```

3. **Start Geth with optimized flags**:
   ```bash
   docker run -d --name ephemery-geth --restart=unless-stopped --network=host \
     -v /opt/ephemery/data/geth:/data \
     -v /opt/ephemery/jwt.hex:/jwt.hex \
     pk910/ephemery-geth:v1.15.3 \
     --datadir=/data \
     --authrpc.jwtsecret=/jwt.hex \
     --http --http.api=eth,net,web3,engine \
     --http.addr=0.0.0.0 --http.corsdomain=* --http.vhosts=* \
     --ws --ws.api=eth,net,web3,engine \
     --ws.addr=0.0.0.0 --ws.origins=* \
     --cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100
   ```

4. **Start Lighthouse with optimized flags**:
   ```bash
   docker run -d --name ephemery-lighthouse --restart=unless-stopped --network=host \
     -v /opt/ephemery/jwt.hex:/jwt.hex \
     -v /opt/ephemery/data/lighthouse:/data \
     -v /opt/ephemery/config/ephemery_network:/ephemery_config \
     pk910/ephemery-lighthouse:latest lighthouse beacon_node \
     --datadir=/data --execution-jwt=/jwt.hex --execution-endpoint=http://127.0.0.1:8551 \
     --http --http-address=0.0.0.0 --http-port=5052 --metrics --metrics-address=0.0.0.0 \
     --metrics-port=5054 --testnet-dir=/ephemery_config --target-peers=100 \
     --execution-timeout-multiplier=5 --allow-insecure-genesis-sync \
     --genesis-backfill --disable-backfill-rate-limiting
   ```

5. **Monitor sync progress**:
   ```bash
   # Check EL sync status
   docker logs ephemery-geth | grep -i sync | tail

   # Check CL sync status
   docker logs ephemery-lighthouse | grep -i sync | tail

   # Check CL peer count
   curl -s http://localhost:5052/eth/v1/node/peer_count | jq
   ```

## Understanding the Optimization Flags

### Execution Layer (Geth) Optimization Flags

- `--cache=4096`: Allocates 4GB of memory to the database cache for faster processing
- `--txlookuplimit=0`: Disables transaction lookup limit to reduce database size
- `--syncmode=snap`: Uses snap sync mode which is faster than full sync
- `--maxpeers=100`: Increases maximum peer connections for better network connectivity

### Consensus Layer (Lighthouse) Optimization Flags

- `--target-peers=100`: Increases target peer count for faster data acquisition
- `--execution-timeout-multiplier=5`: Increases timeout multiplier to prevent execution client timeouts
- `--allow-insecure-genesis-sync`: Enables genesis sync when checkpoint sync fails
- `--genesis-backfill`: Optimizes historical data sync from genesis
- `--disable-backfill-rate-limiting`: Removes rate limiting for faster backfill operation

## Monitoring Your Sync

To check if your sync is progressing properly:

1. **Check EL sync status**:
   ```bash
   docker logs ephemery-geth | grep -i sync | tail
   ```

   Look for messages indicating sync progress like "Imported new chain segment"

2. **Check CL sync status**:
   ```bash
   docker logs ephemery-lighthouse | grep -i sync | tail
   ```

   A good result will show "Syncing" with decreasing distance metrics

3. **Check CL peer count**:
   ```bash
   curl -s http://localhost:5052/eth/v1/node/peer_count | jq
   ```

   You should have at least 20-30 peers for optimal sync speed.

## Troubleshooting Common Issues

If you encounter issues with sync:

1. **Verify JWT Authentication**: Ensure the JWT secret is properly configured and accessible by both clients

2. **Check for Client-Specific Errors**:
   ```bash
   docker logs ephemery-geth | grep ERROR
   docker logs ephemery-lighthouse | grep ERRO
   ```

3. **Ensure Adequate System Resources**:
   - At least 8GB RAM, ideally 16GB+ for optimal performance
   - At least 4 CPU cores
   - At least 100GB SSD storage

4. **Network Connectivity**:
   - Ensure ports 30303 (tcp/udp) and 9000 (tcp/udp) are open
   - Check connectivity to bootstrap nodes
