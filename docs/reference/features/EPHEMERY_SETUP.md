# Ephemery Testnet Setup and Maintenance Guide

## Overview

Ephemery is an ephemeral Ethereum testnet designed for regular resets. This document explains how to properly set up and maintain an Ephemery testnet node, including validator configuration.

## Table of Contents

- [How Ephemery Works](#how-ephemery-works)
- [Key Components](#key-components)
- [Setup Instructions](#setup-instructions)
- [Adding Validators](#adding-validators)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)
- [References](#references)

## How Ephemery Works

The Ephemery testnet has a unique design that differentiates it from other Ethereum testnets:

1. **Regular Resets**: The network resets to a new genesis state regularly (typically every 1-7 days)
2. **Validator Continuity**: Validators are carried forward to each new genesis state if they're included in the validators folder of the ephemery-genesis repository
3. **Fresh State**: Each reset creates a completely fresh state without any history, removing issues like state bloat, insufficient funds, or inactive validators

## Key Components

Our implementation includes the following components:

1. **Retention Script** (`ephemery_retention.sh`): Checks for network resets and updates the node
2. **Cron Job**: Runs the retention script every 5 minutes to stay in sync with network resets
3. **Ansible Playbook**: Deploys the retention script and sets up the cron job on your server

## Setup Instructions

### Prerequisites

- Docker installed on the target server
- Running ephemery-geth and ephemery-lighthouse containers
- Validator keys properly prepared

### Deployment Steps

1. **Deploy using Ansible**:
   ```bash
   ansible-playbook playbooks/deploy_ephemery_retention.yml
   ```

2. **Verify Installation**:
   ```bash
   # Check if the retention script is running
   tail -f /root/ephemery/logs/retention.log

   # Check container status
   docker ps | grep ephemery
   ```

3. **Monitor Sync Status**:
   ```bash
   docker logs ephemery-lighthouse | grep -E 'slot|sync|distance'
   ```

## Adding Validators

To add validators to the Ephemery testnet, follow these steps:

### Method 1: Using eth2-val-tools

Use the eth2-val-tools to generate validator keys with the correct fork version:
```bash
export MNEMONIC="your mnemonic"
eth2-val-tools deposit-data \
  --fork-version 0x10001008 \
  --source-max 200 \
  --source-min 0 \
  --validators-mnemonic="$MNEMONIC" \
  --withdrawals-mnemonic="$MNEMONIC" \
  --as-json-list | jq ".[] | \"0x\" + .pubkey + \":\" + .withdrawal_credentials + \":32000000000\"" | tr -d '"' > name-node1.txt
```

### Method 2: Using ethstaker-deposit-cli

Alternatively, use ethstaker-deposit-cli and process the output:
```bash
cat deposit_data-*.json | jq ".[] | \"0x\" + .pubkey + \":\" + .withdrawal_credentials + \":32000000000\"" | tr -d '"' > name-node1.txt
```

### Submit to Genesis Repository

1. Fork the [ephemery-testnet/ephemery-genesis](https://github.com/ephemery-testnet/ephemery-genesis) repository
2. Add your validator file to the validators folder
3. Create a pull request to have your validators included in the next iteration

## Troubleshooting

### Common Issues

#### Node Not Syncing
- Check if your retention script is running correctly (review logs)
- Verify that your containers can access the necessary ports
- Ensure you're using the correct container configuration

#### Validator Not Active
- Verify your validator keys are correctly included in the genesis repository
- Check if the validator container is running and properly configured
- Look for errors in the validator logs

#### Sync Issues
- Try forcibly resetting by running the retention script manually
- Check network connectivity and peer counts
- Verify your hardware meets the requirements

### JWT Authentication Issues

JWT authentication problems are one of the most common causes of sync failures in Ethereum nodes. If you experience issues with Geth and Lighthouse communication, specifically:

- Consensus client logs showing: "Execution endpoint is not synced"
- Execution client logs showing: "Beacon client online, but no consensus updates received"
- Clients running but stuck in "syncing" or "optimistic" mode

These may indicate JWT authentication issues. Common root causes include:

1. **Mismatched JWT secrets** between execution and consensus clients
2. **Incorrect JWT file paths** in container configuration
3. **Chain ID mismatches** (Geth must use 39438144 for Ephemery)
4. **Container networking issues** preventing client communication

For a detailed troubleshooting guide and fixes, see [JWT Authentication Troubleshooting](./JWT_AUTHENTICATION_TROUBLESHOOTING.md).

### Logs and Monitoring

Key logs to monitor:

1. **Retention Script Log**:
   ```bash
   tail -f /root/ephemery/logs/retention.log
   ```

2. **Lighthouse Logs**:
   ```bash
   docker logs ephemery-lighthouse
   ```

3. **Geth Logs**:
   ```bash
   docker logs ephemery-geth
   ```

## Advanced Configuration

### Custom Reset Interval

If you want to customize the reset interval locally (though you'll still follow the network reset):

1. Edit the `retention.vars` file in your config directory:
   ```bash
   nano /root/ephemery/config/retention.vars
   ```

2. Update the `GENESIS_RESET_INTERVAL` value (in seconds)

### Backup and Recovery

It's a good practice to back up:

1. Your validator keys
2. The `nodekey` file to maintain your network identity

## References

- [Official Ephemery Genesis Repository](https://github.com/ephemery-testnet/ephemery-genesis)
- [Ephemery Scripts Repository](https://github.com/ephemery-testnet/ephemery-scripts)
- [Ephemery Resources](https://github.com/ephemery-testnet/ephemery-resources)

## Related Documentation

- [Validator Key Management](./VALIDATOR_KEY_MANAGEMENT.md)
- [Monitoring Guide](./MONITORING.md)
- [Troubleshooting](../DEVELOPMENT/TROUBLESHOOTING.md)
