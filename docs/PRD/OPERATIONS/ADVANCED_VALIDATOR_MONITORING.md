# Advanced Validator Performance Monitoring

This document describes the Advanced Validator Performance Monitoring system for Ephemery nodes, specifically focusing on the alerting capabilities.

## Overview

The Advanced Validator Performance Monitoring system is a comprehensive solution for monitoring validator performance, identifying issues, and generating alerts. It is designed to help operators maintain optimal validator performance and quickly respond to issues.

The system follows a phased implementation approach:

1. **Enhanced Metrics Collection** (Completed) - Comprehensive collection of validator performance metrics
2. **Dashboard Enhancement** (Completed) - Advanced Grafana dashboards for visualizing validator performance
3. **Advanced Alerting** (Current Phase) - Real-time alerting for performance issues
4. **Analytics and Recommendations** (Future Phase) - Predictive analytics and automatic remediation suggestions

This document focuses on the Advanced Alerting phase, which builds upon the metrics collection and dashboard enhancements to provide real-time alerting for validator performance issues.

## Features

The Advanced Validator Alerting system includes the following features:

- **Comprehensive Monitoring** - Monitors various aspects of validator performance:
  - Attestation effectiveness
  - Proposal success rate
  - Balance trends
  - Sync status
  - System resource usage (CPU, memory, disk)
  - Peer count

- **Flexible Notification Options** - Multiple notification channels:
  - Email notifications
  - Webhook integrations (for custom applications and services)
  - Telegram notifications
  - Discord notifications

- **Alert Severity Levels** - Four severity levels for proper prioritization:
  - Info - Informational alerts, not requiring immediate action
  - Warning - Potential issues that may require attention
  - Error - Significant issues requiring prompt intervention
  - Critical - Urgent issues requiring immediate action

- **Alert History** - Maintains a history of alerts for analysis and tracking

- **Prometheus Integration** - Exposes alerts as Prometheus metrics for integration with existing monitoring systems

- **Grafana Dashboard** - Dedicated Grafana dashboard for visualizing alerts and performance metrics

## Installation

The alerting system can be deployed using the provided setup script:

```bash
./scripts/monitoring/setup_validator_alerts.sh [options]
```

### Installation Options

| Option | Description |
|--------|-------------|
| `--base-dir DIR` | Base directory (default: /opt/ephemery) |
| `--config-file FILE` | Path to custom configuration file |
| `--with-email` | Enable email notifications |
| `--with-webhook URL` | Enable webhook notifications to specified URL |
| `--with-telegram` | Enable Telegram notifications |
| `--with-discord URL` | Enable Discord webhook notifications |
| `--no-restart` | Don't restart services after configuration |
| `--verbose` | Enable verbose output |
| `--help` | Show help message |

### Example

```bash
# Basic installation
./scripts/monitoring/setup_validator_alerts.sh

# Installation with email and Discord notifications
./scripts/monitoring/setup_validator_alerts.sh --with-email --with-discord https://discord.com/api/webhooks/your-webhook-url
```

## Configuration

The alerting system is configured via a JSON configuration file located at `$BASE_DIR/validator_metrics/alerts/alerts_config.json`.

### Alert Thresholds

The default thresholds can be adjusted to meet your specific needs:

```json
"alert_thresholds": {
    "attestation_performance": 90,
    "proposal_performance": 100,
    "balance_decrease": 0.02,
    "sync_status": 50,
    "peer_count": 10,
    "cpu_usage": 80,
    "memory_usage": 80,
    "disk_usage": 80
}
```

| Threshold | Description | Default Value |
|-----------|-------------|---------------|
| `attestation_performance` | Minimum percentage of successful attestations | 90% |
| `proposal_performance` | Minimum percentage of successful proposals | 100% |
| `balance_decrease` | Maximum acceptable balance decrease (as a decimal) | 0.02 (2%) |
| `sync_status` | Maximum acceptable seconds behind chain head | 50 seconds |
| `peer_count` | Minimum number of peers | 10 |
| `cpu_usage` | Maximum CPU usage percentage | 80% |
| `memory_usage` | Maximum memory usage percentage | 80% |
| `disk_usage` | Maximum disk usage percentage | 80% |

### Notification Settings

Configure notification channels based on your preferences:

