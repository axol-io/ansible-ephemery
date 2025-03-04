# Validator Setup Guide

This guide explains how to set up and configure validators for the Ephemery testnet using this Ansible playbook.

## Overview

Validators are a crucial component of the Ethereum consensus mechanism. In the Ephemery testnet, validators function similarly to mainnet validators but operate in a more experimental, temporary environment.

The playbook provides three main approaches for setting up validators:

1. Automatic key generation (default)
2. Using compressed validator keys (recommended for many validators)
3. Using individual pre-generated validator key files

All methods include built-in protections against slashing by ensuring validators are properly stopped before key deployments.

## Validator Configuration Options

### Basic Configuration

To enable a validator on your node, set the `validator_enabled` flag to `true` in your host vars file:

```yaml
# In host_vars/your-node.yaml
validator_enabled: true
```

### Using Default Key Generation

If you don't specify custom keys, the playbook will automatically generate validator keys for you. This is suitable for testing and development purposes.

### Using Compressed Validator Keys (Recommended)

For efficient deployment of many validators, you can use compressed archives:

1. **Create a zip or tar.gz archive** of your validator keys
   - You can compress all your `keystore-m_*.json` files into a single archive
   - Either format is supported: `.zip` or `.tar.gz`

2. **Place the archive in the ansible project**:
   - `files/validator_keys/validator_keys.zip` (preferred format)
   - `files/validator_keys/validator_keys.tar.gz` (alternative format)

3. **Configure your host vars file**:

   ```yaml
   # In host_vars/your-node.yaml
   validator_enabled: true
   validator_keys_password_file: '/path/to/your/password/file.txt'  # Text file with passwords
   validator_fee_recipient: 0x0000000000000000000000000000000000000000  # Optional
   validator_graffiti: my-validator-name  # Optional
   ```

The playbook will:

1. Stop any running validator **to prevent slashing**
2. Transfer the single compressed file (much faster than many individual files)
3. Extract the keys securely on the target node
4. Apply proper permissions
5. Restart the validator with the new keys

### Using Individual Validator Key Files

For more granular control, you can use individual key files:

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

## Anti-Slashing Protection

The playbook includes several safeguards to prevent slashing:

1. **Safe Deployment Process**:
   - Running validators are automatically stopped before any key manipulation
   - Keys are completely replaced rather than incrementally updated
   - Proper permissions are maintained throughout the process

2. **Safe Extraction for Compressed Keys**:
   - Keys are first extracted to a temporary location
   - Only after successful extraction are they moved to the final location
   - The original key directory is completely replaced to prevent duplicates

## File Structure

When using validator keys, the following directory structure will be created on the node:

```bash
/opt/ephemery/
├── data/
│   └── validator/  # Validator client data
├── secrets/
│   └── validator/
│       ├── keys/          # Your keystore files will be copied/extracted here
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
- The playbook automatically sets 0600 permissions on key files
