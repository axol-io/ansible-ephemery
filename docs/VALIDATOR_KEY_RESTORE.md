# Validator Key Restore Guide

This guide explains how to use the validator key restore functionality in Ansible Ephemery to recover your validator keys from backups.

## Overview

The key restore system provides:

1. **Automatic backup creation** before key replacement
2. **Safe restore** from backups with validation
3. **Rollback mechanism** if restore fails
4. **Both Ansible playbook and CLI tools** for flexibility

## Prerequisites

Before attempting a restore operation, ensure:

1. You have previously run the Ansible Ephemery setup with validator keys
2. Backups have been created (which happens automatically during key extraction)
3. You have the necessary permissions to access the backup files

## Backup Locations

Validator key backups are automatically stored in:

```
~/ephemery/backups/validator/keys/
```

Each backup is in a timestamped directory (e.g., `20230415_120000`). The system also maintains a `latest_backup` file pointing to the most recent backup directory.

## Restore Methods

### Method 1: Using the Wrapper Script (Recommended)

The wrapper script provides a simple interface for key restoration:

```bash
./scripts/restore_validator_keys_wrapper.sh [options]
```

Options:
- `-i, --inventory FILE` - Specify the inventory file (default: local-inventory.yaml)
- `-b, --backup TIMESTAMP` - Specify backup to restore (default: latest)
- `-f, --force` - Force restore without confirmation
- `-h, --help` - Show help message

Examples:
```bash
# Restore from the latest backup using local inventory
./scripts/restore_validator_keys_wrapper.sh

# Restore from a specific backup using production inventory
./scripts/restore_validator_keys_wrapper.sh --backup 20230415_120000 --inventory production-inventory.yaml

# Force restore without confirmation
./scripts/restore_validator_keys_wrapper.sh --force
```

### Method 2: Using the Ansible Playbook Directly

For more advanced usage, you can run the Ansible playbook directly:

```bash
ansible-playbook -i your-inventory.yaml playbooks/restore_validator_keys.yml -e "backup_timestamp=20230415_120000 force_restore=yes"
```

Variables:
- `backup_timestamp` - Timestamp or full path of backup to restore (default: latest)
- `force_restore` - Whether to force restore without confirmation (default: no)
- `container_name` - Custom validator container name if different from default

### Method 3: Using the CLI Script Directly

For direct management on the server where Ephemery is running:

```bash
~/ephemery/scripts/restore_validator_keys.sh [options]
```

Options:
- `--list` - List available backups
- `--backup PATH` - Specify backup to restore (path or timestamp)
- `--restore-latest` - Restore from the latest backup
- `--force` - Force restore without confirmation
- `--container NAME` - Specify validator container name
- `--help` - Show help message

Examples:
```bash
# List available backups
~/ephemery/scripts/restore_validator_keys.sh --list

# Restore from the latest backup
~/ephemery/scripts/restore_validator_keys.sh --restore-latest

# Restore from a specific backup
~/ephemery/scripts/restore_validator_keys.sh --backup 20230415_120000
```

## Restore Process

The restore operation follows these steps:

1. **Stop validator container** to prevent slashing
2. **Create safety backup** of current keys
3. **Stage restore** in a temporary directory for validation
4. **Verify key count** to ensure integrity
5. **Replace existing keys** with restored keys
6. **Set correct permissions** on restored files
7. **Start validator container** after successful restore

If any step fails, the system will attempt to roll back to the previous state.

## Verification After Restore

After restoring keys, you should:

1. Verify the validator container is running properly:
   ```bash
   docker ps | grep validator
   ```

2. Check the validator logs for any errors:
   ```bash
   docker logs -f ephemery-validator-lighthouse
   ```

3. Monitor validator performance in the dashboard to confirm correct operation

4. Check that all keys are properly loaded:
   ```bash
   docker exec ephemery-validator-lighthouse lighthouse account_manager validator list
   ```

## Troubleshooting

Common issues and solutions:

### No Backups Found

If no backups are found, check:
- The backup directory exists: `~/ephemery/backups/validator/keys/`
- Keys were properly loaded previously
- You have appropriate permissions to access the backup directory

### Container Not Starting After Restore

If the validator container fails to start after restore:
1. Check container logs: `docker logs ephemery-validator-lighthouse`
2. Verify key permissions: `ls -la ~/ephemery/secrets/validator/keys/`
3. Ensure password file exists: `ls -la ~/ephemery/secrets/validator/passwords/`

### Keys Not Being Recognized

If restored keys are not recognized by the validator client:
1. Verify key format: `ls -la ~/ephemery/secrets/validator/keys/keystore-*.json`
2. Check password file content matches the keys
3. Try restarting the validator container: `docker restart ephemery-validator-lighthouse`

## Advanced: Backup Rotation

Backups are automatically rotated based on the `backup_retention_days` setting (default: 7 days).

To modify the backup retention policy, edit the `ansible/vars/ephemery_variables.yaml` file:

```yaml
features:
  backup:
    enabled: true
    frequency: 'daily'  # Options: hourly, daily, weekly
    retention_days: 7   # Number of days to keep backups
```

## Security Considerations

For enhanced security when handling validator keys:

1. **Limit access** to the backup directories
2. **Encrypt backups** if storing outside the secure server
3. **Monitor access** to the key directories
4. **Audit restore operations** through logs

Remember that validator keys control access to your staked ETH. Handle with appropriate security measures.

## Next Steps

After successful key restoration, consider implementing:

1. Regular backup verification
2. Off-site backup storage
3. Key performance monitoring
4. Automated post-restore validation tests

By following best practices for key management, you can ensure the security and reliability of your validators.
