# Lido CSM Integration Implementation Guide

## Overview

This guide provides instructions for implementing the Lido Community Staking Module (CSM) integration with Ephemery nodes. The implementation includes setup scripts, monitoring tools, and Ansible playbooks for deployment.

## Components

The Lido CSM integration consists of the following components:

1. **Setup Script**: A shell script for configuring and deploying the CSM integration
2. **Monitoring Script**: A tool for monitoring CSM status, performance, validators, and more
3. **Ansible Playbook**: An automated deployment playbook for consistent setup
4. **Configuration Templates**: Standard configuration files for CSM setup

## Prerequisites

Before deploying the CSM integration, ensure that:

1. You have a functioning Ephemery node deployed
2. Docker is installed and running
3. The Ephemery network (`ephemery-net`) is set up
4. Your system has sufficient resources (at least 4 CPU cores, 8GB RAM, 50GB disk space)

## Manual Deployment

### Using the Setup Script

To deploy the CSM integration using the setup script:

```bash
# Basic setup with default settings
./scripts/deployment/setup_lido_csm.sh

# Setup with custom bond amount
./scripts/deployment/setup_lido_csm.sh --bond-amount 3.0

# Setup with validator monitoring
./scripts/deployment/setup_lido_csm.sh --enable-validator-monitor

# Complete setup with all monitoring options
./scripts/deployment/setup_lido_csm.sh --bond-amount 5.0 \
  --enable-validator-monitor \
  --enable-ejector-monitor \
  --enable-protocol-monitor \
  --enable-profitability
```

### Available Options

The setup script supports the following options:

| Option | Description | Default |
|--------|-------------|---------|
| `--base-dir DIR` | Base directory for Ephemery | `~/ephemery` |
| `--bond-amount AMOUNT` | Initial bond amount in ETH | `2.0` |
| `--metrics-port PORT` | Port for CSM metrics | `8888` |
| `--api-port PORT` | Port for CSM API | `9000` |
| `--docker-image IMAGE` | Docker image for CSM | `lidofinance/csm:latest` |
| `--enable-profitability` | Enable profitability calculator | `false` |
| `--enable-validator-monitor` | Enable specialized validator monitoring | `false` |
| `--enable-ejector-monitor` | Enable ejector monitoring system | `false` |
| `--enable-protocol-monitor` | Enable protocol health monitoring | `false` |
| `--reset` | Force reset of CSM configuration and data | `false` |
| `--yes` | Skip confirmations | `false` |
| `--debug` | Enable debug output | `false` |

## Automated Deployment

### Using the Ansible Playbook

To deploy the CSM integration using Ansible:

```bash
# Basic deployment
ansible-playbook playbooks/deploy_lido_csm.yaml -i inventory.yaml

# Deployment with custom options
ansible-playbook playbooks/deploy_lido_csm.yaml -i inventory.yaml \
  -e "csm_bond_amount=3.0 csm_validator_monitoring=true csm_ejector_monitoring=true"

# Force reset of existing installation
ansible-playbook playbooks/deploy_lido_csm.yaml -i inventory.yaml \
  -e "force_reset=true"
```

### Available Variables

The Ansible playbook supports the following variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `ephemery_base_dir` | Base directory for Ephemery | `~/ephemery` |
| `csm_data_dir` | Data directory for CSM | `~/ephemery/data/lido-csm` |
| `csm_config_dir` | Configuration directory for CSM | `~/ephemery/config/lido-csm` |
| `csm_logs_dir` | Logs directory for CSM | `~/ephemery/logs/lido-csm` |
| `csm_metrics_port` | Port for CSM metrics | `8888` |
| `csm_api_port` | Port for CSM API | `9000` |
| `csm_docker_image` | Docker image for CSM | `lidofinance/csm:latest` |
| `csm_bond_amount` | Initial bond amount in ETH | `2.0` |
| `csm_container_name` | Name for the CSM container | `ephemery-lido-csm` |
| `csm_validator_monitoring` | Enable validator monitoring | `false` |
| `csm_ejector_monitoring` | Enable ejector monitoring | `false` |
| `csm_protocol_monitoring` | Enable protocol monitoring | `false` |
| `csm_profitability_calculator` | Enable profitability calculator | `false` |
| `force_reset` | Force reset of existing installation | `false` |

## Monitoring

### Using the Monitoring Script

The CSM integration includes a comprehensive monitoring script:

```bash
# Check basic CSM status
./scripts/monitoring/monitor_lido_csm.sh status

# Monitor performance metrics
./scripts/monitoring/monitor_lido_csm.sh performance

# Monitor validator status
./scripts/monitoring/monitor_lido_csm.sh validators

# Monitor bond status
./scripts/monitoring/monitor_lido_csm.sh bond

# Monitor queue status
./scripts/monitoring/monitor_lido_csm.sh queue

# Monitor ejector status
./scripts/monitoring/monitor_lido_csm.sh ejector

# Launch monitoring dashboard
./scripts/monitoring/monitor_lido_csm.sh dashboard

# Continuous monitoring with 10-second interval
./scripts/monitoring/monitor_lido_csm.sh performance --continuous --interval 10

# Verbose output with more details
./scripts/monitoring/monitor_lido_csm.sh validators --verbose
```

