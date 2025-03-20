# Validator Monitoring Guide

This guide provides detailed information on using the Ephemery validator monitoring system.

## Overview

The Ephemery validator monitoring system provides comprehensive tools for monitoring and managing validators in your Ephemery nodes. It includes:

- Real-time status monitoring
- Performance metrics
- Health checks
- Interactive dashboard
- Alerting capabilities

## Installation

The validator monitoring system is installed as part of the validator management deployment:

```bash
ansible-playbook playbooks/deploy_validator_management.yaml -i your-inventory.yaml
```

This will install all necessary scripts and set up the monitoring configuration.

## Configuration

The validator monitoring system is configured through the following files:

- `/opt/ephemery/config/validator_monitoring.conf` - Main configuration file
- `/opt/ephemery/config/ephemery_paths.conf` - Path configuration

### Configuration Options

The main configuration file supports the following options:

```bash
# Validator Monitoring Configuration
BEACON_API="http://localhost:5052"           # Beacon node API endpoint
VALIDATOR_API="http://localhost:5062"        # Validator API endpoint
VALIDATOR_METRICS_API="http://localhost:5064/metrics"  # Validator metrics endpoint
ALERT_THRESHOLD="90"                         # Alert threshold percentage
MONITORING_INTERVAL="60"                     # Monitoring interval in seconds
```

## Basic Usage

The validator monitoring system provides several operations:

### Status Monitoring

Check the current status of your validators:

```bash
./scripts/manage-validator.sh monitor status
```

This will show:
- Number of active validators
- Total validators
- Active percentage
- Beacon node sync status

### Performance Monitoring

Check the performance of your validators:

```bash
./scripts/manage-validator.sh monitor performance
```

This will show:
- Attestation hits and misses
- Attestation effectiveness
- Alerts if effectiveness is below threshold

### Health Checks

Run a comprehensive health check on your validators:

```bash
./scripts/manage-validator.sh monitor health
```

This will check:
- If validator container is running
- Connection to beacon node
- Recent errors in logs
- Warnings in metrics

### Dashboard

View a live dashboard of your validators:

```bash
./scripts/manage-validator.sh monitor dashboard --continuous
```

This will show a continuously updating dashboard with:
- Validator status
- Performance metrics
- Beacon node status
- System resources

## Advanced Usage

### Continuous Monitoring

Run continuous monitoring with a specified interval:

```bash
./scripts/manage-validator.sh monitor status --continuous --interval 30
```

This will update the status every 30 seconds.

### Custom Alert Thresholds

Set a custom alert threshold:

```bash
./scripts/manage-validator.sh monitor performance --threshold 95
```

This will alert if attestation effectiveness falls below 95%.

### Verbose Output

Get more detailed output:

```bash
./scripts/manage-validator.sh monitor status --verbose
```

## Integration with Monitoring Systems

### Prometheus Integration

The validator monitoring system exposes metrics that can be scraped by Prometheus:

```yaml
# prometheus.yaml
scrape_configs:
  - job_name: 'validator'
    static_configs:
      - targets: ['localhost:5064']
```

### Grafana Dashboard

A Grafana dashboard is available for visualizing validator metrics:

1. Import the dashboard JSON from `/opt/ephemery/config/grafana/validator-dashboard.json`
2. Configure the Prometheus data source
3. View your validator metrics in Grafana

## Troubleshooting

### Common Issues

#### Cannot Connect to Validator API

If you see errors connecting to the validator API:

1. Check if the validator container is running:
   ```bash
   docker ps | grep ephemery-validator
   ```
2. Verify the API endpoint in the configuration file
3. Check if the validator API port is exposed in the Docker configuration

#### Low Attestation Effectiveness

If you see low attestation effectiveness:

1. Check beacon node sync status
2. Verify network connectivity
3. Check validator logs for errors:
   ```bash
   docker logs ephemery-validator | grep -i error
   ```

#### Dashboard Not Updating

If the dashboard is not updating:

1. Check if the continuous flag is set
2. Verify the monitoring interval
3. Check for any error messages in the output

## Best Practices

1. **Regular Monitoring**: Check validator status at least daily
2. **Automated Health Checks**: Set up cron jobs for regular health checks
3. **Performance Tracking**: Monitor performance trends over time
4. **Backup Keys**: Regularly backup validator keys
5. **Alert Integration**: Integrate alerts with your notification system

## Further Resources

- [Validator Management Documentation](../../../scripts/validator/README.md)
- [Ephemery Deployment Guide](../DEPLOYMENT/DEPLOYMENT_GUIDE.md)
- [Lighthouse Validator Documentation](https://lighthouse-book.sigmaprime.io/validator-management.html)
