# Optimized Sync for Ephemery

This document explains how to optimize sync performance for both Execution Layer (EL) and Consensus Layer (CL) clients in the Ephemery network.

## Overview

There are two sync strategies available for Consensus Layer clients in the Ephemery network:

1. **Genesis Sync**: More thorough sync from genesis block, but slower without optimizations
2. **Checkpoint Sync**: Faster initial sync by using a trusted checkpoint provider

**NOTE:** As of our latest testing, we now **recommend using genesis sync with optimized parameters** for Ephemery due to recurring issues with checkpoint sync providers. Our optimized configuration delivers fast sync even without checkpoint sync.

## Optimized Configuration

### Recommended Settings

For optimal sync performance in both execution and consensus layers, use these settings in your inventory or host_vars file:

```yaml
ephemery:
  hosts:
    ephemery-node1:
      # Disable checkpoint sync since it often fails
      use_checkpoint_sync: false
      # Clear database for a fresh start
      clear_database: true
      # Lighthouse optimization parameters for faster sync
      cl_extra_opts: "--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"
      # Geth optimization parameters for faster sync
      el_extra_opts: "--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100"
```

These optimized parameters provide:
- Faster execution layer sync using Geth's snap sync and optimized cache
- Accelerated consensus layer sync with genesis backfill and network optimizations
- Better resource utilization and peer connections

## Configuration Options

The Ephemery Ansible playbooks provide the following variables to control sync strategy:

| Variable | Recommended | Description |
|----------|-------------|-------------|
| `use_checkpoint_sync` | `false` | Whether to use checkpoint sync (true) or genesis sync (false) |
| `clear_database` | `true` | Whether to clear the database before starting the client (useful for resetting) |
| `cl_extra_opts` | See above | Extra optimization flags for the consensus client |
| `el_extra_opts` | See above | Extra optimization flags for the execution client |

## Execution Layer (Geth) Optimization Flags

These flags dramatically improve Geth sync performance:

- `--cache=4096`: Allocates 4GB of memory to the database cache for faster processing
- `--txlookuplimit=0`: Disables transaction lookup limit to reduce database size
- `--syncmode=snap`: Uses snap sync mode which is faster than full sync
- `--maxpeers=100`: Increases maximum peer connections for better network connectivity

## Consensus Layer (Lighthouse) Optimization Flags

These flags significantly accelerate Lighthouse sync:

- `--target-peers=100`: Increases target peer count for faster data acquisition
- `--execution-timeout-multiplier=5`: Increases timeout multiplier to prevent execution client timeouts
- `--allow-insecure-genesis-sync`: Enables genesis sync when checkpoint sync fails
- `--genesis-backfill`: Optimizes historical data sync from genesis
- `--disable-backfill-rate-limiting`: Removes rate limiting for faster backfill operation

## Bootnode Configuration (Important)

Proper peer discovery requires correctly formatted bootnode addresses. Lighthouse requires both TCP and UDP ports to be specified in the multiaddr format:

```yaml
# Correct format with UDP ports
bootstrap_nodes:
  - "/ip4/157.90.35.151/tcp/9000/udp/9000/p2p/16Uiu2HAmVZnsqvTNQ2ya1YG2qi6DQchqX57jF9zN2CukZnQY84wJ"
  - "/ip4/136.243.15.66/tcp/9000/udp/9000/p2p/16Uiu2HAmAwGWqGShumBQeUuivDyRMmCZjvbZsQwcEWYYLDVKvFjG"
  - "/ip4/88.198.2.150/tcp/9000/udp/9000/p2p/16Uiu2HAm8cEfaKtweXbT4koAuifKKJPm8q7TdpaVfWk9j5E5L2m3"
  - "/ip4/135.181.91.151/tcp/9000/udp/9000/p2p/16Uiu2HAmEP7X3JDcdAYLagNQxpJ24n3HDwLGxVVsWyv2aUHrXA5b"
```

Using addresses without UDP ports will result in errors like:
```
Error getting mapping to ENR: InvalidMultiaddr("A UDP port must be specified in the multiaddr")
```

## Client Image Selection

When running Ephemery nodes, always use the pk910 Ephemery-specific images:

```yaml
client_images:
  geth: 'pk910/ephemery-geth:v1.15.3'
  lighthouse: 'pk910/ephemery-lighthouse:latest'
  validator: 'pk910/ephemery-lighthouse:latest'
```

These images are preconfigured for the Ephemery network and include necessary optimizations.

## Resource Allocation

Properly allocating memory between clients improves sync performance:

```yaml
# Resource allocation
el_memory_percentage: 0.5  # 50% for execution client
cl_memory_percentage: 0.4  # 40% for consensus client
validator_memory_percentage: 0.1  # 10% for validator
```

## Monitoring Sync Progress

To monitor sync progress effectively:

```bash
# Check EL sync status
docker logs ephemery-geth | grep -i sync | tail

# Check CL sync status
docker logs ephemery-lighthouse | grep -i sync | tail

# Check CL peer count
curl -s http://localhost:5052/eth/v1/node/peer_count | jq
```

## Troubleshooting Common Issues

1. **JWT Secret**: Ensure the JWT secret is correctly configured and shared between Execution and Consensus clients.
2. **Execution Client Sync**: Verify that your execution client (e.g., Geth) is running and syncing properly.
3. **Low Peer Count**: Ensure P2P ports (30303 for Geth, 9000 for Lighthouse) are open in your firewall.
4. **Forkchoice Errors**: Make sure both clients are properly connected via the Engine API.

## Resetting the Database

If you need to reset your node completely:

```yaml
ephemery:
  hosts:
    ephemery-node1:
      clear_database: true
```

This will delete the existing database and perform a fresh sync.

## Advanced Manual Optimization

For advanced users who want to manually optimize:

```bash
# Stop and remove existing containers
docker stop ephemery-lighthouse ephemery-geth
docker rm ephemery-lighthouse ephemery-geth

# Clear databases
sudo rm -rf /opt/ephemery/data/lighthouse/*
sudo rm -rf /opt/ephemery/data/geth/*

# Start Geth with optimized flags
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

# Start Lighthouse with optimized flags
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

For additional troubleshooting guidance, see our [Troubleshooting Guide](TROUBLESHOOTING.md).