### Available Operations

The monitoring script supports the following operations:

| Operation | Description |
|-----------|-------------|
| `status` | Show current CSM status (default) |
| `performance` | Show performance metrics |
| `validators` | Show CSM validators status |
| `bond` | Show bond status and health |
| `queue` | Show stake distribution queue status |
| `ejector` | Show ejector status and metrics |
| `dashboard` | Launch monitoring dashboard |

### Available Options

The monitoring script supports the following options:

| Option | Description | Default |
|--------|-------------|---------|
| `--api-endpoint URL` | CSM API endpoint | `http://localhost:9000` |
| `--metrics-endpoint URL` | CSM metrics endpoint | `http://localhost:8888/metrics` |
| `-c, --continuous` | Enable continuous monitoring | `false` |
| `-i, --interval SEC` | Monitoring interval in seconds | `30` |
| `--grafana-port PORT` | Grafana port for dashboard | `3000` |
| `-v, --verbose` | Enable verbose output | `false` |
| `--debug` | Enable debug output | `false` |

## Validator Management

### Bond Management

The bond is a security deposit required for participation in the Community Staking Module. The bond serves as collateral for all of a Node Operator's validators.

To manage your bond:

1. Check bond status using the monitoring script:
   ```bash
   ./scripts/monitoring/monitor_lido_csm.sh bond
   ```

2. Get bond optimization recommendations:
   ```bash
   ./scripts/monitoring/monitor_lido_csm.sh bond --verbose
   ```

3. Modify bond amount (requires redeployment):
   ```bash
   ./scripts/deployment/setup_lido_csm.sh --bond-amount <new_amount> --reset
   ```

### Queue Management

The CSM uses a FIFO (First In, First Out) queue for stake distribution. To monitor your position:

1. Check queue status:
   ```bash
   ./scripts/monitoring/monitor_lido_csm.sh queue
   ```

2. Get detailed queue analytics:
   ```bash
   ./scripts/monitoring/monitor_lido_csm.sh queue --verbose
   ```

### Ejector Management

The ejector system is responsible for ejecting underperforming validators from the CSM. To monitor:

1. Check ejector status:
   ```bash
   ./scripts/monitoring/monitor_lido_csm.sh ejector
   ```

2. Get detailed ejector performance metrics:
   ```bash
   ./scripts/monitoring/monitor_lido_csm.sh ejector --verbose
   ```

## Troubleshooting

### Common Issues

#### CSM Container Not Starting

If the CSM container fails to start:

1. Check the container logs:
   ```bash
   docker logs ephemery-lido-csm
   ```

2. Verify the configuration:
   ```bash
   cat ~/ephemery/config/lido-csm/config.yaml
   ```

3. Ensure the Ephemery network exists:
   ```bash
   docker network inspect ephemery-net
   ```

#### API Not Responding

If the CSM API is not responding:

1. Check if the container is running:
   ```bash
   docker ps | grep ephemery-lido-csm
   ```

2. Check if the API port is accessible:
   ```bash
   curl http://localhost:9000/status
   ```

3. Check container logs for errors:
   ```bash
   docker logs ephemery-lido-csm | grep ERROR
   ```

### Resetting CSM

To completely reset the CSM integration:

1. Using the setup script:
   ```bash
   ./scripts/deployment/setup_lido_csm.sh --reset --yes
   ```

2. Using the Ansible playbook:
   ```bash
   ansible-playbook playbooks/deploy_lido_csm.yaml -i inventory.yaml -e "force_reset=true"
   ```

3. Manual reset:
   ```bash
   docker stop ephemery-lido-csm
   docker rm ephemery-lido-csm
   rm -rf ~/ephemery/data/lido-csm ~/ephemery/config/lido-csm
   ```

## Advanced Configuration

For advanced configurations, you can directly edit the configuration file:

```bash
vim ~/ephemery/config/lido-csm/config.yaml
```

After modifying the configuration, restart the container:

```bash
docker restart ephemery-lido-csm
```

## Security Considerations

1. **Bond Management**: Ensure your bond amount is sufficient to cover all validators. Insufficient bond can lead to ejection.

2. **API Security**: The CSM API does not include authentication by default. Consider securing it with a reverse proxy if exposed publicly.

3. **Key Management**: Validator keys are managed through the Ephemery validator system. Ensure proper backup and security.

4. **Resource Allocation**: Monitor resource usage to ensure the CSM has sufficient resources for operation.

## Related Documentation

- [Lido CSM Integration](./LIDO_CSM_INTEGRATION.md) - Comprehensive documentation of the CSM integration
- [Validator Management](./VALIDATOR_MANAGEMENT.md) - Guide for managing validators
- [Monitoring](./MONITORING.md) - Overview of monitoring capabilities
- [Dashboard Implementation](./DASHBOARD_IMPLEMENTATION.md) - Details on dashboard implementation

