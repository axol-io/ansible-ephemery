# Validator Key Restore

This document describes the validator key restore functionality for Ephemery nodes, including the implementation details, usage, and best practices.

## Overview

The Validator Key Restore feature provides a robust mechanism for restoring validator keys from backup, ensuring the integrity and security of keys throughout the process. It includes validation, verification, and automatic backup features to prevent data loss.

## Features

The enhanced validator key restore system provides the following features:

- **Comprehensive Key Validation**
  - JSON syntax validation for all key files
  - Validator key structure verification
  - Expected key count validation
  - Detailed validation reporting

- **Secure Backup Mechanism**
  - Automatic backup of existing keys before restore
  - Timestamped backup directories
  - Latest backup symlink for easy access
  - Rotational backup management

- **Atomic Restore Process**
  - Staged restore using temporary directories
  - Verification before commitment
  - All-or-nothing restore to prevent partial state
  - Detailed error reporting

- **Flexible Configuration**
  - Configurable validation options
  - Force option for emergency restores
  - Dry run capability for testing
  - Verbose logging for debugging

## Implementation

The enhanced validator key restore system consists of the following scripts:

**`enhanced_key_restore.sh`** - The main script that handles the restore process:
- Validates the backup keys for integrity
- Creates backups of existing keys
- Performs atomic restore operations
- Verifies the restore was successful

**`ephemery_key_restore_wrapper.sh`** - A user-friendly wrapper for Ephemery environments:
- Provides simplified interface with sensible defaults for Ephemery setups
- Handles validator container stop/start automatically
- Includes backup discovery and selection features
- Improves usability with enhanced documentation and error reporting

## Usage

### Basic Usage with the Wrapper Script (Recommended)

For standard Ephemery environments, the wrapper script provides the easiest way to restore validator keys:

```bash
./scripts/utilities/ephemery_key_restore_wrapper.sh
```

This automatically:
1. Finds the latest backup
2. Stops the validator container
3. Performs the restore with proper validation
4. Restarts the validator container

### Listing Available Backups

To see what backups are available:

```bash
./scripts/utilities/ephemery_key_restore_wrapper.sh --list-backups
```

This shows all validator key backups along with the number of keys in each backup.

### Restoring a Specific Backup

To restore from a specific backup:

```bash
./scripts/utilities/ephemery_key_restore_wrapper.sh --specific validator_keys_backup_20231115120000
```

### Advanced Wrapper Options

The wrapper script provides additional options:

```bash
./scripts/utilities/ephemery_key_restore_wrapper.sh --dry-run --verbose
```

For complete wrapper script options, run:

```bash
./scripts/utilities/ephemery_key_restore_wrapper.sh --help
```

### Direct Usage of the Core Script

For more detailed control, you can use the core script directly:

```bash
./scripts/utilities/enhanced_key_restore.sh --backup-dir /path/to/backup --target-dir /path/to/validator/keys
```

This will validate the backup, create a backup of any existing keys, and restore the keys from the backup directory.

### Dry Run

To perform a dry run without making any changes:

```bash
./scripts/utilities/enhanced_key_restore.sh --backup-dir /path/to/backup --target-dir /path/to/validator/keys --dry-run
```

This will perform all validation steps but will not actually restore any keys.

### Force Restore

To force a restore even if validation fails:

```bash
./scripts/utilities/enhanced_key_restore.sh --backup-dir /path/to/backup --target-dir /path/to/validator/keys --force
```

This is useful in emergency situations where you need to restore keys despite validation failures.

### Skip Backup

To skip creating a backup of existing keys:

```bash
./scripts/utilities/enhanced_key_restore.sh --backup-dir /path/to/backup --target-dir /path/to/validator/keys --no-backup
```

This is useful when you already have a backup or when the existing keys are known to be invalid.

### Expected Key Count

To validate the number of keys in the backup:

```bash
./scripts/utilities/enhanced_key_restore.sh --backup-dir /path/to/backup --target-dir /path/to/validator/keys --count 100
```

This will ensure that the backup contains exactly 100 valid key files.

### Advanced Usage

For detailed debugging and complete control:

```bash
./scripts/utilities/enhanced_key_restore.sh \
  --backup-dir /path/to/backup \
  --target-dir /path/to/validator/keys \
  --force \
  --no-backup \
  --verbose
```

## Configuration Options

The enhanced validator key restore system supports the following options:

| Option | Description | Default |
|--------|-------------|---------|
| `-b`, `--backup-dir DIR` | Source backup directory containing validator keys | (required) |
| `-t`, `--target-dir DIR` | Target directory to restore keys to | (required) |
| `-f`, `--force` | Force restore even if validation fails | `false` |
| `-d`, `--dry-run` | Perform validation without actual restore | `false` |
| `-n`, `--no-backup` | Skip creating backup of existing keys | `false` |
| `-s`, `--skip-verify` | Skip verification steps | `false` |
| `-c`, `--count NUM` | Expected key count (0 to skip check) | `0` |
| `-v`, `--verbose` | Enable verbose output | `false` |
| `-h`, `--help` | Show help message | `false` |

## Wrapper Script Options

The Ephemery wrapper script provides these additional options:

| Option | Description | Default |
|--------|-------------|---------|
| `--specific BACKUP` | Use a specific backup (timestamp or folder name) | (latest) |
| `--list-backups` | List available backups in backup directory | |
| `--no-stop` | Don't stop the validator container before restore | `false` |
| `--no-start` | Don't start the validator container after restore | `false` |
| `--container NAME` | Specify validator container name | `ephemery-validator-lighthouse` |

## Validation Process

The validation process consists of several steps:

1. **Directory Validation**
   - Checks if the backup directory exists
   - Verifies the directory contains JSON files

