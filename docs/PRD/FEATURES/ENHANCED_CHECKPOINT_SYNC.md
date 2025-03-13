# Enhanced Checkpoint Sync

The Enhanced Checkpoint Sync feature provides an optimized solution for Ephemery nodes to synchronize with the network quickly and reliably. This feature implements multiple improvements over the standard checkpoint sync mechanism, addressing common issues and enhancing resilience.

## Overview

Checkpoint syncing is a critical feature that allows nodes to join the network without processing the entire chain history. The Enhanced Checkpoint Sync implementation includes:

1. **Multi-Provider Fallback**: Automatic detection and switching between multiple checkpoint sources if the primary source is unavailable
2. **Improved Monitoring**: Real-time sync status monitoring with progress tracking and alerts
3. **Performance Optimizations**: Special configuration parameters to accelerate sync speed
4. **Automated Recovery**: Self-healing capabilities when sync issues are detected

## Key Features

### Multi-Provider Fallback

The system maintains a list of reliable checkpoint sync providers and automatically tests them for availability:

- Tests all providers to find a working source
- Monitors the current source for availability
- Automatically switches to an alternative source if the current one fails
- Creates backups before making any changes

### Sync Progress Monitoring

Comprehensive monitoring of the sync progress provides insight into the sync status:

- Real-time tracking of sync distance and speed
- Estimated completion time calculation
- Historical progress tracking
- Stall detection with configurable thresholds
- Alert system for slow or stalled sync

### Performance Optimization

The implementation includes several performance enhancements:

- Increased cache size for execution client
- Optimized peer count configuration
- Genesis backfill optimization
- Backfill rate limiting disabled for faster sync
- Increased timeout multipliers for reliable connections

## Implementation Details

The Enhanced Checkpoint Sync has been implemented in multiple components:

### Scripts

1. **Main Script**: `scripts/maintenance/enhance_checkpoint_sync.sh` - Core implementation that sets up checkpoint sync with the enhanced features.
   
2. **Fallback Script**: `scripts/utilities/checkpoint_sync_fallback.sh` - Continuously monitors checkpoint URL availability and switches to alternatives if needed.
   
3. **Monitoring Script**: `scripts/monitoring/checkpoint_sync_monitor.sh` - Tracks sync progress, detects stalls, and provides alerts.

### Configuration Changes

The following changes are made to the `inventory.yaml` configuration:

```yaml
use_checkpoint_sync: true
checkpoint_sync_url: "https://checkpoint-sync.ephemery.ethpandaops.io"
cl_extra_opts: "--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"
el_extra_opts: "--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100"
```

### Systemd Services

Two systemd services are created for continuous operation:

1. **checkpoint-fallback.service** - Runs the fallback script as a background service
2. **checkpoint-monitor.service** - Runs the monitoring script as a background service

## Usage

### Setting Up Enhanced Checkpoint Sync

To set up the Enhanced Checkpoint Sync:

```bash
# Basic setup
./scripts/maintenance/enhance_checkpoint_sync.sh

# With monitoring enabled
./scripts/maintenance/enhance_checkpoint_sync.sh --monitor

# Reset database and use force mode (no confirmations)
./scripts/maintenance/enhance_checkpoint_sync.sh --reset --force
```

### Command-Line Options

The following options are available:

- `-h, --help`: Display help information
- `-v, --verbose`: Enable verbose output
- `-t, --timeout SECONDS`: Set timeout for checkpoint sync (default: 300)
- `-m, --monitor`: Set up continuous monitoring after setup
- `-r, --reset`: Reset the database before attempting sync
- `-f, --force`: Skip confirmations

## Monitoring and Troubleshooting

### Checking Sync Status

To check the current sync status:

```bash
# View lighthouse service logs
journalctl -fu lighthouse.service

# View specific metrics
curl http://localhost:5054/metrics | grep sync
```

### Monitoring Services

To check the status of the monitoring services:

```bash
# View fallback service logs
journalctl -fu checkpoint-fallback.service

# View monitoring service logs
journalctl -fu checkpoint-monitor.service

# Check service status
systemctl status checkpoint-fallback.service
systemctl status checkpoint-monitor.service
```

### Common Issues and Solutions

| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| Sync not starting | Checkpoint URL unreachable | The fallback service should automatically switch to an alternative URL |
| Very slow sync | Poor network conditions | Check network connection and increase `--execution-timeout-multiplier` |
| Stalled sync | Client or network issue | The monitoring service will detect this and alert; consider restarting the service |
| Service failures | System resource constraints | Check system resources and logs for specific error messages |

## Service Management

### Starting and Stopping Services

```bash
# Start services
systemctl start checkpoint-fallback.service
systemctl start checkpoint-monitor.service

# Stop services
systemctl stop checkpoint-fallback.service
systemctl stop checkpoint-monitor.service

# Restart services
systemctl restart checkpoint-fallback.service
systemctl restart checkpoint-monitor.service
```

### Enabling and Disabling Services

```bash
# Enable services to start at boot
systemctl enable checkpoint-fallback.service
systemctl enable checkpoint-monitor.service

# Disable services
systemctl disable checkpoint-fallback.service
systemctl disable checkpoint-monitor.service
```

## Related Features

- [Checkpoint Sync](./CHECKPOINT_SYNC.md) - Base checkpoint sync functionality
- [Checkpoint Sync Fix](./CHECKPOINT_SYNC_FIX.md) - Previous checkpoint sync improvements
- [Sync Monitoring](./SYNC_MONITORING.md) - General sync monitoring capabilities

## Future Enhancements

Planned enhancements for the future include:

1. Web dashboard integration for visual monitoring of sync progress
2. Additional checkpoint providers for greater redundancy
3. Machine learning-based prediction of sync issues
4. Mobile alerts for critical sync problems
5. Integration with external monitoring systems 