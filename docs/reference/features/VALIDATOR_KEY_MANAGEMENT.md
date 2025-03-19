# Validator Key Management Best Practices

This document provides detailed guidance on managing validator keys for Ephemery nodes, covering security considerations, key preparation, and troubleshooting.

## Table of Contents

- [Key Preparation](#key-preparation)
- [Directory Structure](#directory-structure)
- [Mounting and Syncing](#mounting-and-syncing)
- [Troubleshooting](#troubleshooting)
- [Safety Measures](#safety-measures)

## Key Preparation

### Creating Validator Keys

To generate validator keys for Ephemery testing:

1. Use the Ethereum deposit CLI tool:

   ```bash
   # Example: Generate keys for Ephemery (testnet)
   ./deposit new-mnemonic \
     --num_validators=1 \
     --chain=ephemery \
     --eth1_withdrawal_address=0x0000000000000000000000000000000000000000
   ```

2. After generation, you'll have:
   - A directory containing keystore files (`keystore-m_*.json`)
   - Password files for each keystore

### Preparing Keys for Ansible Deployment

1. **Create the directory structure**:

   ```bash
   mkdir -p files/validator_keys
   mkdir -p files/passwords
   ```

2. **Create a single password file**:

   ```bash
   # Example: Create password file with "ephemery" password
   echo "ephemery" > files/passwords/validators.txt
   ```

3. **Compress validator keys into a ZIP archive**:

   ```bash
   # Assume keys are in ./validator_keys directory
   cd ./validator_keys
   zip -r ../files/validator_keys/validator_keys.zip keystore-*.json
   ```

### Key Security

For Ephemery testing, basic security is usually sufficient. For production environments:

1. **Use secure password generation**:

   ```bash
   # Generate a strong random password
   openssl rand -base64 32 > files/passwords/validators.txt
   ```

2. **Set restrictive permissions**:

   ```bash
   chmod 600 files/passwords/validators.txt
   chmod 600 files/validator_keys/validator_keys.zip
   ```

## Directory Structure

Understanding the validator key directory structure is important:

```
ansible-ephemery/
├── files/
│   ├── passwords/
│   │   └── validators.txt            # Single password file for all validators
│   ├── validator_keys/
│   │   └── validator_keys.zip        # ZIP archive of validator keystores
│   └── validator_definitions.yaml    # Optional: for complex validator setups
```

On the deployed node:

```
/root/ephemery/
├── data/
│   └── validator/                    # Validator client data directory
├── secrets/
│   └── validator/
│       ├── keys/                     # Extracted validator keystores
│       │   └── keystore-*.json
│       └── passwords/
│           └── validators.txt        # Copied password file
└── tmp/                              # Temporary directory for key extraction
```

## Mounting and Syncing

The playbook handles key mounting and syncing through these steps:

1. **Key Detection**: Checks if `files/validator_keys/validator_keys.zip` exists
2. **Key Transfer**: Copies keys and password files to the target node
3. **Safe Extraction**: Extracts keys to a temporary directory before moving to final location
4. **Permission Setting**: Sets proper permissions (0600) on key files
5. **Container Mounting**: Mounts keys as read-only and data directory as read-write

### Container Mounts

```yaml
volumes:
  - '{{ ephemery_base_dir }}/data/validator:/data:rw'           # Persistent data
  - '{{ ephemery_base_dir }}/secrets/validator/keys:/secrets/keys:ro'  # Keys (read-only)
  - '{{ ephemery_base_dir }}/secrets/validator/passwords:/secrets/passwords:ro'  # Passwords
  - '{{ jwt_secret_path }}:/execution-auth.jwt:ro'              # JWT authentication
  - '{{ ephemery_base_dir }}/config/ephemery_network:/ephemery_config:ro'  # Network config
```

## Troubleshooting

### Key Extraction Issues

If you're having issues with key extraction:

1. **Verify the ZIP file structure**:

   ```bash
   unzip -l files/validator_keys/validator_keys.zip
   ```

   The ZIP should contain `keystore-*.json` files directly, not nested in subdirectories.

2. **Check for key validation errors**:
   The playbook includes a step to remove keys that don't have a valid `pubkey` field.
   Ensure your keystores have a proper `pubkey` field:

   ```bash
   grep -l "pubkey" keystore-*.json | wc -l
   ```

3. **Monitor the extraction process**:

   ```bash
   ansible-playbook -i inventory.yaml ephemery.yaml -v -t validator
   ```

   Using verbose mode (`-v`) provides more details about the extraction process.

### Permission Issues

If you're having permission problems:

1. **Check file ownership**:

   ```bash
   ls -la /root/ephemery/secrets/validator/keys/
   ```

   Files should be owned by the user running the validator.

2. **Verify permissions**:

   ```bash
   stat -c '%a %n' /root/ephemery/secrets/validator/keys/*
   ```

   All files should have 600 permissions.

3. **Fix permission issues**:

   ```bash
   chmod 600 /root/ephemery/secrets/validator/keys/*
   chmod 600 /root/ephemery/secrets/validator/passwords/*
   ```

### Empty Key Directory

If your validator fails because the key directory is empty:

1. **Check if keys were extracted**:

   ```bash
   ls -la /root/ephemery/tmp/validator_keys/
   ```

2. **Manually move keys if needed**:

   ```bash
   mkdir -p /root/ephemery/secrets/validator/keys/
   cp /root/ephemery/tmp/validator_keys/keystore-*.json /root/ephemery/secrets/validator/keys/
   chmod 600 /root/ephemery/secrets/validator/keys/*
   ```

## Safety Measures

The playbook includes several safety features:

1. **Container Stopping**: Automatically stops existing validator containers before key operations
2. **Directory Validation**: Checks if required directories exist and creates them if needed
3. **Key Validation**: Verifies keys are properly formatted before using them
4. **Empty Directory Check**: Warns if the validator key directory is empty
5. **Password Management**: Creates default password file if none exists

These measures help prevent common issues and protect against accidental slashing.

## Related Documentation

- [Ephemery Setup Guide](./EPHEMERY_SETUP.md)
- [Monitoring Guide](./MONITORING.md)
- [Troubleshooting](../DEVELOPMENT/TROUBLESHOOTING.md)
