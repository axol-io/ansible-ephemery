# Validator Performance Monitoring

This document describes the validator performance monitoring features implemented for Ephemery nodes, including setup instructions, usage, and customization options.

## Overview

The validator performance monitoring system provides comprehensive metrics, alerts, and visual dashboards for monitoring the health and effectiveness of your validators on the Ephemery network. It helps identify underperforming validators and potential issues before they impact your staking rewards.

## Features

The validator performance monitoring system offers:

- **Real-time Performance Metrics**
  - Balance tracking and trend analysis
  - Attestation effectiveness reporting
  - Missed proposal detection
  - Slashing risk indicators

- **Visual Dashboard**
  - Terminal-based visual dashboard
  - Performance trend graphs
  - Status distribution visualization
  - Hourly income calculation

- **Alerting System**
  - Configurable performance thresholds
  - Underperforming validator detection
  - Alert generation and delivery
  - Historical alert tracking

- **Data Collection and Analysis**
  - Automatic metrics collection
  - Historical data retention
  - Performance trend analysis
  - Comparative reports

## Components

The validator performance monitoring system consists of the following components:

1. **Metrics Collection Script** (`advanced_validator_monitoring.sh`)
   - Collects metrics from the Validator API and Beacon Node API
   - Stores metrics in JSON format for analysis
   - Maintains historical data for trend analysis

2. **Performance Dashboard**
   - Terminal-based visual dashboard for real-time monitoring
   - Displays key metrics, status distributions, and trends
   - Provides hourly earning calculations

3. **Alert System**
   - Detects validators performing below threshold
   - Generates alerts for review
   - Supports multiple alert destinations

## Installation

The validator performance monitoring system is included with the Ephemery deployment, but can also be installed separately:

```bash
# Deploy the validator performance monitoring system
./scripts/monitoring/advanced_validator_monitoring.sh --dashboard --alerts
```

## Usage

### Basic Status Check

To check the current status of your validators:

```bash
./scripts/monitoring/advanced_validator_monitoring.sh --check
```

### Live Dashboard

To view the live dashboard:

```bash
./scripts/monitoring/advanced_validator_monitoring.sh --dashboard
```

### Configure Alerts

To enable alerts for underperforming validators:

```bash
./scripts/monitoring/advanced_validator_monitoring.sh --alerts --threshold 90
```

This will alert you if any validator's balance falls below 90% of the average.

### Full Configuration

For a comprehensive monitoring setup:

```bash
./scripts/monitoring/advanced_validator_monitoring.sh \
  --output /path/to/custom/metrics/dir \
  --validator-api http://localhost:5064 \
  --beacon-api http://localhost:5052 \
  --dashboard \
  --alerts \
  --threshold 85 \
  --verbose
```

## Configuration Options

The validator performance monitoring system supports the following configuration options:

| Option | Description | Default |
|--------|-------------|---------|
| `--output DIR` | Output directory for metrics | `./validator_metrics` |
| `--validator-api URL` | Validator API URL | `http://localhost:5064` |
| `--beacon-api URL` | Beacon API URL | `http://localhost:5052` |
| `--alerts` | Generate alerts for underperforming validators | `false` |
| `--threshold NUM` | Alert threshold percentage | `90` |
| `--check` | Only check current validator status | `false` |
| `--dashboard` | Display live dashboard | `false` |
| `--verbose` | Enable verbose output | `false` |

## Metrics Collected

The system collects and analyzes the following metrics:

- **Balance Metrics**
  - Current balance
  - Historical balance trend
  - Hourly earnings rate
  - Comparative performance to network average

- **Status Metrics**
  - Active validators
  - Pending validators
  - Exiting validators
  - Slashed validators

- **Performance Metrics**
  - Attestation effectiveness
  - Proposal participation
  - Missed attestations
  - Sync committee participation

## Alert System

The alert system monitors for the following conditions:

1. **Underperforming Validators**
   - Validators with balance below the specified threshold percentage of the average
   
2. **Missed Attestations**
   - Validators missing consecutive attestations
   
3. **Balance Decline**
   - Validators with consistently declining balance
   
4. **Status Changes**
   - Validators changing status (e.g., from active to exiting)

When an alert condition is detected, an alert is generated and saved to the alerts directory.

## Data Retention

By default, the system retains the following data:

- **Current Status**: Latest validator status
- **Historical Data**: Up to 1,000 historical data points (configurable)
- **Alerts**: All generated alerts
- **Performance Reports**: Daily and weekly reports

## Extending the System

The validator performance monitoring system can be extended through:

1. **Custom Alert Handlers**
   - Add custom alert handlers in the configuration
   
2. **Additional Metrics Collection**
   - Implement custom metrics collectors
   
3. **Integration with External Systems**
   - Forward metrics to external monitoring systems

## Troubleshooting

### Common Issues

1. **Connection Error to Validator API**
   - Verify the validator API is running
   - Check the API URL configuration
   - Ensure firewall rules allow access

2. **Missing Historical Data**
   - Verify the output directory permissions
   - Check available disk space
   - Ensure the script is running regularly

3. **Dashboard Rendering Issues**
   - Install required dependencies (jq, watch)
   - Use a terminal that supports ANSI color codes
   - Increase terminal size for better visualization

## References

- [Validator Key Management](./VALIDATOR_KEY_MANAGEMENT.md)
- [Validator Key Restore](./VALIDATOR_KEY_RESTORE.md)
- [Ephemery Setup](./EPHEMERY_SETUP.md)
- [Genesis Validator Guide](../OPERATIONS/GENESIS_VALIDATOR.md)
