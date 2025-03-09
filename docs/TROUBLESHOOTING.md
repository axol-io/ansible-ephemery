# Ephemery Troubleshooting Guide

This document provides guidance for common issues when running Ephemery nodes, with a focus on sync issues and client connectivity problems.

## Bootnode Connectivity Issues

### Missing UDP Port in Bootnode Addresses

**Problem**: Lighthouse logs show errors like `Error getting mapping to ENR: InvalidMultiaddr("A UDP port must be specified in the multiaddr")`.

**Solution**:
- Bootnode addresses must include both TCP and UDP ports for proper peer discovery.
- Use the format: `/ip4/<IP>/tcp/9000/udp/9000/p2p/<PEER_ID>`
- Example: `/ip4/157.90.35.151/tcp/9000/udp/9000/p2p/16Uiu2HAmVZnsqvTNQ2ya1YG2qi6DQchqX57jF9zN2CukZnQY84wJ`

If you're seeing these errors in your logs, verify that your bootnode addresses in `inventory.yaml` or `ansible/defaults/main.yaml` include the UDP ports.

### Low Peer Count

**Problem**: Your node is connecting to very few peers (0-1), making sync extremely slow.

**Solution**:
1. Ensure bootnode addresses are correctly formatted with UDP ports
2. Increase the target peer count: `--target-peers=150`
3. Verify your firewall allows both TCP and UDP traffic on port 9000
4. Check if you're behind a NAT and consider port forwarding

## JWT Authentication Issues

**Problem**: Logs show `Failed jwt authorization` or `Auth(InvalidToken)` errors when the consensus client tries to connect to the execution client.

**Solution**:
1. Ensure the same JWT token is used by both clients
2. The JWT token should be a file, not a directory
3. Proper file permissions should be set (600)
4. Both clients should mount the same JWT file path

To manually fix JWT issues:

```bash
# Generate a new JWT token
openssl rand -hex 32 | tr -d '\n' > ~/ephemery/jwt.hex
chmod 600 ~/ephemery/jwt.hex

# Restart both clients with the correct JWT path
docker restart ephemery-geth ephemery-lighthouse
```

## Client Sync Issues

### Using the Right Client Images

**Problem**: Standard Ethereum client images may not work properly with Ephemery.

**Solution**:
- Use the Ephemery-specific pk910 images:
  - Execution client: `pk910/ephemery-geth:v1.15.3`
  - Consensus client: `pk910/ephemery-lighthouse:latest`

These images have built-in support for the Ephemery network and its configuration.

### Slow Sync Progress

**Problem**: Syncing is extremely slow or stuck.

**Solution**:
1. Check Lighthouse logs for sync status
2. For Lighthouse, add these optimization flags for faster genesis sync:
   ```
   --allow-insecure-genesis-sync
   --genesis-backfill
   --disable-backfill-rate-limiting
   ```
3. Consider using checkpoint sync if available: `use_checkpoint_sync: true`
4. Ensure the execution client is running before starting the consensus client

## Execution Client Issues

**Problem**: Execution client is not connecting to the consensus client.

**Solution**:
1. Check if JWT authentication is working correctly
2. Ensure the execution endpoint URL is correct (default: `http://127.0.0.1:8551`)
3. Verify the execution client can listen on the configured ports
4. For Geth, ensure auth RPC is configured with `--authrpc.jwtsecret=/path/to/jwt.hex`

## Monitoring Sync Progress

To monitor sync progress, use:

```bash
# Check Lighthouse sync status
docker logs ephemery-lighthouse | grep "Syncing\|sync\|peers"

# Check Geth status
docker logs ephemery-geth | grep "Looking for peers"
```

The complete sync process for Ephemery can take several hours to days depending on network conditions and server resources.
