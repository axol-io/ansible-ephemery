# Validator Performance Monitoring

This document provides an overview of the validator performance monitoring system implemented in the Ansible Ephemery project.

## Overview

The validator performance monitoring system tracks the effectiveness and health of your validators, providing insights into attestation and proposal activities, and alerting you when performance issues arise.

Key features include:

1. **Real-time Performance Metrics**: Track validator attestation and proposal effectiveness
2. **Multi-Client Support**: Compatible with Lighthouse, Teku, Prysm, Nimbus, and Lodestar validator clients
3. **Visualization Dashboard**: Grafana dashboard for performance visualization
4. **Alert System**: Automated alerts for performance issues
5. **Historical Data Storage**: Track performance over time
6. **Prometheus Integration**: Export metrics for Prometheus consumption

## Installation

To deploy the validator performance monitoring system:

```bash
ansible-playbook playbooks/deploy_validator_monitoring.yml -i inventory.yaml
```

This playbook will:

1. Install the validator performance monitoring script
2. Configure Prometheus to scrape validator metrics
3. Set up a Grafana dashboard for visualization
4. Create a systemd service for continuous monitoring

## Components

### Monitoring Script

The `validator_performance_monitor.sh` script:

- Collects metrics from validator clients
- Analyzes attestation and proposal effectiveness
- Generates alerts for performance issues
- Exports metrics to Prometheus format

The script automatically detects the validator client type (Lighthouse, Teku, Prysm, Nimbus, or Lodestar) and collects client-specific metrics.

### Systemd Service

The monitoring is run as a systemd service (`validator-performance-monitor.service`) that:

- Runs continuously in the background
- Automatically starts on system boot
- Restarts in case of failures
- Outputs logs to the system journal

### Grafana Dashboard

The validator performance dashboard includes:

- Validator overview (count, effectiveness gauges)
- Attestation performance graphs
- Block proposal performance graphs
- Effectiveness trends
- System resource usage
- Network traffic

## Key Metrics

The monitoring system tracks the following key metrics:

1. **Attestation Effectiveness**: Percentage of successful attestations
   - Hits: Number of successful attestations
   - Misses: Number of missed attestations
   - Rate: Success rate (0-1)

2. **Block Proposal Effectiveness**: Percentage of successful block proposals
   - Hits: Number of successful proposals
   - Misses: Number of missed proposals
   - Rate: Success rate (0-1)

3. **System Resources**:
   - CPU usage
   - Memory usage
   - Network traffic

## Alerts

The system generates alerts for the following conditions:

- **Warning Alert**: Attestation effectiveness below 95%
- **Critical Alert**: Attestation effectiveness below 90%
- **Warning Alert**: Block proposal effectiveness below 95%
- **Critical Alert**: Block proposal effectiveness below 90%

Alerts are:
- Logged to `/root/ephemery/logs/validator_alerts.log`
- Displayed on the Grafana dashboard
- Tracked as metrics in Prometheus

## Accessing the Dashboard

Access the validator performance dashboard at:

```
http://<YOUR_SERVER_IP>:3000/d/validator-performance
```

Default credentials are:
- Username: admin
- Password: admin

## Viewing Raw Metrics

Raw metrics are stored in JSON format at:

```
/root/ephemery/data/metrics/validator_metrics.json
```

Historical metrics are stored in:

```
/root/ephemery/data/metrics/history/
```

## Prometheus Integration

Prometheus metrics are available at:

```
/root/ephemery/data/metrics/prometheus/validator_metrics.prom
```

Add the following to your `prometheus.yml` configuration (already done by the deployment playbook):

```yaml
- job_name: 'validator-performance'
  file_sd_configs:
    - files:
      - '/prometheus/validator-metrics/*.prom'
  metrics_path: /metrics
  relabel_configs:
    - source_labels: [__address__]
      target_label: instance
      replacement: 'ephemery-validator'
```

## Troubleshooting

### Service Issues

Check the service status:

```bash
systemctl status validator-performance-monitor
```

View the logs:

```bash
journalctl -u validator-performance-monitor
```

### Missing Metrics

If metrics are not appearing in Prometheus:

1. Check the metrics file exists:
   ```bash
   cat /root/ephemery/data/metrics/prometheus/validator_metrics.prom
   ```

2. Verify the Prometheus configuration:
   ```bash
   docker exec -it prometheus promtool check config /etc/prometheus/prometheus.yml
   ```

3. Restart the monitoring service:
   ```bash
   systemctl restart validator-performance-monitor
   ```

### Dashboard Issues

If the dashboard is not showing data:

1. Check Prometheus is scraping the metrics:
   ```
   http://<YOUR_SERVER_IP>:9090/targets
   ```

2. Verify the metrics exist in Prometheus:
   ```
   http://<YOUR_SERVER_IP>:9090/graph?g0.expr=ephemery_validator_count
   ```

3. Restart Grafana:
   ```bash
   docker restart grafana
   ```

## Customizing Thresholds

To customize alert thresholds, edit the script at `/root/ephemery/scripts/validator_performance_monitor.sh`:

```bash
# Alert thresholds section
local attestation_warning=0.95  # 95%
local attestation_critical=0.9  # 90%
local proposal_warning=0.95     # 95%
local proposal_critical=0.9     # 90%
```

After modifying, restart the service:

```bash
systemctl restart validator-performance-monitor
```

## Extending the System

### Adding New Metrics

To add new metrics to the monitoring system:

1. Update the `validator_performance_monitor.sh` script
2. Add the new metrics to the Prometheus export section
3. Add visualization panels to the Grafana dashboard

### Adding Notification Channels

To add notification channels for alerts:

1. Configure notification channels in Grafana (Alerting → Notification Channels)
2. Create alert rules in Grafana based on the validator metrics
3. Assign notification channels to your alert rules

## References

- [Lighthouse Metrics Documentation](https://lighthouse-book.sigmaprime.io/validator-monitoring.html)
- [Teku Metrics Documentation](https://docs.teku.consensys.net/reference/rest/#tag/Validator)
- [Prysm Metrics Documentation](https://docs.prylabs.network/docs/prysm-usage/monitoring/metrics)
- [Nimbus Metrics Documentation](https://nimbus.guide/metrics-pretty-pictures.html)
- [Lodestar Metrics Documentation](https://chainsafe.github.io/lodestar/reference/cli/)
