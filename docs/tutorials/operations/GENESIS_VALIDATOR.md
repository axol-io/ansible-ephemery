---
id: genesis_validator
title: Genesis Validator Guide
sidebar_label: Genesis Validator
description: Complete guide for setting up and operating genesis validators on the Ephemery testnet
keywords:
  - validator
  - genesis
  - ephemery
  - setup
---

# Genesis Validator Guide

This guide provides comprehensive instructions for setting up and operating a genesis validator on the Ephemery testnet.

## Overview

Genesis validators are validators that participate in the network from block 0. As a genesis validator, you have additional responsibilities and requirements compared to regular validators who join after genesis.

## Prerequisites

Before setting up a genesis validator, ensure you have:

1. **Hardware Requirements**:
   - CPU: 4+ cores
   - RAM: 16GB+
   - Storage: 100GB+ SSD
   - Stable internet connection

2. **Software Requirements**:
   - Linux operating system (Ubuntu 22.04 LTS recommended)
   - Docker (optional, for containerized deployments)
   - Git
   - Ansible

3. **Knowledge Requirements**:
   - Basic command line knowledge
   - Understanding of Ethereum consensus
   - Familiarity with validator operations

## Setup Process

### 1. Repository Setup

Clone the Ephemery repository and install required dependencies:

```bash
git clone https://github.com/your-org/ansible-ephemery.git
cd ansible-ephemery
bash scripts/install-collections.sh
```

### 2. Generate Validator Keys

For genesis validators, you must generate keys and submit them before genesis:

```bash
# Navigate to the scripts directory
cd scripts/core

# Generate keys
./validator.sh --generate

# This will output your validator keys in the specified directory
```

The script will create:
- Validator keys
- Withdrawal credentials
- Deposit data

### 3. Submit Keys to Genesis

For Ephemery testnet, you need to submit your generated keys to the testnet coordinator. The Ephemery Genesis repository accepts validator submissions through text files:

```bash
# Using eth2-val-tools
export MNEMONIC="your mnemonic"
eth2-val-tools deposit-data --fork-version 0x10001008 --source-max 200 --source-min 0 --validators-mnemonic="$MNEMONIC" --withdrawals-mnemonic="$MNEMONIC" --as-json-list | jq ".[] | \"0x\" + .pubkey + \":\" + .withdrawal_credentials + \":32000000000\"" | tr -d '"' > name-node1.txt

# Alternatively, using ethstaker-deposit-cli
# Use ethstaker-deposit-cli with Ephemery validator key support
cat deposit_data-*.json | jq ".[] | \"0x\" + .pubkey + \":\" + .withdrawal_credentials + \":32000000000\"" | tr -d '"' > name-node1.txt
```

The ansible-ephemery system simplifies this process with automated scripts that handle the key generation and submission formatting:

```bash
# Generate and format keys for submission
./scripts/utilities/genesis_validator_key_submit.sh --name "your-node-name"
```

