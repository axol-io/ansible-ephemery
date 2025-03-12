# Synchronization Monitoring

This document details the synchronization monitoring capabilities implemented in the Ansible Ephemery project.

## Overview

Our synchronization monitoring system provides comprehensive visibility into the sync status of both execution and consensus clients, offering real-time metrics, historical tracking, and visual feedback.

## Features

### Comprehensive Sync Dashboard

- **Real-time Metrics Display**: Monitor the sync status of both execution and consensus clients in real time
- **Visual Progress Indicators**: See clear progress bars with status indicators (syncing/synced/error)
- **Node Information**: View combined information about execution and consensus clients
- **Resource Usage Statistics**: Monitor system resource utilization during synchronization

### Enhanced Status Reporting

- **Geth Sync Stage Logging**: Detailed logging of Geth sync stages, including current and highest blocks
- **Lighthouse Distance/Slot Metrics**: Track Lighthouse sync distance and head slot
- **Combined Sync Status**: Unified view of both execution and consensus client sync statuses
- **Auto-detection of Sync Completion**: Automatic detection when clients have completed synchronization

### Performance Metrics

- **Sync Percentage Calculation**: Automatic calculation of sync completion percentage
- **Historical Data Collection**: Storage and tracking of the last 100 sync points
- **Structured JSON Output**: Export of structured data for consumption by external monitoring tools
- **Trend Analysis**: Analysis of sync speed and remaining time

## Configuration

Sync monitoring is enabled by default. You can configure it with these inventory variables:

```yaml
# In your inventory file
sync_monitoring_enabled: true     # Enable sync monitoring (default: true)
sync_dashboard_enabled: true      # Enable web dashboard (default: false)
sync_monitor_interval: 300        # Monitoring check interval in seconds (default: 300)
sync_history_points: 100          # Number of historical data points to keep (default: 100)
```

## Accessing Sync Status

After deployment, you can access the sync status through:

### CLI Access

```bash
# View current status (JSON format)
cat /path/to/ephemery/data/monitoring/sync/current_status.json

# View historical data
cat /path/to/ephemery/data/monitoring/sync/history.json

# Check monitoring logs
cat /path/to/ephemery/data/monitoring/sync/monitor.log
```

### Web Dashboard

If the dashboard is enabled, access it at:

```
http://YOUR_SERVER_IP/ephemery-status/
```

The dashboard includes:
- Current sync progress for both clients
- Historical sync graphs
- Node information
- Resource usage statistics

## Implementation Details

### Data Collection

The monitoring system collects data from multiple sources:

1. **Execution Client**:
   - JSON-RPC endpoint for block information
   - Admin API for peer count and network status
   - Debug API for sync status and stages

2. **Consensus Client**:
   - Beacon API for sync status and slot information
   - Validator API for validator status (if applicable)
   - Metrics endpoint for detailed performance data

### Dashboard Implementation

The dashboard is implemented using:
- Simple HTML/CSS/JavaScript for the frontend
- Server-side data collection script
- Nginx for serving the dashboard

### Directory Structure

The monitoring system uses the following directory structure:

```
/path/to/ephemery/data/monitoring/
├── sync/
│   ├── current_status.json   # Current sync status
│   ├── history.json          # Historical sync data
│   ├── monitor.log           # Monitoring logs
│   └── dashboard/            # Web dashboard files
└── scripts/
    ├── monitor_sync.sh       # Main monitoring script
    ├── collect_metrics.sh    # Metrics collection script
    └── update_dashboard.sh   # Dashboard update script
```

## Future Enhancements

While the current implementation provides comprehensive monitoring, we plan to add:

- Alert system for sync failures
- Network health monitoring (peer counts, latency)
- Advanced visualization options
- Mobile-friendly dashboard design
- Integration with external monitoring systems

For a complete list of planned improvements, see the [Roadmap](ROADMAP.md).
