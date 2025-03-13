# Ephemery Genesis Integration

This document consolidates information from the Ephemery Genesis repository and explains how it's integrated into the ansible-ephemery deployment system.

## Overview

The [Ephemery Genesis repository](https://github.com/ephemery-testnet/ephemery-genesis) is the official source for the Ephemery testnet genesis configuration. It contains essential configuration files, validator information, and reset mechanisms that our ansible-ephemery deployment system leverages to create and maintain Ephemery nodes.

## Key Components from Ephemery Genesis

### Genesis Configuration Files

The Ephemery Genesis repository contains several core configuration files that are essential for node operation:

1. **cl-config.yaml**: Consensus layer configuration 
2. **el-config.yaml**: Execution layer configuration
3. **el-bootnodes.txt**: List of execution layer bootnodes
4. **values.env**: Environment variables for the testnet

Our ansible-ephemery system automatically fetches and applies these configuration files during deployment and reset operations.

### Reset Mechanism

The Ephemery Genesis repository uses a reset mechanism implemented in `retention.sh` that:

1. Detects when a new genesis has been published
2. Downloads the latest genesis configuration
3. Resets the node's databases
4. Restarts the clients with the new configuration

This reset script is customized and improved in our ansible-ephemery implementation, which provides:

- Automated detection of genesis resets
- Robust error handling
- Comprehensive logging
- Health monitoring during reset operations

### Validator Registry

The Ephemery Genesis repository maintains a registry of genesis validators. To add validators to the genesis state, validator public keys are added to text files in the `validators` folder of the repository.

Our ansible-ephemery deployment system provides streamlined tools for:

1. Generating validator keys compatible with Ephemery
2. Preparing validator registration files
3. Backing up validator keys securely
4. Configuring validators to participate from genesis

## Integration with ansible-ephemery

### Automatic Configuration

The ansible-ephemery system:

1. **Fetches Configuration**: Automatically retrieves the latest configuration from Ephemery Genesis
2. **Applies Settings**: Configures clients with the appropriate genesis parameters
3. **Monitors Changes**: Tracks the Ephemery Genesis repository for updates

### Reset Automation

Our implementation extends the basic reset functionality with:

1. **Cron Integration**: Automated 5-minute polling using a properly configured cron job
2. **Monitoring**: Tracks reset events and client restarts
3. **Recovery**: Automatic recovery in case of issues during reset
4. **Notification**: Optional alerts when resets occur

### Genesis Validator Support

For genesis validators, our system provides:

1. **Key Generation**: Tooling to generate validator keys using the correct format
2. **Submission Preparation**: Helpers to format validator data for submission
3. **Key Management**: Secure key backup and restoration capabilities
4. **Performance Monitoring**: Tracking of validator effectiveness

## Configuration Instructions

### Configuring the Reset Script

The reset functionality is configured through the following options in your inventory:

```yaml
ephemery_reset_enabled: true
ephemery_reset_poll_interval: 300  # 5 minutes in seconds
ephemery_genesis_repo: "https://github.com/ephemery-testnet/ephemery-genesis"
ephemery_reset_notification_enabled: true
ephemery_reset_notification_email: "alerts@example.com"  # Optional
```

### Genesis Validator Configuration

To set up a genesis validator:

```yaml
# Enable validator functionality
validator_enabled: true

# Specify genesis validator operation
genesis_validator: true

# Key management options
validator_keys_dir: "/path/to/validator/keys"
validator_keystore_password: "your-secure-password"
```

See the [Genesis Validator Guide](../OPERATIONS/GENESIS_VALIDATOR.md) for complete instructions.

## Monitoring the Reset Process

The reset process can be monitored through:

1. Logs at `/var/log/ephemery-reset.log`
2. Status checks via `systemctl status ephemery-reset.service`
3. Metrics exported to Prometheus at the `/metrics` endpoint

## Related Documentation

- [Genesis Validator Guide](../OPERATIONS/GENESIS_VALIDATOR.md)
- [Resetter Configuration Guide](../OPERATIONS/RESETTER_CONFIGURATION.md)
- [Validator Key Management](./VALIDATOR_KEY_MANAGEMENT.md)
- [Ephemery-Specific Configuration](./EPHEMERY_SPECIFIC.md) 