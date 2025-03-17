# Checkpoint Sync Fix

This document provides information about the enhanced checkpoint synchronization system for Ephemery nodes, including the implementation details, usage, and troubleshooting.

## Overview

The enhanced checkpoint synchronization system addresses several issues with the standard checkpoint sync implementation:

1. **URL Accessibility Issues**: Automatically tests and selects the best working checkpoint sync URL
2. **Network Connectivity Problems**: Implements optimized network settings for faster sync
3. **Stalled Sync Detection**: Monitors and recovers from stuck synchronization
4. **Inconsistent Configuration**: Ensures proper configuration across all components

## Features

The enhanced checkpoint sync system provides the following features:

- **Automatic URL Testing and Selection**
  - Tests multiple checkpoint sync URLs for accessibility
  - Measures response time for each working URL
  - Selects the fastest responding URL automatically
  - Updates inventory file with the best URL

- **Optimized Synchronization**
  - Configures Lighthouse with optimized parameters
  - Implements proper timeout and retry settings
  - Sets up optimal peer discovery configuration
  - Disables rate limiting during initial sync

- **Monitoring and Recovery**
  - Detects stalled sync conditions
  - Implements automatic recovery procedures
  - Provides detailed sync progress reporting
  - Creates health check alerts

## Implementation

The enhanced checkpoint sync system consists of two main components:

1. **`enhanced_checkpoint_sync.sh`** - A shell script that:
   - Tests multiple checkpoint sync URLs
   - Selects the best working URL
   - Updates the inventory file
   - Applies the fix via Ansible

2. **`fix_checkpoint_sync.yaml`** - An Ansible playbook that:
   - Applies the selected checkpoint sync URL
   - Configures Lighthouse with optimized parameters
   - Sets up monitoring and recovery mechanisms
   - Verifies the sync is progressing

## Usage

### Basic Usage

To run the enhanced checkpoint sync system with default settings:

```bash
./scripts/maintenance/enhanced_checkpoint_sync.sh
```

This will test available checkpoint sync URLs and report the best one without making changes.

### Apply Fix

To apply the checkpoint sync fix automatically:

```bash
./scripts/maintenance/enhanced_checkpoint_sync.sh --apply
```

This will test URLs, select the best one, update the inventory file, and apply the fix.

### Force Reset

To force reset the Lighthouse database (useful for severely stuck syncs):

```bash
./scripts/maintenance/enhanced_checkpoint_sync.sh --apply --reset
```

### Custom Inventory

To use a custom inventory file:

```bash
./scripts/maintenance/enhanced_checkpoint_sync.sh --inventory production-inventory.yaml --apply
```

### Monitor Sync Status

To check the current sync status:

```bash
./scripts/maintenance/enhanced_checkpoint_sync.sh --status
```

### Advanced Usage

For detailed debugging and customization:

```bash
./scripts/maintenance/enhanced_checkpoint_sync.sh --inventory custom-inventory.yaml --apply --reset --verbose
```

## Configuration Options

The enhanced checkpoint sync system supports the following options:

| Option | Description | Default |
|--------|-------------|---------|
| `-i`, `--inventory FILE` | Specify the inventory file | `./inventory.yaml` |
| `-a`, `--apply` | Apply the fix automatically | `false` |
| `-r`, `--reset` | Force reset of the Lighthouse database | `false` |
| `-t`, `--test` | Test URLs without making changes | `false` |
| `-s`, `--status` | Check current sync status | `false` |
| `-v`, `--verbose` | Enable verbose output | `false` |
| `-h`, `--help` | Show help message | `false` |

## Checkpoint URLs

The system automatically tests the following checkpoint sync URLs:

- https://checkpoint-sync.ephemery.ethpandaops.io
- https://beaconstate-ephemery.chainsafe.io
- https://checkpoint-sync.ephemery.dev
- https://checkpoint.ephemery.eth.limo
- https://checkpoint-sync.mainnet.ethpandaops.io
- https://sync-mainnet.beaconcha.in

## Troubleshooting

### Common Issues

#### 1. No Working Checkpoint URLs

If none of the predefined checkpoint URLs are accessible:

- Check your network connectivity
- Ensure the checkpoint URLs are accessible from your server
- Add custom checkpoint URLs to the script

#### 2. Sync Still Stalled After Fix

If synchronization remains stalled after applying the fix:

- Use the `--reset` option to force a complete reset of the Lighthouse database
- Check the Lighthouse logs for any specific error messages
- Ensure the execution client is fully synced

#### 3. Inventory File Updates Not Applied

If inventory file updates aren't reflected in the configuration:

- Check file permissions on the inventory file
- Manually verify the URL was updated in the inventory
- Run the Ansible playbook directly with `-v` for verbose output

#### 4. JWT Authentication Failures

Even with a working checkpoint sync URL, sync might fail due to JWT authentication issues between the execution and consensus clients:

- Consensus logs showing "Execution endpoint is not synced" despite checkpoint sync
- Execution logs showing "Beacon client online, but no consensus updates received"
- Chain ID mismatches between clients (Ephemery requires 39438144)

For detailed troubleshooting of JWT authentication issues, see [JWT Authentication Troubleshooting](./JWT_AUTHENTICATION_TROUBLESHOOTING.md).

### Diagnostic Steps

1. **Check Lighthouse Logs**:
   ```bash
   docker logs ephemery-lighthouse | tail -100
   ```

2. **Verify API Connectivity**:
   ```bash
   curl -s http://localhost:5052/eth/v1/node/syncing
   ```

3. **Test Checkpoint URL Directly**:
   ```bash
   curl -s -I https://checkpoint-sync.ephemery.ethpandaops.io/eth/v1/beacon/states/finalized
   ```

## Advanced Configuration

### Custom Checkpoint URLs

You can modify the list of checkpoint URLs in the script to include your own trusted sources:

```bash
CHECKPOINT_URLS=(
  "https://checkpoint-sync.ephemery.ethpandaops.io"
  "https://beaconstate-ephemery.chainsafe.io"
  "https://checkpoint-sync.ephemery.dev"
  "https://checkpoint.ephemery.eth.limo"
  "https://your-custom-checkpoint-url.example.com"
)
```

### Optimizing Lighthouse Parameters

The enhanced checkpoint sync system configures Lighthouse with the following optimized parameters:

- `--checkpoint-sync-url-timeout=300`: Extends timeout for checkpoint downloads
- `--target-peers=100`: Increases peer count for better network connectivity
- `--disable-deposit-contract-sync`: Speeds up sync by skipping deposit contract
- `--import-all-attestations`: Improves sync by importing all attestations
- `--disable-backfill-rate-limiting`: Removes rate limiting during initial sync
- `--execution-timeout-multiplier=10`: Increases timeout for execution client calls

These parameters can be customized in the `fix_checkpoint_sync.yaml` playbook.

## References

- [Lighthouse Documentation](https://lighthouse-book.sigmaprime.io/)
- [Ephemery Setup Guide](./EPHEMERY_SETUP.md)
- [Sync Monitoring Guide](./SYNC_MONITORING.md)
- [Checkpoint Sync](./CHECKPOINT_SYNC.md)
