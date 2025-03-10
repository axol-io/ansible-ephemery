# Ephemery Troubleshooting Guide

This document provides solutions for common issues when running Ephemery nodes, with focus on optimization, connectivity, and synchronization problems.

## Sync Performance Issues

### Slow Genesis Sync

**Problem**: Initial synchronization taking too long (expected: 8-12 hours with optimizations).

**Solution**:

1. **Apply optimization flags**:

   ```bash
   # Lighthouse optimizations
   --target-peers=100
   --execution-timeout-multiplier=5
   --allow-insecure-genesis-sync
   --genesis-backfill
   --disable-backfill-rate-limiting
   --disable-deposit-contract-sync

   # Geth optimizations
   --cache=4096
   --txlookuplimit=0
   --syncmode=snap
   --maxpeers=100
   --db.engine=pebble
   ```

2. **Check system resources**:
   - SSD storage (required for reasonable sync times)
   - Minimum 8GB RAM
   - At least 4 CPU cores
   - Check disk I/O with `iostat -xz 1`

3. **Check client logs for errors**:

   ```bash
   docker logs -f ephemery-geth
   docker logs -f ephemery-lighthouse
   ```

### Network Reset Handling

**Problem**: After Ephemery's daily reset, node stops syncing or shows invalid chain errors.

**Solution**:

1. Stop clients

   ```bash
   docker stop ephemery-geth ephemery-lighthouse
   ```

2. Clear data directories

   ```bash
   rm -rf /root/ephemery/data/geth/* /root/ephemery/data/lighthouse/*
   ```

3. Restart clients in correct order

   ```bash
   docker start ephemery-geth
   sleep 10  # Wait for execution client to initialize
   docker start ephemery-lighthouse
   ```

## Connectivity Issues

### Low Peer Count

**Problem**: Node connecting to few or no peers.

**Solutions**:

1. **Verify bootstrap nodes configuration**:
   - Include correct bootstrap nodes in configuration
   - Ensure UDP port is specified in bootnode addresses: `/ip4/<IP>/tcp/9000/udp/9000/p2p/<PEER_ID>`

2. **Check firewall settings**:
   - Port 30303 (TCP/UDP) for execution client
   - Port 9000 (TCP/UDP) for consensus client

3. **Increase target peers parameter**:

   ```bash
   --target-peers=100
   ```

### JWT Authentication Issues

**Problem**: Authorization errors between execution and consensus clients.

**Solutions**:

1. Verify JWT secret exists and has correct permissions

   ```bash
   ls -la /root/ephemery/jwt.hex  # Should be -rw------- (600)
   ```

2. Regenerate JWT secret if needed

   ```bash
   openssl rand -hex 32 | tr -d "\n" > /root/ephemery/jwt.hex
   chmod 600 /root/ephemery/jwt.hex
   ```

3. Ensure both containers mount the same JWT file

   ```bash
   docker inspect ephemery-geth | grep jwt
   docker inspect ephemery-lighthouse | grep jwt
   ```

## Monitoring Sync Progress

### Real-time Sync Status Commands

```bash
# Lighthouse sync status
curl -s http://localhost:5052/eth/v1/node/syncing | jq

# Geth sync status
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545 | jq

# Check peer counts
curl -s http://localhost:5052/eth/v1/node/peers | jq '.data | length'
```

### Interpreting Sync Status

For Lighthouse:

- `is_syncing: true` - Node is actively syncing
- `head_slot` vs `sync_distance` - Shows how far behind the node is
- Decreasing `sync_distance` indicates progress

For Geth:

- `"result": false` - Fully synced or snap sync in progress
- `"currentBlock"` vs `"highestBlock"` - Shows sync progress

## Deployment Method Issues

### Ansible Playbook Issues

**Problem**: Recursive templating errors or variable resolution problems.

**Solution**:

1. Explicitly define all directory paths in inventory.yaml

   ```yaml
   directories:
     base: "/root/ephemery"
     data: "/root/ephemery/data"
     secrets: "/root/ephemery/secrets"
     logs: "/root/ephemery/logs"
     scripts: "/root/ephemery/scripts"
     backups: "/root/ephemery/backups"
   jwt_secret_path: "/root/ephemery/jwt.hex"
   ```

2. Use the simpler direct script alternative for testing

   ```bash
   ./scripts/local/run-ephemery-local.sh
   ```

### Container Issues

**Problem**: Docker containers exit immediately after starting.

**Solution**:

1. Check logs for startup errors

   ```bash
   docker logs ephemery-geth
   docker logs ephemery-lighthouse
   ```

2. Verify all required volumes are mounted correctly

   ```bash
   docker inspect ephemery-geth | grep -A 10 Mounts
   docker inspect ephemery-lighthouse | grep -A 10 Mounts
   ```

3. Ensure data directories exist and have correct permissions

   ```bash
   mkdir -p /root/ephemery/data/geth /root/ephemery/data/lighthouse
   chmod 755 -R /root/ephemery/data
   ```
