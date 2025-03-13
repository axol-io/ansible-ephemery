# Ephemery-Specific Features

This document outlines features and configurations that are specific to Ephemery testnets.

## Table of Contents

- [Introduction](#introduction)
- [Ephemery Network Characteristics](#ephemery-network-characteristics)
- [Docker Images](#docker-images)
- [Deployment Methods](#deployment-methods)
- [Automatic Genesis Reset](#automatic-genesis-reset)
- [Critical Optimizations](#critical-optimizations)
- [Troubleshooting](#troubleshooting)
- [Adding Validators](#adding-validators)
- [Resources](#resources)

## Introduction

Ephemery testnets have unique characteristics compared to other Ethereum testnets, with the primary distinction being their regular resets.

## Ephemery Network Characteristics

Ephemery testnets are designed for rapid testing with regular resets (typically every 24 hours). This makes them ideal for testing state transitions, client implementations, and protocol changes without long-term state accumulation.

## Docker Images

Ephemery uses specialized Docker images pre-configured for its unique requirements:

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

## Automatic Genesis Reset

Ephemery testnet resets regularly (typically every 24 hours). Our implementation includes an automated retention system to handle these resets:

### 1. Deploying Retention Script System

```bash
# Deploy retention script and set up cron job
./scripts/deploy_ephemery_retention.sh
```

This will:
- Install the retention script on the target server
- Configure a cron job to run every 5 minutes
- Perform an initial check and reset if needed

### 2. How the Retention System Works

The retention system consists of these components:

1. **Retention Script** (`ephemery_retention.sh`):
   - Checks if the testnet has been reset by examining genesis time
   - Downloads the latest genesis files from the official repository
   - Resets node data while preserving critical files like node keys
   - Restarts clients with the new genesis state

2. **Cron Job**:
   - Runs the retention script every 5 minutes
   - Ensures the node stays in sync with network resets
   - Logs all activity for monitoring

3. **Deployment Playbook**:
   - Manages deployment across multiple servers
   - Validates the environment before deployment
   - Sets up monitoring and logging

### 3. Key Features

- **Automatic Detection**: Detects when the network has been reset
- **Clean Resets**: Preserves important data while ensuring clean resets
- **Monitoring**: Comprehensive logging of all reset activities
- **Recovery**: Self-healing capabilities for failed resets

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

### Manual Reset When Automatic System Fails

If the automatic retention system fails, you can manually reset the node:

```bash
# Run the retention script manually with verbose output
/root/ephemery/scripts/ephemery_retention.sh

# Check logs for errors
tail -f /root/ephemery/logs/retention.log

# Force a reset regardless of conditions
cd /root/ephemery && ./scripts/ephemery_retention.sh
```

### Monitoring Sync Progress

```bash
# Lighthouse sync status
curl -s http://localhost:5052/eth/v1/node/syncing | jq

# Geth sync status
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545

# Check retention script logs
tail -f /root/ephemery/logs/retention.log
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

4. **Retention Script Issues**
   - Verify the script has execute permissions
   - Check if cron is running properly with `crontab -l`
   - Ensure paths in the script match your environment
   - Check disk space for storing genesis files

## Adding Validators

To add validators to the Ephemery testnet:

1. Generate validator keys with the correct fork version
2. Format them according to Ephemery requirements
3. Submit them to the validators folder in the ephemery-genesis repository

For detailed instructions, see [Ephemery Setup](./EPHEMERY_SETUP.md).

## Resources

- [Ephemery Official Site](https://ephemery.dev/)
- [Ephemery Client Wrapper](https://github.com/pk910/ephemery-client-wrapper)
- [Ephemery Resources](https://github.com/ephemery-testnet/ephemery-resources)
- [Ephemery Genesis Repository](https://github.com/ephemery-testnet/ephemery-genesis)
- [Ephemery Scripts Repository](https://github.com/ephemery-testnet/ephemery-scripts)