2. **JSON Validation**
   - Validates that each file is a valid JSON document
   - Counts valid and invalid JSON files
   - Reports detailed validation results

3. **Validator Key Validation**
   - Checks if the JSON files contain `pubkey` fields indicating they are validator keys
   - Verifies the expected key count if specified
   - Reports validation results and any issues found

4. **Restore Verification**
   - After restore, compares the number of files in the source and target directories
   - Verifies that the restore was complete and accurate

## Backup Mechanism

The backup mechanism creates timestamped backups of existing keys before performing any restore:

1. **Backup Directory Structure**
   ```
   /path/to/validator/keys_backups/
   ├── validator_keys_backup_20231201123456/
   ├── validator_keys_backup_20231202123456/
   └── latest -> validator_keys_backup_20231202123456/
   ```

2. **Backup Process**
   - Creates a timestamped directory
   - Copies all files from the target directory
   - Creates/updates a symlink called `latest` pointing to the most recent backup

3. **Backup Usage**
   To restore from a backup of the backup:
   ```bash
   ./scripts/utilities/enhanced_key_restore.sh \
     --backup-dir /path/to/validator/keys_backups/latest \
     --target-dir /path/to/validator/keys
   ```

## Restore Process

The restore process is designed to be atomic, ensuring that the target directory is either completely updated or left unchanged:

1. **Staging**
   - Creates a temporary directory
   - Copies all files from the backup to the temporary directory
   - Verifies the copy was complete

2. **Atomic Commit**
   - Uses rsync with `--delete` to perform an atomic update
   - Either all files are updated or none are
   - Cleans up temporary directory regardless of success or failure

3. **Verification**
   - Counts files in the target directory after restore
   - Compares to the count in the source directory
   - Reports success or failure

## Integration with Ephemery

### Automated Restore After Genesis Reset

The validator key restore system is designed to work seamlessly with Ephemery's weekly reset cycle. You can automatically restore validator keys after a network reset by integrating with the reset detection system:

1. **Add to Reset Handler**

   Edit your reset handler script to include:

   ```bash
   # After detecting a reset
   /path/to/scripts/utilities/ephemery_key_restore_wrapper.sh
   ```

2. **Cron Job**

   Alternatively, create a cron job that checks for resets and restores keys:

   ```bash
   #!/bin/bash
   # Check if network reset has occurred
   if [[ -f /path/to/reset_detected_file ]]; then
     # Restore validator keys
     /path/to/scripts/utilities/ephemery_key_restore_wrapper.sh
     # Clear the detection file
     rm /path/to/reset_detected_file
   fi
   ```

### Docker Integration

The wrapper script automatically handles Docker container management:

1. Stops the validator container before restore
2. Restores the keys
3. Starts the validator container after successful restore

To customize container handling:

```bash
# Custom container name
./scripts/utilities/ephemery_key_restore_wrapper.sh --container my-custom-validator

# Skip container management
./scripts/utilities/ephemery_key_restore_wrapper.sh --no-stop --no-start
```

## Troubleshooting

### Common Issues

#### 1. Validation Failures

If validation fails with message `JSON validation failed`, check:
- The backup directory contains valid JSON files
- The files are properly formatted
- Use `--verbose` to see which files are invalid
- Use `--force` to override validation if necessary

#### 2. Missing Pubkeys

If validation fails with message `No validator keys found`, check:
- The backup contains actual validator keys with `pubkey` fields
- The files are not encrypted or protected
- Use `--skip-verify` to bypass this check if needed

#### 3. Backup Failures

If backup creation fails, check:
- Permissions on the target directory
- Available disk space
- Use `--no-backup` to skip backup creation if necessary

#### 4. Restore Failures

If restore fails, check:
- Permissions on the target directory
- Available disk space
- The detailed error message for specific issues

#### 5. Container Issues

If container management fails:
- Check that Docker is running
- Verify the container name is correct
- Check container logs for errors
- Use `--no-stop --no-start` to manage containers manually

### Diagnostic Steps

1. **Run with Verbose Output**:
   ```bash
   ./scripts/utilities/enhanced_key_restore.sh \
     --backup-dir /path/to/backup \
     --target-dir /path/to/validator/keys \
     --verbose
   ```

2. **Perform a Dry Run**:
   ```bash
   ./scripts/utilities/enhanced_key_restore.sh \
     --backup-dir /path/to/backup \
     --target-dir /path/to/validator/keys \
     --dry-run --verbose
   ```

3. **Check Key Format**:
   ```bash
   jq . /path/to/backup/keyfile.json
   ```

4. **List Available Backups**:
   ```bash
   ./scripts/utilities/ephemery_key_restore_wrapper.sh --list-backups
   ```

## Best Practices

1. **Regular Backups**
   - Create regular backups of validator keys
   - Store backups securely on separate media
   - Test restores periodically

2. **Secure Storage**
   - Encrypt backups when possible
   - Store backups in secure locations
   - Use strong access controls

3. **Verification**
   - Always verify backups after creation
   - Test restore process in a safe environment
   - Document backup locations and procedures

4. **Emergency Procedures**
   - Document emergency restore procedures
   - Have clear instructions for force restore options
   - Test emergency procedures periodically

## Examples

For practical examples of using the validator key restore functionality in different scenarios, see:
- [Validator Key Restore Examples](../../scripts/examples/validator_key_restore_examples.md)

## References

- [Validator Key Management](./VALIDATOR_KEY_MANAGEMENT.md)
- [Genesis Validator Guide](../OPERATIONS/GENESIS_VALIDATOR.md)
- [Ephemery Setup Guide](./EPHEMERY_SETUP.md)