After generating your submission file:
1. Submit a pull request to the [Ephemery Genesis repository](https://github.com/ephemery-testnet/ephemery-genesis) with your file in the `validators` folder
2. Keep your validator keys secure and backed up
3. Wait for confirmation that your validator has been included in genesis
4. Your validator will be included in the next network reset

### 4. Configure Genesis Validator

Edit the `inventory.yaml` file to enable genesis validator mode:

```yaml
# Enable genesis validator mode
genesis_validator: true

# Specify the path to your validator keys
validator_keys_path: "/path/to/validator_keys"

# Configure withdrawal credentials (optional)
withdrawal_credentials: "0x..."
```

### 5. Deploy the Validator

Run the deployment script with genesis validator flags:

```bash
cd /path/to/ansible-ephemery
./scripts/deployment/deploy-ephemery.sh --genesis-validator
```

This script will:
- Deploy the Ephemery node with genesis configuration
- Import your validator keys
- Configure the client for genesis participation
- Set up automatic reset handling

## Operational Procedures

### Handling Resets

Ephemery testnet resets periodically. As a genesis validator, you need to handle these resets properly:

1. **Automatic Reset Handling**:
   ```bash
   # Setup the retention script as a cron job to handle resets
   ./scripts/deployment/deploy_ephemery_retention.sh
   ```

2. **Verify Cron Configuration**:
   ```bash
   crontab -l | grep ephemery
   ```
   You should see an entry that runs the retention script every 5 minutes.

### Monitoring Validator Performance

To ensure your genesis validator is performing optimally:

1. **Setup Validator Monitoring**:
   ```bash
   ./scripts/monitoring/validator_performance_monitor.sh --setup
   ```

2. **Check Validator Status**:
   ```bash
   ./scripts/monitoring/check_ephemery_status.sh --validator
   ```

3. **View Detailed Metrics**:
   ```bash
   ./scripts/monitoring/key_performance_metrics.sh
   ```

### Key Management

Proper key management is critical for genesis validators:

1. **Backup Keys**:
   Always maintain secure backups of your validator keys in multiple locations.

2. **Key Rotation** (if needed):
   ```bash
   ./scripts/utilities/key_management.sh --rotate
   ```

3. **Emergency Exit**:
   In case of emergency, you can exit your validator:
   ```bash
   ./scripts/core/validator.sh --exit
   ```

## Genesis-Specific Configuration

Genesis validators require special configuration parameters:

```yaml
# Example genesis validator configuration
cl_extra_opts: "--genesis-state=/path/to/genesis.ssz --genesis-validator"
el_extra_opts: "--genesis=/path/to/genesis.json"
```

These parameters ensure your node correctly starts from genesis and participates in block validation from the beginning.

## Troubleshooting

### Common Issues

#### Validator Not Selected for Genesis

**Symptoms**: Validator index not appearing in genesis.json

**Solution**:
1. Verify your deposit data was correctly submitted
2. Check if you missed the submission deadline
3. Contact the Ephemery team to confirm your inclusion status

#### Failed to Sync at Genesis

**Symptoms**: Node fails to sync after genesis

**Solution**:
1. Verify your genesis files match the official files
2. Check client logs for specific errors
3. Use checkpoint sync as a fallback:
   ```bash
   ./scripts/maintenance/enhance_checkpoint_sync.sh --reset
   ```

#### Missed Attestations

**Symptoms**: Validator missing attestations

**Solution**:
1. Check if your node is fully synced
2. Verify your system time is accurate (use NTP)
3. Check client logs for errors
4. Ensure your node has network connectivity to peers

## Performance Optimization

To optimize your genesis validator performance:

1. **Client Performance Tuning**:
   ```yaml
   # High-performance configuration for validators
   cl_extra_opts: "--target-peers=100 --execution-timeout-multiplier=5"
   el_extra_opts: "--cache=4096 --txlookuplimit=0 --maxpeers=100"
   ```

2. **System Optimization**:
   - Adjust kernel parameters for network performance
   - Enable disk I/O optimizations
   - Ensure sufficient memory is available

3. **Monitoring Optimization**:
   - Set up alerts for missed attestations
   - Monitor system resource usage
   - Track sync status continuously

## Best Practices

1. **Regular Backups**:
   - Back up validator keys securely
   - Back up node configuration
   - Document all custom settings

2. **Security Measures**:
   - Use a dedicated machine for validation
   - Implement proper firewall rules
   - Keep software updated
   - Use strong SSH authentication

3. **Operational Discipline**:
   - Regularly check logs and performance
   - Test reset procedures before they happen
   - Maintain contact with the Ephemery team
   - Document all operational procedures

## Additional Resources

- [Ephemery Testnet Website](https://ephemery.dev/)
- [Client Documentation](https://lighthouse-book.sigmaprime.io/)
- [Validator Monitoring Guide](../FEATURES/VALIDATOR_PERFORMANCE_MONITORING.md)
- [Checkpoint Sync Documentation](../FEATURES/ENHANCED_CHECKPOINT_SYNC.md)
- [Resetter Configuration Guide](./RESETTER_CONFIGURATION.md)

## FAQ

**Q: How often does the Ephemery testnet reset?**

A: The Ephemery testnet typically resets every 2 weeks, though this schedule may vary. The reset process is automated, and your node should handle it if properly configured.

**Q: What happens to my validator during a reset?**

A: During a reset, all chain data is cleared, and the network starts from a new genesis. Your validator will automatically rejoin if the retention script is properly configured.

**Q: Do I need to resubmit my keys after each reset?**

A: No, once your keys are included in the genesis configuration, they will be automatically included in subsequent resets without further action.

**Q: Can I use the same keys for mainnet and Ephemery?**

A: No, never use the same validator keys between networks. Always generate separate keys for each network you participate in.

**Q: How can I tell if my validator is included in genesis?**

A: You can check the genesis.ssz file or verify your validator index appears in the Ephemery explorer after genesis.

## Handling Iteration Resets

Ephemery testnet resets every iteration (approximately monthly). As a genesis validator:

1. **Automatic Reset Handling**:
   The ansible-ephemery system provides a robust retention script based on the original Ephemery Genesis retention.sh script:
   ```bash
   # Setup the retention script as a cron job to handle resets
   ./scripts/deployment/deploy_ephemery_retention.sh
   ```

   This script:
   - Polls for new genesis states every 5 minutes
   - Automatically downloads new genesis configuration
   - Resets the database when necessary
   - Restarts the clients with the new genesis

2. **Verify Cron Configuration**:
   ```bash
   crontab -l | grep ephemery
   ```
   You should see an entry that runs the retention script every 5 minutes.

3. **Test Reset Readiness**:
   ```bash
   # Test if your system is properly configured for resets
   ./scripts/maintenance/test_reset_process.sh
   ```

## Genesis Repository Integration

The ansible-ephemery system integrates with the Ephemery Genesis repository in these key ways:

1. **Automated Genesis Fetching**: Automatically retrieves the latest genesis configuration files
2. **Reset Detection**: Monitors for new iterations and handles resets
3. **Configuration Consistency**: Ensures your node uses the official Ephemery parameters
4. **Key Management**: Provides tools for proper key submission and verification

For more details on this integration, see [Ephemery Genesis Integration](../FEATURES/EPHEMERY_GENESIS_INTEGRATION.md).