```json
"notification_settings": {
    "email": {
        "enabled": false,
        "smtp_server": "smtp.example.com",
        "smtp_port": 587,
        "username": "user@example.com",
        "password": "",
        "recipients": ["admin@example.com"]
    },
    "webhook": {
        "enabled": false,
        "url": ""
    },
    "telegram": {
        "enabled": false,
        "bot_token": "",
        "chat_id": ""
    },
    "discord": {
        "enabled": false,
        "webhook_url": ""
    }
}
```

### Alert Settings

Configure which severity levels trigger notifications and their cooldown periods:

```json
"alert_settings": {
    "notification_levels": {
        "info": false,
        "warning": true,
        "error": true,
        "critical": true
    },
    "cooldown_periods": {
        "info": 3600,
        "warning": 1800,
        "error": 900,
        "critical": 300
    }
}
```

| Setting | Description |
|---------|-------------|
| `notification_levels` | Which severity levels trigger notifications |
| `cooldown_periods` | Time in seconds between repeated notifications of the same type |

### System Settings

Configure general system behavior:

```json
"system_settings": {
    "check_interval": 300,
    "history_retention_days": 30,
    "log_level": "info"
}
```

| Setting | Description | Default Value |
|---------|-------------|---------------|
| `check_interval` | How often to check for issues (in seconds) | 300 (5 minutes) |
| `history_retention_days` | Number of days to retain alert history | 30 days |
| `log_level` | Logging verbosity (debug, info, warning, error) | info |

## Using the Dashboard

The Advanced Validator Performance Monitoring dashboard in Grafana provides a comprehensive view of validator performance and alerts.

### Dashboard Sections

1. **Overview** - Summary stats including active validators, alert counts, and key performance indicators
2. **Validator Performance** - Detailed charts for attestation effectiveness, proposal success, and validator balances
3. **Alerts & System** - Active alerts table and system resource usage graphs

### Accessing the Dashboard

The dashboard is accessible via Grafana at:

```
http://<your-server-ip>:3000/d/validator-performance-advanced
```

### Alert Table

The alert table displays all active (unacknowledged) alerts with the following information:

- Time - When the alert was generated
- Severity - Alert severity level (color-coded)
- Type - The type of alert
- Message - Detailed alert description

## Advanced Usage

### Manual Alert Checks

To manually run an alert check:

```bash
/opt/ephemery/scripts/validator_alerts_system.sh --check
```

### Acknowledge Alerts

To acknowledge an alert (prevent further notifications):

```bash
/opt/ephemery/scripts/validator_alerts_system.sh --acknowledge <alert-id>
```

### View Alert History

```bash
/opt/ephemery/scripts/validator_alerts_system.sh --history
```

### Test Notifications

```bash
/opt/ephemery/scripts/validator_alerts_system.sh --test-notification --severity warning --message "Test notification"
```

## Troubleshooting

### Check Service Status

```bash
systemctl status validator-alerts.service
systemctl status validator-alerts-exporter.service
```

### View Alert Logs

```bash
tail -f /opt/ephemery/validator_metrics/alerts/alerts.log
```

### Common Issues

**No Alerts Being Generated**

1. Check if the validator alerts service is running
2. Verify the configuration file exists and is valid JSON
3. Check if metrics data exists in the metrics directory

**Alerts Not Showing in Grafana**

1. Verify the Prometheus exporter is running
2. Check if Prometheus is scraping the alerts endpoint
3. Ensure the dashboard is properly imported in Grafana

**Notifications Not Being Sent**

1. Check the notification configuration in the alerts config file
2. Verify connectivity to the notification service (SMTP, webhook URL, etc.)
3. Check alert severity levels and cooldown periods

## Integration with External Systems

The alerting system can be integrated with external systems via:

1. **Webhook Notifications** - Send JSON-formatted alerts to any HTTP endpoint
2. **Prometheus Metrics** - Alert data is exposed as Prometheus metrics at `http://localhost:9877/metrics`
3. **Grafana** - The dashboard can be embedded into other Grafana instances

## Conclusion

The Advanced Validator Performance Monitoring system with alerting capabilities provides comprehensive monitoring and notification for Ephemery validator operators. By properly configuring thresholds and notification channels, operators can ensure optimal validator performance and quickly respond to issues.

## Related Documentation

- [Validator Operations Guide](./VALIDATOR_OPERATIONS.md)
- [Genesis Validator Guide](./GENESIS_VALIDATOR.md)
- [Monitoring System Overview](./MONITORING_SYSTEM.md)
- [Ephemery Testnet Overview](../OVERVIEW/EPHEMERY_TESTNET.md) 