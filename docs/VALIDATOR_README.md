# Ephemery Network Validator Guide

This guide explains how to set up and configure validators for the Ephemery testnet using this Ansible playbook.

## Overview

Validators are a crucial component of the Ethereum consensus mechanism. In the Ephemery testnet, validators function similarly to mainnet validators but operate in a more experimental, temporary environment.

The playbook provides three main approaches for setting up validators:

1. Automatic key generation (default)
2. Using compressed validator keys (recommended for many validators)
3. Using individual pre-generated validator key files

All methods include built-in protections against slashing by ensuring validators are properly stopped before key deployments.

## Quick Start

To enable a validator on your node:

1. Set `validator_enabled: true` in your host vars file
2. Place your validator keys in the appropriate location
3. Configure your password file
4. Run the playbook with the validator tag

```bash
ansible-playbook -i inventory.yaml ephemery.yaml -v -t validator -e "validator_enabled=true"
```

## Validator Configuration Options

### Basic Configuration

To enable a validator on your node, set the `validator_enabled` flag to `true` in your host vars file:

```yaml
# In host_vars/your-node.yaml
validator_enabled: true
```

### Validator Client Selection

You can choose which validator client to use by configuring the client image:

```yaml
# Client images
client_images:
  validator: "pk910/ephemery-lighthouse:latest"  # Specialized image for Ephemery network
  # Alternative options (for future reference):
  # validator: "sigp/lighthouse:v5.3.0"  # Standard Lighthouse validator
```

> **Note**: Currently, only the Lighthouse validator client is fully supported, which aligns with our supported consensus client (Lighthouse).

### Password File

The password file (e.g., `files/validator_keys/axol-node1.txt`) contains the validator keystore password. This file is copied to the validator container and used to decrypt the validator keys.

Example password file structure:

```plaintext
!@6YMXVadbU
```

The password file should be a plain text file containing only the password on a single line.

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

3. **Create a password file**:
   - Create a file like `files/validator_keys/validators.txt` with your keystore password

4. **Configure your host vars file**:

   ```yaml
   # In host_vars/your-node.yaml
   validator_enabled: true
   validator_keys_password_file: 'files/validator_keys/validators.txt'  # Text file with password
   validator_fee_recipient: 0x0000000000000000000000000000000000000000  # Optional
   validator_graffiti: my-validator-name  # Optional
   ```

### Using Individual Validator Key Files

For more granular control, you can use individual key files:

```yaml
# In host_vars/your-node.yaml
validator_enabled: true

# Validator key paths and configuration
validator_keys_src: 'files/validator_keys'  # Directory containing keystore-*.json files
validator_keys_password_file: 'files/validator_keys/validators.txt'  # Password file
validator_fee_recipient: 0x0000000000000000000000000000000000000000  # Fee recipient address
validator_graffiti: my-validator-name  # Custom graffiti text
```

## File Structure

When using validator keys, the following directory structure will be created on the node:

```bash
{{ ephemery_base_dir }}/ (typically /root/ephemery/)
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
- **Beacon Node**: Automatically connected to the local consensus client via `--beacon-nodes` parameter
- **Fee Recipient**: From `validator_fee_recipient` or default zero address
- **Graffiti**: From `validator_graffiti` or hostname if not specified
- **Keys**: Mounted from the copied keystores at `/secrets/keys`
- **Passwords**: Mounted from the copied password file at `/secrets/passwords`

Note: For Lighthouse validators, the parameter is `--beacon-nodes` (plural), not `--beacon-node`.

## Client-Specific Considerations

The playbook currently supports only the Lighthouse validator client, which:

- Uses the standard validator command line options
- Connects seamlessly to the Lighthouse consensus client
- Handles Ephemery network specifics with pre-configured images

Other validator clients (Prysm, Teku, etc.) may be supported in the future as additional client combinations are implemented.

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

## Troubleshooting

If your validator fails to start, check:

1. Keystore files are in the correct format
2. Password file (`validators.txt`) contains the correct password
3. Consensus client is running and accessible
4. Logs from the validator container: `docker logs ephemery-validator` or `docker logs {{ network }}-validator-{{ cl }}`
5. For Prysm validators, ensure the `--accept-terms-of-use` flag is properly passed

## Security Considerations

- Your validator keys are sensitive information - handle them securely
- For production-like environments, consider using an external secure storage solution
- Ensure proper permissions on keystore files and password files
- The playbook automatically sets 0600 permissions on key files
