---
id: checkpoint_sync_dashboard
title: Checkpoint Sync Dashboard
sidebar_label: Checkpoint Sync Dashboard
description: A dashboard for monitoring and managing checkpoint synchronization for Ephemery nodes
keywords:
  - dashboard
  - checkpoint sync
  - monitoring
---

# Ephemery Checkpoint Sync Dashboard

This document provides information on using the Ephemery Checkpoint Sync Dashboard, a tool designed to monitor and manage the checkpoint synchronization process for Ephemery nodes.

## Overview

The Ephemery Checkpoint Sync Dashboard offers a comprehensive interface for monitoring the synchronization status of Ethereum clients in the Ephemery network. It provides real-time metrics, historical data visualization, and tools to troubleshoot and optimize the sync process.

## Features

- **Real-time Sync Status Monitoring:** View the current sync status of both Lighthouse (consensus client) and Geth (execution client).
- **Historical Sync Data:** Track sync progress over time with interactive charts.
- **Performance Metrics:** Monitor system resource usage during the sync process.
- **One-click Actions:** Restart clients, check for alternative checkpoint URLs, and run fix scripts directly from the dashboard.
- **Alerting:** Receive notifications for sync issues or stalled syncs.
- **Grafana Integration:** Advanced metric visualization through pre-configured Grafana dashboards.

## Dashboard Components

The dashboard consists of several components:

1. **Web Dashboard:** A Flask-based web application that provides the main user interface.
2. **Prometheus:** Collects and stores metrics from the clients.
3. **Grafana:** Provides advanced data visualization and dashboards.

## Installation and Setup

### Prerequisites

- Docker and Docker Compose
- Python 3.8 or higher
- Ephemery node with Lighthouse and Geth clients

### Setup Instructions

1. **Install the Dashboard:**

   ```bash
   cd /path/to/ephemery
   ./scripts/setup_dashboard.sh
   ```

2. **Access the Dashboard:**

   - Web Dashboard: <http://localhost:8080>
   - Grafana: <http://localhost:3000> (username: admin, password: ephemery)
   - Prometheus: <http://localhost:9090>

## Dashboard Usage

### Main Dashboard

The main dashboard displays:

- **Checkpoint Sync Status:** Current sync status for both Lighthouse and Geth clients.
- **Sync Progress Chart:** Visual representation of sync progress over time.
- **Recent Alerts:** Any recent sync issues or notifications.
- **Action Buttons:** Quick actions for common sync management tasks.

### Grafana Dashboards

The Grafana instance includes pre-configured dashboards:

- **Ephemery Sync Status:** Detailed sync metrics and progress.
- **System Resources:** CPU, memory, and network usage during sync.
- **Client Health:** Client-specific metrics and health indicators.

## Testing and Benchmarking

The dashboard includes tools for testing and benchmarking different sync methods:

### Running Sync Tests

Use the `test_checkpoint_sync.sh` script to run tests on different sync methods:

```bash
# Test checkpoint sync only
./scripts/test_checkpoint_sync.sh checkpoint

# Test optimized genesis sync only
./scripts/test_checkpoint_sync.sh genesis-optimized

# Test all sync methods and generate a comparison
./scripts/test_checkpoint_sync.sh all

# Compare existing test results
./scripts/test_checkpoint_sync.sh compare
```

### Test Results

Test results are stored in the `test_results` directory and include:

- Sync duration
- Final sync distance
- Head slot values
- System resource utilization
- Detailed logs

### Performance Comparison

The comparison report provides a side-by-side analysis of different sync methods, helping you determine the most efficient approach for your environment.

## Troubleshooting

### Common Issues

1. **Dashboard Not Loading:**
   - Check if Docker services are running: `docker-compose -f dashboard/docker-compose.yml ps`
   - Restart the services: `./scripts/setup_dashboard.sh restart`

2. **No Data in Charts:**
   - Ensure Prometheus can reach the clients: Check network settings
   - Verify client metrics endpoints are exposed

3. **Sync Not Progressing:**
   - Check client logs for errors: `docker logs ephemery-lighthouse`
   - Try an alternative checkpoint URL using the dashboard action button

### Support

For additional support:

- Check the [Ephemery Discord channel](https://discord.gg/ephemery)
- Open an issue on the [GitHub repository](https://github.com/eth-clients/ephemery)

## Advanced Configuration

### Custom Metrics

To add custom metrics to the dashboard:

1. Edit `/dashboard/app/app.py` to define additional metrics
2. Update Prometheus configuration in `/dashboard/prometheus.yml`
3. Create custom Grafana panels using the new metrics

### Remote Access

By default, the dashboard is only accessible from localhost. To enable remote access:

1. Edit `/dashboard/docker-compose.yml` and change the port mapping to `"8080:8080"`
2. Configure proper authentication and security measures
3. Update your firewall rules to allow access to the required ports

## Related Topics

- [Checkpoint Sync](./CHECKPOINT_SYNC.md)
- [Checkpoint Sync Fix](./CHECKPOINT_SYNC_FIX.md)
- [Checkpoint Sync Performance](./CHECKPOINT_SYNC_PERFORMANCE.md)
- [Monitoring](./MONITORING.md)
