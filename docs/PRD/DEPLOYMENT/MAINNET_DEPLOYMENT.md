# Ephemery Mainnet Deployment Guide

This document provides guidance for deploying Ephemery nodes in a production mainnet environment, addressing common issues and providing recommended configurations.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deployment Process](#deployment-process)
- [Common Issues and Solutions](#common-issues-and-solutions)
- [Mainnet Deployment Fix Script](#mainnet-deployment-fix-script)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Performance Tuning](#performance-tuning)

## Overview

Deploying Ephemery in a production mainnet environment requires special considerations due to its unique network characteristics. This guide addresses these specific requirements and provides solutions for common deployment issues.

## Prerequisites

Before deploying to mainnet, ensure you have:

- A server with the following minimum specifications:
  - 4+ CPU cores
  - 8+ GB RAM
  - 100+ GB SSD storage
  - Linux OS (Ubuntu 20.04+ recommended)

- Required software:
  - Docker and Docker Compose
  - Ansible 2.10+ (for automated deployment)
  - SSH access with sudo privileges

- Network requirements:
  - Open ports: 30303 (TCP/UDP), 9000 (TCP/UDP), 8545 (TCP), 5052 (TCP)
  - Stable internet connection with good bandwidth (25+ Mbps recommended)

## Deployment Process

The recommended deployment process for mainnet consists of the following steps:

### 1. Create Inventory File

Create a production inventory file with Ephemery-specific parameters:

```yaml
ephemery:
  children:
    geth_lighthouse:
      hosts:
        ephemery-mainnet:
          ansible_host: your_server_ip
          ansible_user: root
          # Client configurations
          el: geth
          cl: lighthouse
          validator_enabled: false # Set to true if running validators

          # Ephemery-specific configurations
          geth_image: "pk910/ephemery-geth:v1.15.3"
          lighthouse_image: "pk910/ephemery-lighthouse:v5.3.0"
          validator_image: "pk910/ephemery-lighthouse:v5.3.0"

          # Network directory
          ephemery_network_dir: "/opt/ephemery/config/ephemery_network"

          # Client parameters
          cl_extra_opts: "--testnet-dir=/opt/ephemery/config/ephemery_network --target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"
          el_extra_opts: "--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100 --db.engine=pebble"

          # Monitoring and automation
          monitoring_enabled: true
          sync_monitoring_enabled: true
          ephemery_automatic_reset: true
```

### 2. Deploy Base Infrastructure

Deploy the base infrastructure using the Ansible playbook:

```bash
ansible-playbook -i production-inventory.yaml ansible/playbooks/main.yaml
```

### 3. Set Up Network Directory

Ensure the Ephemery network directory is properly configured with the latest genesis:

```bash
# Manually via SSH
ssh root@your_server_ip "mkdir -p /opt/ephemery/config/ephemery_network && \
  cd /opt/ephemery/config/ephemery_network && \
  wget https://ephemery.dev/ephemery-latest/testnet-all.tar.gz && \
  tar -xzf testnet-all.tar.gz && \
  rm testnet-all.tar.gz"

# Or using the fix script
./scripts/fix_mainnet_deployment.sh --host your_server_ip
```

### 4. Deploy Monitoring (Optional)

Deploy monitoring with specific Ephemery metrics:

```bash
ansible-playbook -i production-inventory.yaml ansible/playbooks/monitoring.yaml
```

### 5. Set Up Ephemery Reset Automation

Configure automatic reset detection to handle Ephemery's weekly reset cycles:

```bash
./scripts/deploy_ephemery_retention.sh --inventory production-inventory.yaml
```

## Common Issues and Solutions

### 1. Client Container Failures

**Issue**: Containers repeatedly restart with errors like `invalid value 'ephemery' for '--network <network>'` or `invalid command: "geth"`.

**Solution**:
- Use Ephemery-specific client images (`pk910/ephemery-geth`, `pk910/ephemery-lighthouse`)
- Ensure testnet directory is properly mounted and referenced
- Use the fix script: `./scripts/fix_mainnet_deployment.sh --host your_server_ip`

### 2. Network Configuration Issues

**Issue**: Consensus client can't find genesis state or sync properly.

**Solution**:
- Ensure the latest genesis files are downloaded from the official repository
- Properly mount the testnet directory in the container
- Use the correct `--testnet-dir` flag pointing to the network directory

### 3. Monitoring Issues

**Issue**: Prometheus and Grafana containers restart due to missing configurations.

**Solution**:
- Deploy monitoring with the complete templates
- Use the fix script with `--fix-monitoring` flag

### 4. Checkpoint Sync Issues

**Issue**: Consensus client can't sync from checkpoint.

**Solution**:
- Test multiple checkpoint URLs to find the most reliable one
- Use optimized sync parameters in the consensus client
- Run the checkpoint sync fix: `./scripts/fix_checkpoint_sync.sh`

## Mainnet Deployment Fix Script

We provide a comprehensive fix script for addressing common mainnet deployment issues:

```bash
./scripts/fix_mainnet_deployment.sh --inventory production-inventory.yaml
```

Or directly via SSH:

```bash
./scripts/fix_mainnet_deployment.sh --host your_server_ip
```

The script performs the following:

1. Fixes client container configuration with proper Ephemery-specific images
2. Sets up the Ephemery network directory with the latest genesis
3. Fixes container parameters to correctly reference the testnet directory
4. Fixes checkpoint sync issues
5. Restarts services to apply all fixes

For more details, run:

```bash
./scripts/fix_mainnet_deployment.sh --help
```

## Monitoring and Maintenance

### Sync Status Monitoring

To monitor sync status:

```bash
./scripts/check_sync_status.sh --host your_server_ip
```

Or via direct API calls on the server:

```bash
# Check Lighthouse sync status
curl -s http://localhost:5052/eth/v1/node/syncing | jq

# Check Geth sync status
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545 | jq
```

### Retention Script Logs

To monitor genesis resets and retention script activity:

```bash
ssh root@your_server_ip "tail -f /opt/ephemery/logs/retention.log"
```

## Performance Tuning

For optimal mainnet performance, consider the following tuning parameters:

### Execution Client (Geth)

```bash
--cache=4096           # Increase for higher memory systems
--txlookuplimit=0      # Disable transaction lookup index (saves storage)
--syncmode=snap        # Use snap sync for faster initial sync
--maxpeers=100         # Increase for better network connectivity
--db.engine=pebble     # More efficient database engine
```

### Consensus Client (Lighthouse)

```bash
--target-peers=100                      # More peers for faster sync
--execution-timeout-multiplier=5        # Prevent timeouts
--allow-insecure-genesis-sync           # Enable optimized genesis sync
--genesis-backfill                      # Improve genesis sync performance
--disable-backfill-rate-limiting        # Remove sync rate limiting
--disable-deposit-contract-sync         # Skip unnecessary deposit contract operations
```

---

For further assistance or to report issues with mainnet deployment, please submit an issue through our issue tracking system or consult the [Ephemery Specific Configuration](../FEATURES/EPHEMERY_SPECIFIC.md) document.
