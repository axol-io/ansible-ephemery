# Monitoring Ephemery Nodes

This document provides information about the monitoring setup for Ephemery nodes, including Prometheus, Grafana, and metrics collection from Ethereum clients.

## Overview

The monitoring stack consists of:

- **Prometheus**: Time-series database for metrics collection
- **Grafana**: Visualization and dashboarding
- **Node Exporter**: System metrics collection
- **cAdvisor**: Container metrics collection
- **Grafana Agent**: Metrics forwarding (optional)

## Enabling Monitoring

Monitoring is disabled by default. To enable it, set the following in your host variables:

```yaml
monitoring_enabled: true
```

## Metrics Configuration

### Execution Clients

The following execution clients expose metrics on these default ports:

| Client     | Metrics Port | Metrics Path           |
|------------|--------------|------------------------|
| Geth       | 6060         | /debug/metrics/prometheus |
| Nethermind | 9091         | /metrics              |
| Besu       | 9545         | /metrics              |
| Erigon     | 6060         | /debug/metrics/prometheus |
| Reth       | 9090         | /metrics              |

### Consensus Clients

The following consensus clients expose metrics on these default ports:

| Client     | Metrics Port | Metrics Path           |
|------------|--------------|------------------------|
| Lighthouse | 5054         | /metrics              |
| Prysm      | 8080         | /metrics              |
| Teku       | 8008         | /metrics              |
| Lodestar   | 8008         | /metrics              |

## Prometheus Configuration

Prometheus is configured to scrape metrics from all enabled clients. The configuration is generated from the template `templates/prometheus.yaml.j2`.

Key configuration options:

```yaml
# In defaults/main.yaml or host_vars
prometheus_port: 17690
```

## Grafana Configuration

Grafana is configured with pre-built dashboards for Ethereum clients and system metrics.

Key configuration options:

```yaml
# In defaults/main.yaml or host_vars
grafana_port: 3000
```

## Automatic Reset and Monitoring

When automatic reset is enabled, the monitoring services are restarted after each reset to ensure continuous monitoring:

```yaml
# In defaults/main.yaml or host_vars
ephemery_automatic_reset: true
ephemery_reset_frequency: "0 0 * * *"  # Cron format (midnight daily)
```

## Troubleshooting

### Common Issues

1. **Metrics not appearing in Prometheus**:
   - Check that the client is running and exposing metrics
   - Verify the metrics port is correct in the configuration
   - Check Prometheus targets page at `http://<node-ip>:17690/targets`

2. **Grafana not showing data**:
   - Verify Prometheus is running and collecting data
   - Check Grafana data source configuration

3. **Missing client metrics**:
   - Ensure the client is configured to expose metrics
   - Check that the metrics port is not blocked by firewall

## Advanced Configuration

### Custom Prometheus Configuration

To customize the Prometheus configuration beyond the defaults, you can modify the `templates/prometheus.yaml.j2` template.

### Custom Grafana Dashboards

Custom Grafana dashboards can be added by placing JSON dashboard files in the `files/grafana/dashboards/` directory.

## References

- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Ethereum Client Metrics Documentation](https://ethereum.org/en/developers/docs/nodes-and-clients/)
- [Sync Monitoring Documentation](SYNC_MONITORING.md) - Detailed information about our synchronization monitoring system
