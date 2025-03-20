# Data Management

This document describes the data management features implemented for Ephemery nodes, including disk space optimization, data pruning, and validator key backup/restore functionality.

## Table of Contents

- [Overview](#overview)
- [Data Pruning](#data-pruning)
  - [Pruning Levels](#pruning-levels)
  - [Implementation](#implementation)
  - [Usage](#usage)
- [Validator Backup and Restore](#validator-backup-and-restore)
  - [Backup Features](#backup-features)
  - [Restore Features](#restore-features)
  - [Security Considerations](#security-considerations)
  - [Implementation](#implementation-1)
  - [Usage](#usage-1)
- [Related Documentation](#related-documentation)

## Overview

As Ephemery nodes operate over time, they accumulate blockchain data that can consume substantial disk space. Additionally, validator keys and slashing protection data represent critical assets that need to be backed up securely. The data management features address these concerns by providing tools for:

1. Optimizing disk space usage through selective pruning
2. Backing up and restoring validator keys and associated data
3. Managing the lifecycle of Ephemery node data

## Data Pruning

The data pruning functionality enables operators to reclaim disk space by removing non-essential data based on configurable pruning levels.

### Pruning Levels

Three pruning levels are available:

1. **Safe Pruning**: Removes only non-essential data that doesn't affect node operation:
   - Ancient receipts and transaction data that is no longer needed
   - Cached state trie data that can be reconstructed
   - Old state snapshots from the freezer database

2. **Aggressive Pruning**: Removes more data, which may temporarily affect performance:
   - All freezer database contents
   - Ancient headers, bodies, and receipts
   - State trie cache data
   - Hot database contents

3. **Full Pruning**: Completely resets the node, requiring a full resync:
   - All execution client data
   - All consensus client data
   - This option is primarily for recovering from severely corrupted databases

### Implementation

The pruning functionality is implemented in the `prune_ephemery_data.sh` script with the following features:

- Layer-specific pruning (execution-only or consensus-only)
- Dry-run mode to show what would be pruned without making changes
- Automatic container management (stopping/starting as needed)
- Space utilization reporting before and after pruning
- Safety measures to prevent accidental data loss

### Usage

```bash
./prune_ephemery_data.sh [options]

Options:
  -s, --safe              Safe pruning (removes only non-essential data, default)
  -a, --aggressive        Aggressive pruning (removes more data, may affect performance)
  -f, --full              Full pruning (completely resets nodes, requires resync)
  -e, --execution-only    Prune only execution layer data
  -c, --consensus-only    Prune only consensus layer data
  -d, --dry-run           Show what would be pruned without making changes (default)
  -y, --yes               Skip confirmation prompts
  --base-dir PATH         Specify a custom base directory
```

## Validator Backup and Restore

The validator backup and restore functionality provides a secure way to back up validator keys and slashing protection data, and restore them when needed.

### Backup Features

- Comprehensive backup of validator keystores
- Backup of validator password files
- Optional inclusion of slashing protection data
- Optional encryption of backup archives
- Timestamped backups for versioning

### Restore Features

- Restore of validator keystores to the correct location
- Restore of password files
- Optional restoration of slashing protection data
- Automatic handling of encrypted backups
- Container management for seamless restoration

### Security Considerations

The backup and restore functionality includes several security features:

- Optional encryption of backup archives using AES-256-CBC
- Restrictive file permissions (600) for sensitive files
- Automatic backup of existing validator data before restoration
- Container stopping during key operations to prevent conflicts

### Implementation

The backup and restore functionality is implemented in the `backup_restore_validators.sh` script with the following features:

- Two operation modes: backup and restore
- Container-aware operations that work whether the validator is running or not
- Comprehensive error handling
- Progress reporting
- Automatic detection of backup types

### Usage

```bash
# Create a backup
./backup_restore_validators.sh backup [options]

# Restore from a backup
./backup_restore_validators.sh restore --file BACKUP_FILE [options]

Options:
  -d, --dir DIR          Directory to store backups or read from
  -f, --file FILE        Specific backup file to restore from (for restore mode)
  -e, --encrypt          Encrypt the backup (backup mode)
  --no-slashing          Exclude slashing protection data (backup mode)
  --base-dir PATH        Specify a custom base directory
```

## Related Documentation

- [Validator Key Management](./VALIDATOR_KEY_MANAGEMENT.md)
- [Ephemery Setup Guide](./EPHEMERY_SETUP.md)
- [Troubleshooting](../DEVELOPMENT/TROUBLESHOOTING.md)
