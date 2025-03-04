# Validator Setup Guide

This guide explains how to set up and configure validators for the Ephemery testnet using this Ansible playbook.

## Overview

Validators are a crucial component of the Ethereum consensus mechanism. In the Ephemery testnet, validators function similarly to mainnet validators but operate in a more experimental, temporary environment.

The playbook provides two main approaches for setting up validators:

1. Automatic key generation (default)
2. Using pre-generated validator keys (custom)

## Validator Configuration Options

### Basic Configuration

To enable a validator on your node, set the `validator_enabled` flag to `true` in your host vars file:

```yaml
# In host_vars/your-node.yaml
validator_enabled: true
```

### Using Default Key Generation

If you don't specify custom keys, the playbook will automatically generate validator keys for you. This is suitable for testing and development purposes.

### Using Custom Validator Keys

To use your own pre-generated validator keys:

```yaml
# In host_vars/your-node.yaml
validator_enabled: true

# Validator key paths and configuration
validator_keys_src: '/path/to/your/validator/keys'  # Directory containing keystore-*.json files
validator_keys_password_file: '/path/to/your/password/file.txt'  # Text file with passwords
validator_fee_recipient: 0x0000000000000000000000000000000000000000  # Fee recipient address
validator_graffiti: my-validator-name  # Custom graffiti text
```

#### Key Requirements

When using custom keys, ensure:

1. Your keys directory contains valid EIP-2335 keystore files (typically named `keystore-m_*.json`)
2. Your password file contains the password to decrypt these keystores
3. All paths are accessible to Ansible

## File Structure

When using custom validator keys, the following directory structure will be created on the node:

```
/root/ephemery/
├── data/
│   └── validator/  # Validator client data
├── secrets/
│   └── validator/
│       ├── keys/          # Your keystore files will be copied here
│       └── passwords/     # Your password file will be copied here as validators.txt
```

## Validator Client Configuration

The validator client will be configured with the following settings:

- **Network**: Ephemery testnet
- **Data Directory**: `/data` (container path)
- **Beacon Node**: Automatically connected to the local consensus client
- **Fee Recipient**: From `validator_fee_recipient` or default zero address
- **Graffiti**: From `validator_graffiti` or hostname if not specified
- **Keys**: Mounted from the copied keystores
- **Passwords**: Mounted from the copied password file

## Client-Specific Considerations

Different consensus clients (Lighthouse, Teku, Prysm, Lodestar) have slightly different validator configurations. The playbook handles these differences automatically based on the `cl` variable in your host configuration.

## Dedicated Validator Playbook

For managing validators independently of other node components, you can use the dedicated validator playbook:

```bash
ansible-playbook -i inventory.yaml playbooks/validator.yaml
```

This allows you to update or reconfigure validators without affecting the execution or consensus clients.

## Troubleshooting

If your validator fails to start, check:

1. Keystore files are in the correct format
2. Password file contains the correct password
3. Consensus client is running and accessible
4. Logs from the validator container: `docker logs ephemery-validator-[client]`

## Security Considerations

- Your validator keys are sensitive information - handle them securely
- For production-like environments, consider using an external secure storage solution
- Ensure proper permissions on keystore files and password files
