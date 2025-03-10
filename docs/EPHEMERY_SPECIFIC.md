# Ephemery-Specific Configuration

This document provides essential information about Ephemery-specific configurations and optimizations used in this Ansible role.

## Ephemery Docker Images

| Client | Image | Version | Notes |
|--------|-------|---------|-------|
| Geth (Execution) | `pk910/ephemery-geth` | v1.15.3 | Pre-configured for Ephemery |
| Lighthouse (Consensus) | `pk910/ephemery-lighthouse` | latest | Pre-configured for Ephemery |

### Benefits

- Pre-configured genesis state and network parameters
- Automatic network reset handling
- Simplified deployment with built-in Ephemery configurations
- Optimized for faster synchronization

## Deployment Methods

### 1. Using Ansible (Recommended)

```bash
# Install requirements
ansible-galaxy collection install -r requirements.yaml
pip install -r requirements.txt

# Configure inventory.yaml with optimized parameters
# See example in inventory.yaml

# Run playbook
ansible-playbook -i inventory.yaml ephemery.yaml
```

### 2. Using Direct Script Deployment

For rapid deployment or testing purposes, use the included script:

```bash
# Configure settings in scripts/local/run-ephemery-local.sh
# Run script
./scripts/local/run-ephemery-local.sh
```

This script:

- Deploys to remote host via SSH
- Sets up directories and JWT authentication
- Configures and starts optimized Docker containers
- Includes all performance optimizations

## Critical Optimizations

### Execution Client (Geth)

```bash
--cache=4096           # Increase cache size for faster processing
--txlookuplimit=0      # Disable transaction lookup index
--syncmode=snap        # Use snap sync mode
--maxpeers=100         # Increase peer count
--db.engine=pebble     # Use Pebble DB for better performance
```

### Consensus Client (Lighthouse)

```bash
--target-peers=100                      # More peers for faster sync
--execution-timeout-multiplier=5        # Prevent timeouts
--allow-insecure-genesis-sync           # Enable optimized genesis sync
--genesis-backfill                      # Improve genesis sync performance
--disable-backfill-rate-limiting        # Remove sync rate limiting
--disable-deposit-contract-sync         # Skip unnecessary deposit contract operations
# Include bootstrap nodes for better connectivity
```

## Troubleshooting

### Reset After Network Regenesis

When Ephemery resets (every 24 hours), nodes may need manual intervention:

```bash
# Stop containers
docker stop ephemery-geth ephemery-lighthouse

# Clear data directories
rm -rf /root/ephemery/data/geth/* /root/ephemery/data/lighthouse/*

# Restart containers
docker start ephemery-geth
sleep 10
docker start ephemery-lighthouse
```

### Monitoring Sync Progress

```bash
# Lighthouse sync status
curl -s http://localhost:5052/eth/v1/node/syncing | jq

# Geth sync status
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545
```

### Common Issues

1. **Low Peer Count**
   - Check firewall settings (ports 30303, 9000)
   - Verify bootstrap nodes are correctly configured
   - Increase target peer count

2. **JWT Authentication Failures**
   - Ensure JWT secret file is mounted correctly in both containers
   - Verify file permissions (600)
   - Check execution endpoint URL is correct

3. **Slow Genesis Sync**
   - Verify all optimization flags are applied
   - Check system resources (CPU, memory, disk I/O)
   - Ensure SSD storage is used

## Resources

- [Ephemery Official Site](https://ephemery.dev/)
- [Ephemery Client Wrapper](https://github.com/pk910/ephemery-client-wrapper)
- [Ephemery Resources](https://github.com/ephemery-testnet/ephemery-resources)
