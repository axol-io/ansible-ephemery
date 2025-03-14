# Enhanced Validator Dashboard User Guide

## Overview

The Enhanced Validator Dashboard provides a comprehensive monitoring solution for Ephemery validators. This guide explains how to set up, use, and customize the dashboard to monitor your validator performance effectively.

## Features

The Enhanced Validator Dashboard offers:

- **Real-time Performance Monitoring**
  - Balance tracking with trend visualization
  - Attestation effectiveness reporting
  - Proposal participation tracking
  - Sync committee performance

- **Visual Status Indicators**
  - Color-coded status displays
  - Status distribution charts
  - Performance trend graphs
  - Comparative metrics against network averages

- **Advanced Analytics**
  - Historical performance analysis
  - Income and reward calculations
  - Effectiveness and uptime statistics
  - Performance benchmarking

- **Customizable Views**
  - Compact view for basic monitoring
  - Detailed view with validator-specific metrics
  - Full view with comprehensive data
  - Historical analysis reports with charts

## Installation

The Enhanced Validator Dashboard is included in your Ephemery installation. To ensure you have the latest version:

```bash
# Update your repository
git pull

# Make sure the dashboard scripts are executable
chmod +x scripts/validator-dashboard.sh
chmod +x scripts/monitoring/validator_dashboard.sh
chmod +x scripts/monitoring/advanced_validator_monitoring.sh
```

## Quick Start

To launch the dashboard with default settings:

```bash
./scripts/validator-dashboard.sh
```

This will connect to your local validator and beacon node endpoints and display the full dashboard view.

## Usage Options

The validator dashboard offers various options to customize your monitoring experience:

```bash
./scripts/validator-dashboard.sh [options]

Options:
  -b, --beacon URL      Beacon node API URL (default: http://localhost:5052)
  -v, --validator URL   Validator API URL (default: http://localhost:5064)
  -r, --refresh N       Refresh interval in seconds (default: 10)
  -c, --compact         Use compact view (summary only)
  -d, --detailed        Use detailed view (includes validator details)
  -f, --full            Use full view with all information (default)
  -a, --analyze         Generate historical performance analysis report
  --period PERIOD       Analysis period (1d, 7d, 30d, 90d, all) for historical analysis
  --charts              Generate performance charts (requires gnuplot)
  -h, --help            Show this help message
```

### View Modes

The dashboard offers three view modes to suit different monitoring needs:

1. **Compact View** (`-c, --compact`): Shows a summary of validator status, perfect for quick checks or smaller screens:

   ```bash
   ./scripts/validator-dashboard.sh --compact
   ```

2. **Detailed View** (`-d, --detailed`): Shows validator-specific metrics and status for more in-depth monitoring:

   ```bash
   ./scripts/validator-dashboard.sh --detailed
   ```

3. **Full View** (`-f, --full`): The default view, displaying all available metrics and analytics:

   ```bash
   ./scripts/validator-dashboard.sh --full
   ```

### Historical Analysis

The dashboard can generate historical performance analysis reports:

```bash
# Generate performance report for the last 7 days
./scripts/validator-dashboard.sh --analyze

# Generate detailed report with charts for last 30 days
./scripts/validator-dashboard.sh --analyze --period 30d --charts

# Generate a report for all time with charts
./scripts/validator-dashboard.sh --analyze --period all --charts
```

## Dashboard Sections

The Enhanced Validator Dashboard is organized into several sections:

### 1. Summary Section

Displays aggregate statistics for all validators:
- Total validators
- Active validators
- Total balance
- Average effectiveness
- Network participation rate

### 2. Status Distribution

Visual representation of validator statuses:
- Active validators
- Pending validators
- Slashed validators
- Exited validators

### 3. Performance Metrics

Detailed performance metrics for validators:
- Attestation effectiveness
- Proposal participation
- Sync committee performance
- Income and rewards

### 4. Validator List

List of individual validators with key metrics:
- Public key (abbreviated)
- Status
- Balance
- Effectiveness
- Last attestation
- Proposals (scheduled/completed)

### 5. Recent Events

Timeline of recent validator events:
- Attestations
- Proposals
- Sync committee participations
- Status changes

### 6. Performance Charts

Visual charts showing performance trends:
- Balance history
- Effectiveness trends
- Income projections
- Comparison to network averages

## Advanced Configuration

You can customize the dashboard behavior by creating a configuration file:

```bash
mkdir -p ~/ephemery/config
cat > ~/ephemery/config/validator_dashboard.conf << EOF
# Enhanced Validator Dashboard Configuration

# Connection Settings
BEACON_NODE_URL="http://localhost:5052"
VALIDATOR_URL="http://localhost:5064"

# Display Settings
REFRESH_INTERVAL=10
DEFAULT_VIEW="full"
CHART_STYLE="line"
COLOR_THEME="default"

# Alert Thresholds
EFFECTIVENESS_ALERT=90
BALANCE_DECLINE_ALERT=0.01
MISSED_ATTESTATION_ALERT=3

# Historical Data
HISTORY_DAYS=30
HISTORY_RESOLUTION="hourly"
EOF
```

## Troubleshooting

### Connection Issues

If the dashboard cannot connect to the beacon node or validator client:

1. Verify the services are running:
   ```bash
   docker ps | grep ephemery
   ```

2. Check API endpoints are accessible:
   ```bash
   curl -s http://localhost:5052/eth/v1/node/health
   curl -s http://localhost:5064/lighthouse/health
   ```

3. Try specifying the endpoints explicitly:
   ```bash
   ./scripts/validator-dashboard.sh --beacon http://your-beacon-node:5052 --validator http://your-validator:5064
   ```

### Display Issues

If the dashboard doesn't display correctly:

1. Ensure your terminal supports colors and Unicode characters
2. Try using a different terminal or SSH client
3. Adjust your terminal window size (minimum 100x30 recommended)

### Data Issues

If metrics appear incorrect or incomplete:

1. Verify your validator is properly synced:
   ```bash
   curl -s http://localhost:5052/eth/v1/node/syncing | jq
   ```

2. Check validator status:
   ```bash
   curl -s http://localhost:5052/eth/v1/beacon/states/head/validators | jq
   ```

3. Clear the metrics cache and restart collection:
   ```bash
   rm -rf ~/ephemery/data/validator_metrics/*
   ./scripts/monitoring/advanced_validator_monitoring.sh --reset
   ```

## Integration with Other Tools

### Prometheus Integration

The dashboard metrics can be exposed to Prometheus:

1. Run the monitoring script with Prometheus output:
   ```bash
   ./scripts/monitoring/advanced_validator_monitoring.sh --prometheus
   ```

2. Configure Prometheus to scrape the metrics endpoint:
   ```yaml
   # prometheus.yml
   scrape_configs:
     - job_name: 'validator_metrics'
       static_configs:
         - targets: ['localhost:8080']
   ```

### Grafana Integration

A pre-configured Grafana dashboard is available:

1. Import the dashboard JSON from `dashboard/validator-dashboard.json`
2. Configure Grafana to use your Prometheus data source
3. Access the dashboard through your Grafana instance

## Conclusion

The Enhanced Validator Dashboard provides comprehensive monitoring tools for Ephemery validators. By using this dashboard regularly, you can ensure optimal validator performance, quickly identify and resolve issues, and maximize your staking rewards. 