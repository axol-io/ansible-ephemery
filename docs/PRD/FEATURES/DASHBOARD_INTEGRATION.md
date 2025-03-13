# Dashboard Integration

This document explains the dashboard integration options available for Ephemery nodes, including both terminal-based dashboards and Grafana dashboards.

## Overview

Ephemery provides two types of dashboards for monitoring and managing your nodes:

1. **Terminal-based Dashboards**: Text-based dashboards that run in the terminal
2. **Web-based Dashboards**: Graphical dashboards that run in a web browser, powered by Grafana

Both dashboard types provide valuable information about your Ephemery nodes, but they serve different purposes and have different features.

## Terminal-based Dashboards

Terminal-based dashboards are lightweight, easy to use, and don't require additional services like Grafana or Prometheus. They're ideal for quick checks and basic monitoring.

### Available Terminal Dashboards

1. **Validator Dashboard**
   - Shows validator status, performance, and health
   - Provides real-time updates on validator activities
   - Displays balance trends and attestation effectiveness

2. **Sync Status Dashboard**
   - Shows sync status for both execution and consensus clients
   - Displays sync progress and estimated time to completion
   - Provides information about checkpoint sync

### Using Terminal Dashboards

To use the validator terminal dashboard:

```bash
# Using the wrapper script
./scripts/manage-validator.sh monitor dashboard

# Or directly
./scripts/validator/monitor_validator.sh dashboard
```

To use the sync status terminal dashboard:

```bash
./scripts/monitoring/check_sync_status.sh --dashboard
```

## Web-based Dashboards (Grafana)

Web-based dashboards provide more detailed and visually appealing information. They require Prometheus for data collection and Grafana for visualization.

### Available Grafana Dashboards

1. **Validator Performance Dashboard**
   - Detailed validator performance metrics
   - Historical data and trends
   - Customizable alerts and notifications

2. **Node Status Dashboard**
   - Comprehensive node status information
   - Resource usage metrics (CPU, memory, disk, network)
   - Client-specific metrics for both execution and consensus clients

3. **Ephemery Network Dashboard**
   - Network-wide metrics and statistics
   - Participation rate and validator count
   - Block production and attestation statistics

### Setting Up Grafana Dashboards

The Grafana dashboards are automatically set up when you deploy an Ephemery node with monitoring enabled:

```bash
# Deploy with monitoring enabled
./scripts/deploy-ephemery.sh --monitoring

# Or enable monitoring in your inventory file
# monitoring_enabled: true
```

You can also deploy the dashboards separately:

```bash
ansible-playbook -i inventory.yaml playbooks/deploy_monitoring.yaml
```

### Accessing Grafana Dashboards

Once deployed, you can access the Grafana dashboards at:

```
http://YOUR_SERVER_IP:3000
```

Default credentials:
- Username: admin
- Password: admin (you'll be prompted to change this on first login)

## Integration Between Dashboard Types

The terminal-based and web-based dashboards complement each other:

- **Terminal dashboards** provide quick, lightweight access to essential information
- **Grafana dashboards** provide detailed, historical data with advanced visualization

Both dashboard types use the same underlying data sources, ensuring consistency in the information displayed.

## Prometheus Integration

Both dashboard types rely on metrics collected by various components:

1. **Direct API Queries**: Terminal dashboards directly query the client APIs
2. **Prometheus Metrics**: Grafana dashboards use Prometheus for data collection

### Prometheus Configuration

Prometheus is configured to scrape metrics from various sources:

- Execution client (Geth) metrics
- Consensus client (Lighthouse) metrics
- Validator client metrics
- Node exporter metrics (system resources)

The Prometheus configuration file is located at:

```
/opt/ephemery/config/prometheus.yaml
```

You can customize this file to add additional metrics sources or change the scrape interval.

## Dashboard Customization

### Terminal Dashboard Customization

Terminal dashboards can be customized by editing the script files:

- `scripts/validator/monitor_validator.sh` for validator dashboard
- `scripts/monitoring/check_sync_status.sh` for sync status dashboard

### Grafana Dashboard Customization

Grafana dashboards can be customized through the Grafana web interface:

1. Log in to Grafana
2. Navigate to the dashboard you want to customize
3. Click the gear icon in the top right to enter edit mode
4. Make your changes and save the dashboard

You can also import custom dashboards from the `dashboard/grafana/` directory.

## Troubleshooting

### Terminal Dashboard Issues

If terminal dashboards aren't working:

1. Check that the required APIs are accessible
2. Verify that the client containers are running
3. Check for error messages in the dashboard output

### Grafana Dashboard Issues

If Grafana dashboards aren't working:

1. Check that Prometheus and Grafana services are running
2. Verify that Prometheus is collecting data from all sources
3. Check Grafana logs for error messages

```bash
# Check Prometheus status
systemctl status prometheus

# Check Grafana status
systemctl status grafana-server

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq
```

## Related Documentation

- [Validator Monitoring](VALIDATOR_MONITORING.md)
- [Sync Monitoring](SYNC_MONITORING.md)
- [Prometheus Integration](PROMETHEUS_INTEGRATION.md)
