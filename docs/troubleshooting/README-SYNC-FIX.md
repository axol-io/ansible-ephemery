# Ephemery Node Synchronization Fix

This document describes the issues and fixes for the Ephemery node synchronization problems.

## Issues Encountered

1. **Checkpoint Sync Incompatibility**: The checkpoint sync URL `https://checkpoint-sync.ephemery.ethpandaops.io` was returning a state that didn't match the block root expected by our node. This caused the sync to fail with:

   ```
   Failed to start beacon node: Snapshot state's most recent block root does not match block
   ```

2. **Network Connection Issues**: The Lighthouse container couldn't resolve the hostname `geth` when trying to connect to the execution client.

3. **Geth Execution Client Communication**: The Geth client was logging constant warnings about beacon client not being online:

   ```
   WARN [MM-DD|HH:MM:SS] Beacon client online, but no consensus updates received in a while. Please fix your beacon client to follow the chain!
   ```

## Working Solutions

### 1. Genesis Sync Configuration

The most reliable synchronization method was to use genesis sync with the following optimization flags:

```
lighthouse beacon \
  --testnet-dir=/data/testnet \
  --datadir=/data/lighthouse-data \
  --execution-jwt=/config/jwtsecret \
  --execution-endpoint=http://172.20.0.2:8551 \
  --http \
  --http-address=0.0.0.0 \
  --http-port=5052 \
  --metrics \
  --metrics-address=0.0.0.0 \
  --metrics-port=8008 \
  --target-peers=100 \
  --execution-timeout-multiplier=5 \
  --allow-insecure-genesis-sync \
  --genesis-backfill \
  --disable-backfill-rate-limiting
```

### 2. Network Connection Fix

Use the IP address of the execution client container directly instead of the hostname:

1. Find the IP address of the Geth container:

   ```
   docker inspect ephemery-geth | grep IPAddress
   ```

2. Use this IP in the execution-endpoint parameter:

   ```
   --execution-endpoint=http://172.20.0.2:8551
   ```

### 3. Database Clean Start

When switching synchronization methods, always clear the database directory:

```
rm -rf /data/ephemery/lighthouse-data/beacon
```

## Ansible Configuration Updates

Update `ansible/host_vars/ephemery-node1.yaml` with:

```yaml
# Optimization flags
cl_extra_opts: "--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"
el_extra_opts: "--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100"

# Disable checkpoint sync in favor of genesis sync
use_checkpoint_sync: false

# Network configuration
docker_network_name: ephemery-network
execution_client_ip: "172.20.0.2"
```

## Monitoring Sync Progress

Check the sync status with:

```
curl -s http://localhost:5052/eth/v1/node/syncing | jq
```

Check peer connections with:

```
curl -s http://localhost:5052/eth/v1/node/peer_count | jq
```

## Current Status

The node is now successfully syncing with the Ephemery network (iteration 144) using genesis sync method.
The sync progress indicates a sync distance of approximately 33,500 slots, which will take several hours to complete.
