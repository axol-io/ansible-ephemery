# Validator Monitoring Guide

This guide provides information on how to use the advanced validator monitoring capabilities in the Ephemery project to track validator performance, earnings, and health.

## Overview

The validator monitoring system provides comprehensive monitoring for Ethereum validators, including performance metrics, attestation tracking, earnings estimation, and comparative analytics. This system helps operators maintain optimal validator performance and quickly identify issues.

## Monitoring Components

### 1. Performance Metrics

The validator performance monitoring system collects and displays the following metrics:

- Attestation effectiveness (successful vs. missed)
- Proposal effectiveness (successful vs. missed)
- Sync committee participation
- Validator balance tracking
- Validator status changes
- Validator activation times

### 2. Earnings Estimation

The earnings estimation component provides:

- Projected annual earnings based on current performance
- Comparative analysis against network averages
- Historical earnings tracking
- ROI calculations

### 3. Performance Comparison

The performance comparison tool allows:

- Comparing your validators against network averages
- Comparing performance across different client setups
- Analyzing performance trends over time
- Identifying underperforming validators

### 4. Alert System

The alert system provides:

- Attestation and proposal miss notifications
- Balance change alerts
- Validator status change alerts
- Performance degradation warnings
- Multiple notification channels (Discord, Telegram, Email)

## Setup and Usage

### Performance Monitoring Setup

To enable comprehensive validator monitoring:

1. Ensure Prometheus metrics are enabled for your clients
2. Deploy the validator dashboard using:

```bash
scripts/deploy_enhanced_validator_dashboard.sh
```

3. Configure alert thresholds in the configuration file:

```bash
nano /etc/ephemery/monitoring/validator_alerts.conf
```

### Accessing Monitoring Dashboards

The validator dashboards can be accessed at:

```
http://YOUR_SERVER_IP:3000/d/validator-performance/validator-performance
```

### Performance Benchmarking

To run a performance benchmark on your validators:

```bash
scripts/testing/tests/performance_benchmark/test_client_performance.sh
```

This will generate a detailed report of your validator's performance metrics compared to baseline expectations.

## Alert Configuration

To configure monitoring alerts:

1. Edit the alert configuration file:

```bash
nano /etc/ephemery/monitoring/validator_alerts.conf
```

2. Configure notification channels:

```ini
[notifications]
enable_discord = true
discord_webhook = "https://discord.com/api/webhooks/your-webhook-id"

enable_telegram = false
telegram_bot_token = ""
telegram_chat_id = ""

enable_email = false
email_from = ""
email_to = ""
smtp_server = ""
smtp_port = 587
```

3. Configure alert thresholds:

```ini
[thresholds]
# Percentage of attestations that must be successful
attestation_effectiveness_threshold = 95

# Alert if balance decreases by this percentage
balance_decrease_threshold = 1.0

# Alert if validator is offline for this many epochs
offline_epochs_threshold = 3
```

## Validator Health Check Script

To run a manual validator health check:

```bash
scripts/validator/check_validator_health.sh
```

This will perform a comprehensive check of your validator's health and provide recommendations for improvements.

## Interpreting Monitoring Data

### Key Performance Indicators

- **Attestation Effectiveness**: Should be above 99% for well-functioning validators
- **Balance Growth**: Should show steady increase over time
- **Proposal Success Rate**: Should be 100% (missed proposals are critical)
- **Sync Committee Performance**: Should show high participation when selected

### Troubleshooting Common Issues

If monitoring shows performance problems:

1. Check network connectivity and client synchronization
2. Verify client resource allocation (CPU, memory)
3. Ensure time synchronization is accurate
4. Check for client software updates
5. Review logs for error messages
6. Verify validator keys are correctly loaded

## Advanced Monitoring Features

### Historical Performance Tracking

The system maintains historical performance data allowing you to:

- Track validator performance over time
- Identify patterns in performance degradation
- Compare performance before and after configuration changes

### Client-Specific Metrics

The monitoring system includes client-specific metrics for:

- Lighthouse
- Prysm
- Teku
- Nimbus
- Lodestar

### Custom Grafana Dashboards

Additional dashboard templates are available for specific monitoring needs:

- Validator Economics Dashboard
- Genesis Validator Performance
- Client Comparison Dashboard
- Alert History Dashboard

## Conclusion

Proper validator monitoring is essential for maintaining optimal performance and ensuring maximum returns. The Ephemery validator monitoring system provides comprehensive tools to track all aspects of validator performance, alert on issues, and provide actionable insights for performance optimization. 