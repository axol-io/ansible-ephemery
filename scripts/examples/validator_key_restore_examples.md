# Validator Key Restore Examples

This document provides practical examples of using the Enhanced Validator Key Restore script for different scenarios.

## Basic Examples

### Simple Key Restore

To restore validator keys from a backup to your validator directory:

```bash
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /path/to/validator/backup/keys \
  --target-dir /var/lib/lighthouse/validators
```

This command will:
1. Validate the backup keys for JSON syntax and validator key format
2. Create a backup of any existing keys in the target directory
3. Restore the keys from the backup directory
4. Verify the restore was successful

### Dry Run

To check if a restore would work without actually changing anything:

```bash
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /path/to/validator/backup/keys \
  --target-dir /var/lib/lighthouse/validators \
  --dry-run
```

This is useful for validating your backup before attempting a restore.

### Verbose Output

For detailed logging of each step in the process:

```bash
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /path/to/validator/backup/keys \
  --target-dir /var/lib/lighthouse/validators \
  --verbose
```

## Advanced Examples

### Force Restore

To force a restore even if validation fails (use with caution):

```bash
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /path/to/validator/backup/keys \
  --target-dir /var/lib/lighthouse/validators \
  --force
```

This might be necessary in emergency scenarios where you need to restore keys immediately.

### Skip Backup

To skip creating a backup of existing keys:

```bash
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /path/to/validator/backup/keys \
  --target-dir /var/lib/lighthouse/validators \
  --no-backup
```

This is useful when:
- You've already created a backup
- The target directory is empty
- You're running low on disk space

### Validate Expected Key Count

To ensure the backup contains exactly 100 validator keys:

```bash
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /path/to/validator/backup/keys \
  --target-dir /var/lib/lighthouse/validators \
  --count 100
```

The script will fail if the backup doesn't contain exactly 100 valid validator keys.

### Combined Options

For detailed output with multiple options:

```bash
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /path/to/validator/backup/keys \
  --target-dir /var/lib/lighthouse/validators \
  --verbose \
  --count 100 \
  --dry-run
```

This will perform a detailed validation of the keys, ensure there are exactly 100 of them, but won't actually perform the restore.

## Production Examples

### Restore from Time-Stamped Backup

If you have time-stamped backups, you can point directly to a specific backup:

```bash
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /var/backups/validators/validator_keys_backup_20231115120000 \
  --target-dir /var/lib/lighthouse/validators
```

### Restore Latest Backup

If you use a "latest" symlink in your backup system:

```bash
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /var/backups/validators/latest \
  --target-dir /var/lib/lighthouse/validators
```

### Restore from One Node to Another

To migrate keys from one node to another:

```bash
# First, create a backup from the source node
ssh source-node "tar -czf /tmp/validator_keys_backup.tar.gz -C /var/lib/lighthouse validators"

# Transfer the backup to the target node
scp source-node:/tmp/validator_keys_backup.tar.gz /tmp/

# Extract the backup on the target node
mkdir -p /tmp/validator_keys_backup
tar -xzf /tmp/validator_keys_backup.tar.gz -C /tmp/validator_keys_backup

# Restore to the target directory
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /tmp/validator_keys_backup/validators \
  --target-dir /var/lib/lighthouse/validators
```

## Integration with Ephemery

### Restore After Network Reset

To restore keys after an Ephemery network reset:

```bash
# First, stop the validator container
docker stop ephemery-validator-lighthouse

# Then restore the keys
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /home/ephemery/backups/validators/latest \
  --target-dir /home/ephemery/validators/keys

# Finally, restart the validator
docker start ephemery-validator-lighthouse
```

### Scheduled Restore in Cron

To setup a scheduled restore after network resets, you can create a cron script:

```bash
#!/bin/bash

# Check if network reset has occurred by looking at genesis time file
if [[ -f /home/ephemery/last_genesis_update ]]; then
  LAST_UPDATE=$(cat /home/ephemery/last_genesis_update)
  CURRENT_TIME=$(date +%s)

  # If update was less than 1 hour ago, restore keys
  if (( CURRENT_TIME - LAST_UPDATE < 3600 )); then
    echo "Recent network reset detected. Restoring validator keys..."

    # Stop validator container
    docker stop ephemery-validator-lighthouse

    # Restore keys
    /home/ephemery/scripts/utilities/enhanced_key_restore.sh \
      --backup-dir /home/ephemery/backups/validators/latest \
      --target-dir /home/ephemery/validators/keys

    # Start validator container
    docker start ephemery-validator-lighthouse

    echo "Key restore completed at $(date)"
  fi
fi
```

## Troubleshooting Examples

### Diagnose JSON Validation Issues

If you're having problems with JSON validation:

```bash
# First check the format of one of your JSON files
jq . /path/to/backup/keys/keystore-0.json

# Then run the script with verbose output
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /path/to/backup/keys \
  --target-dir /var/lib/lighthouse/validators \
  --verbose \
  --dry-run
```

### Force Restore with Skip Verify

In extreme cases where you need to bypass all validation:

```bash
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /path/to/backup/keys \
  --target-dir /var/lib/lighthouse/validators \
  --force \
  --skip-verify
```

**Warning**: This should only be used in emergency situations when you're certain the backup is valid but the validation is failing for some other reason.

## Conclusion

The Enhanced Validator Key Restore script provides a flexible and robust way to manage validator key restores in different scenarios. By using the appropriate options for your situation, you can ensure a secure and reliable key restore process.
