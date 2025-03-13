# Ephemery Troubleshooting Guide

This document provides solutions for common issues when running Ephemery nodes, with a focus on optimization, connectivity, and synchronization problems.

## Table of Contents

- [Sync Performance Issues](#sync-performance-issues)
- [Connectivity Issues](#connectivity-issues)
- [Validator Issues](#validator-issues)
- [Monitoring Sync Progress](#monitoring-sync-progress)
- [Deployment Method Issues](#deployment-method-issues)

## Automated Troubleshooting Script

We have developed a comprehensive troubleshooting script (`troubleshoot_ephemery.sh`) that automates the diagnosis and resolution of common Ephemery node issues. This script performs the following tasks:

1. **Docker Service Verification**: Checks if Docker is running and attempts to start it if not.
2. **Container Status Verification**: Verifies the status of Ephemery containers (Geth and Lighthouse).
3. **Docker Network Verification**: Checks the existence and configuration of the Docker network used by Ephemery.
4. **JWT Token Verification**: Validates the existence, permissions, and format of the JWT token used for client authentication.
5. **Container Networking Tests**: Tests network connectivity between containers to identify networking issues.
6. **Container Configuration Examination**: Examines container configurations, focusing on JWT token access.
7. **Log Analysis**: Analyzes recent logs for common error patterns.
8. **Automated Fixes**: Offers to automatically fix common issues, such as JWT token mismatches.

### Using the Troubleshooting Script

Run the script with root or sudo privileges:

```bash
sudo /opt/ephemery/scripts/troubleshoot_ephemery.sh
```

### Example Output

The script provides detailed, color-coded output to help identify issues:

```
=== Ephemery Node Troubleshooting ===
Starting comprehensive diagnostics...
Loading configuration from /opt/ephemery/config/ephemery_paths.conf

Step 1: Checking Docker service status
✓ Docker service is running

Step 2: Checking Ephemery containers
Current running containers:
CONTAINER ID   IMAGE                        COMMAND                  CREATED        STATUS        PORTS                                                                                   NAMES
a1b2c3d4e5f6   sigp/lighthouse:latest       "lighthouse bn --net…"   2 hours ago    Up 2 hours    0.0.0.0:5052-5053->5052-5053/tcp, 0.0.0.0:5054->5054/tcp                               ephemery-lighthouse
g7h8i9j0k1l2   ethereum/client-go:latest    "geth --datadir=/dat…"   2 hours ago    Up 2 hours    0.0.0.0:8545-8546->8545-8546/tcp, 0.0.0.0:8551->8551/tcp, 0.0.0.0:6060->6060/tcp      ephemery-geth
✓ Geth container is running
✓ Lighthouse container is running

... (additional output)
```

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

4. **Check container networking and DNS resolution**

   ```bash
   # Get container IPs
   GETH_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ephemery-geth)
   LIGHTHOUSE_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ephemery-lighthouse)
   
   # Test connectivity from Lighthouse to Geth
   docker exec ephemery-lighthouse ping -c 2 ephemery-geth
   docker exec ephemery-lighthouse ping -c 2 $GETH_IP
   
   # Test API endpoint connectivity
   docker exec ephemery-lighthouse curl -v http://ephemery-geth:8551
   ```

5. **Use IP address instead of container name**

   If DNS resolution between containers is failing, recreate the Lighthouse container using the Geth container's IP address:

   ```bash
   # Get Geth IP address
   GETH_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{if eq .NetworkID "ephemery-net"}}{{.IPAddress}}{{end}}{{end}}' ephemery-geth)
   
   # Stop and remove Lighthouse container
   docker stop ephemery-lighthouse
   docker rm ephemery-lighthouse
   
   # Recreate Lighthouse container with Geth IP
   docker run -d --name ephemery-lighthouse \
       --network ephemery \
       --restart unless-stopped \
       -v /root/ephemery/data/lighthouse:/ethdata \
       -v /root/ephemery/jwt.hex:/config/jwt-secret \
       -p 5052:5052 -p 9000:9000 -p 9000:9000/udp -p 8008:8008 \
       pk910/ephemery-lighthouse:latest \
       lighthouse beacon \
       --datadir /ethdata \
       --testnet-dir /ephemery_config \
       --execution-jwt /config/jwt-secret \
       --execution-endpoint http://$GETH_IP:8551 \
       --http --http-address 0.0.0.0 --http-port 5052 \
       --target-peers=100 \
       --execution-timeout-multiplier=5 \
       --allow-insecure-genesis-sync \
       --genesis-backfill \
       --disable-backfill-rate-limiting \
       --disable-deposit-contract-sync
   ```

6. **Create a dedicated network for the containers**

   If network issues persist, try creating a dedicated network:

   ```bash
   # Create a new network
   docker network create ephemery-net
   
   # Connect both containers to the new network
   docker network connect ephemery-net ephemery-geth
   docker network connect ephemery-net ephemery-lighthouse
   
   # Get the new IP addresses
   GETH_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{if eq .NetworkID "ephemery-net"}}{{.IPAddress}}{{end}}{{end}}' ephemery-geth)
   
   # Update Lighthouse configuration to use the new IP
   docker stop ephemery-lighthouse
   docker rm ephemery-lighthouse
   # Recreate with the new IP (see command above)
   ```

## Validator Issues

### Validator Keys Not Found

**Problem**: Validator fails to start with "no validator keys found" error.

**Solutions**:

1. **Verify key files exist in the correct location**:

   ```bash
   # Check if keys are present
   ls -la /root/ephemery/secrets/validator/keys/
   ```

2. **Ensure key file format is correct** (should be keystore-*.json files):

   ```bash
   # Look for proper keystore files
   find /root/ephemery/secrets/validator/keys/ -name "keystore-*.json"
   ```

3. **Verify file permissions**:

   ```bash
   # Check permissions - should be 0600
   ls -la /root/ephemery/secrets/validator/keys/

   # Fix permissions if needed
   chmod -R 0600 /root/ephemery/secrets/validator/keys/
   ```

4. **Check validation key extraction results**:

   ```bash
   # If using compressed keys, verify extraction worked:
   ls -la /root/ephemery/tmp/validator_keys/
   ```

### Password Issues

**Problem**: Validator fails with "incorrect password" or "unable to decrypt" errors.

**Solutions**:

1. **Verify password file exists and has correct content**:

   ```bash
   cat /root/ephemery/secrets/validator/passwords/validators.txt
   ```

2. **Ensure password file has correct permissions**:

   ```bash
   chmod 600 /root/ephemery/secrets/validator/passwords/validators.txt
   ```

3. **Recreate password file if needed**:

   ```bash
   echo "ephemery" > /root/ephemery/secrets/validator/passwords/validators.txt
   chmod 600 /root/ephemery/secrets/validator/passwords/validators.txt
   ```

### Validator Not Connecting to Beacon Node

**Problem**: Validator starts but cannot connect to beacon node.

**Solutions**:

1. **Check if the beacon node is running**:

   ```bash
   docker ps | grep lighthouse
   ```

2. **Verify API endpoint is correct**:

   ```bash
   # For Lighthouse
   curl -s http://127.0.0.1:5052/eth/v1/node/version
   ```

3. **Check validator logs for connection errors**:

   ```bash
   docker logs ephemery-validator-lighthouse
   ```

4. **Restart validator after ensuring beacon is synced**:

   ```bash
   docker restart ephemery-validator-lighthouse
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
   docker logs ephemery-validator-lighthouse
   ```

2. Verify all required volumes are mounted correctly

   ```bash
   docker inspect ephemery-validator-lighthouse | grep -A 10 Mounts
   ```

3. Ensure data directories exist and have correct permissions

   ```bash
   mkdir -p /root/ephemery/data/validator /root/ephemery/secrets/validator/keys
   chmod 755 -R /root/ephemery/data
   chmod 600 -R /root/ephemery/secrets/validator/keys
   ```

## Related Documentation

- [Development Setup Guide](./DEVELOPMENT_SETUP.md)
- [Validator Key Management](../FEATURES/VALIDATOR_KEY_MANAGEMENT.md)
- [Monitoring Guide](../FEATURES/MONITORING.md)

## Getting Help

If you encounter issues not covered in this troubleshooting guide, please:

1. Check the [Known Issues](../PROJECT_MANAGEMENT/KNOWN_ISSUES.md) document
2. Open an issue on the GitHub repository with detailed information about your problem
3. Join the Ephemery community Discord channel for real-time assistance 