## Advanced Validator Performance Analytics

The CSM integration now includes comprehensive advanced validator performance analytics tools that provide operators with detailed insights into CSM validator performance, bond optimization, and predictive analytics.

### CSM Validator Performance Monitoring

The CSM validator performance monitoring script (`scripts/monitoring/csm_validator_performance.sh`) provides real-time and historical monitoring of CSM validators with the following capabilities:

- **Real-time Performance Metrics**
  - Attestation effectiveness tracking
  - Balance growth monitoring
  - Inclusion distance measurement
  - Proposal performance tracking
  - Sync committee participation metrics

- **Advanced Analytics**
  - Performance anomaly detection
  - Trend analysis for early issue detection
  - Comparative analysis against network averages
  - Historical performance tracking with data storage
  - Performance rating and classification

- **Alert Generation**
  - Configurable alert thresholds
  - Multiple notification channels (console, email, Slack, PagerDuty)
  - Priority-based alerting with severity levels
  - Alert summaries with actionable recommendations

- **Flexible Output**
  - Multiple output formats (JSON, CSV, terminal, HTML)
  - Customizable report generation
  - Integration with analytics dashboard

#### Usage

```bash
# Basic monitoring with terminal output
./scripts/monitoring/csm_validator_performance.sh

# Monitoring with specific options
./scripts/monitoring/csm_validator_performance.sh \
  --output-file=/var/log/ephemery/csm_performance.json \
  --output=json \
  --monitoring-interval=300 \
  --alert-threshold=5 \
  --compare-network \
  --verbose
```

### CSM Analytics Suite

The CSM Analytics Suite (`scripts/monitoring/csm_analytics_suite.sh`) provides a unified interface to all CSM analytics tools, including:

- **Validator Performance Monitoring**: Real-time and historical performance tracking
- **Predictive Analytics**: Forward-looking performance projections
- **Bond Optimization**: Analysis and recommendations for bond amounts
- **Dashboard Generation**: Comprehensive analytics dashboard
- **Automation Tools**: Scheduled analytics setup with cron jobs

#### Usage

```bash
# Run validator performance monitoring
./scripts/monitoring/csm_analytics_suite.sh monitor

# Run predictive analytics
./scripts/monitoring/csm_analytics_suite.sh analyze

# Run bond optimization
./scripts/monitoring/csm_analytics_suite.sh optimize

# Generate a comprehensive analytics dashboard
./scripts/monitoring/csm_analytics_suite.sh dashboard

# Set up automated analytics (cron jobs)
./scripts/monitoring/csm_analytics_suite.sh automate

# Show help message
./scripts/monitoring/csm_analytics_suite.sh help
```

### Configuration System

All CSM analytics tools use a flexible JSON-based configuration system located in `scripts/monitoring/config/`:

- **csm_validator_performance.json**: Configuration for the validator performance monitoring script
- **csm_analytics_suite.json**: Configuration for the CSM analytics suite

The configuration includes:

- **Directory Settings**: Paths for data, metrics, and output
- **API Endpoints**: URLs for beacon API, CSM API, and network API
- **Alert Settings**: Notification channels, thresholds, and formats
- **Performance Thresholds**: Warning and critical levels for different metrics
- **Historical Data**: Retention periods and analysis frequency

#### Example Configuration

```json
{
  "data_directory": "/var/lib/validator/data",
  "metrics_directory": "/var/lib/validator/metrics",
  "monitoring_interval": 60,
  "alert_threshold": 10,
  "compare_network": true,
  "api_endpoints": {
    "beacon_api": "http://localhost:5052",
    "csm_api": "http://localhost:8545",
    "network_api": "https://beaconcha.in/api/v1"
  },
  "alert_channels": {
    "email": {
      "enabled": false,
      "recipients": ["admin@example.com"],
      "smtp_server": "smtp.example.com",
      "smtp_port": 587
    },
    "slack": {
      "enabled": false,
      "webhook_url": "https://hooks.slack.com/services/xxx/yyy/zzz",
      "channel": "#monitoring"
    },
    "pagerduty": {
      "enabled": false,
      "integration_key": "xxxxxxxxxxxx"
    }
  },
  "performance_thresholds": {
    "effectiveness": {
      "warning": 95,
      "critical": 90
    },
    "inclusion_distance": {
      "warning": 3,
      "critical": 5
    },
    "balance_growth": {
      "warning": -0.01,
      "critical": -0.05
    }
  },
  "historical_data": {
    "retention_days": 90,
    "analysis_frequency": 3600
  }
}
```

### Integration with Existing Tools

The CSM validator performance analytics tools integrate seamlessly with the existing Ephemery ecosystem:

- **Validator Dashboard**: Analytics accessible through the main validator dashboard
- **Monitoring System**: Metrics collection integrated with overall monitoring
- **Alert System**: Alerts incorporated into the existing notification framework
- **Data Storage**: Performance data stored in standard metrics directory

This integrated approach ensures operators have a comprehensive view of CSM validator performance within the context of their overall Ephemery node operations. 