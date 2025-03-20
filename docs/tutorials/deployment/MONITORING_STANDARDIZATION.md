# Monitoring Standardization

This document details the standardization of monitoring configurations in the Ephemery Node system, with a focus on Prometheus metrics collection and dashboard integration.

## Overview

Monitoring is critical for the successful operation of Ephemery nodes. The standardization of monitoring configurations ensures consistent metrics collection, alerting, and dashboard visualization across all deployments.

## Prometheus Configuration Standardization

### Standardized Prometheus Configuration

We've standardized the Prometheus configuration file (`prometheus.yaml`) to ensure consistent monitoring across all environments:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "lighthouse"
    metrics_path: /metrics
    static_configs:
      - targets: ["ephemery-lighthouse:5054"]
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: "lighthouse"

  - job_name: "geth"
    metrics_path: /debug/metrics/prometheus
    static_configs:
      - targets: ["ephemery-geth:6060"]
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: "geth"

  - job_name: "node_exporter"
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: "validator-metrics"
    metrics_path: /metrics
    static_configs:
      - targets: ["localhost:8009"]
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: "validator"
```

### Key Standardization Elements

1. **Consistent Job Names**: Standardized job names (`prometheus`, `lighthouse`, `geth`, `node_exporter`, `validator-metrics`) for easier dashboard integration.

2. **Consistent Target Definitions**: Standardized target definitions with proper container names and ports.

3. **Consistent Relabeling**: Added consistent relabeling configurations to ensure metrics are properly labeled.

4. **Consistent Intervals**: Standardized scrape and evaluation intervals (15s).

5. **File Extension Standardization**: Standardized on `.yaml` extension for configuration files.

## Dashboard Integration

The standardized Prometheus configuration ensures proper integration with Grafana dashboards:

1. **Standard Dashboard Variables**: Dashboard variables now match the standardized job names and labels.

2. **Consistent Metric Names**: Metric names are consistently formatted across all dashboards.

3. **Dashboard Templating**: Dashboard templates have been updated to work with the standardized configuration.

## Validator Metrics Standardization

Validator performance metrics have been standardized to ensure consistent monitoring:

1. **Standard Metric Paths**: Standardized metric paths for validator metrics.

2. **Standard Labels**: Standardized labels for validator metrics.

3. **Consistent Collection Intervals**: Standardized collection intervals for validator metrics.

## Node Exporter Integration

System metrics collection through Node Exporter has been standardized:

1. **Standard Container Name**: The Node Exporter container is consistently named `node-exporter`.

2. **Standard Port**: Node Exporter consistently uses port 9100.

3. **Standard Metrics Collection**: Standard set of system metrics are collected.

## Container Metrics Standardization

Docker container metrics collection has been standardized:

1. **Standard Job Configuration**: Consistent job configuration for container metrics.

2. **Standard Label Structure**: Standardized label structure for container metrics.

## Alert Configuration

Alert rules have been standardized across all monitoring configurations:

1. **Standard Alert Rules**: Consistent alert rules for common issues.

2. **Standard Thresholds**: Standardized thresholds for alerts.

3. **Standard Notification Channels**: Standardized notification channel configuration.

## Implementation Details

### Prometheus Configuration Deployment

The standardized Prometheus configuration is deployed through Ansible:

```yaml
- name: Copy Prometheus configuration
  copy:
    content: |
      global:
        scrape_interval: 15s
        evaluation_interval: 15s

      scrape_configs:
        # ... standardized configuration ...
    dest: "{{ prometheus_config_dir }}/prometheus.yaml"
    mode: '0644'
```

### Dashboard Container Integration

The dashboard Docker Compose file has been updated to use the standardized Prometheus configuration:

```yaml
prometheus:
  image: prom/prometheus:latest
  ports:
    - "9090:9090"
  volumes:
    - ./prometheus.yaml:/etc/prometheus/prometheus.yaml
    - prometheus_data:/prometheus
  command:
    - --config.file=/etc/prometheus/prometheus.yaml
```

## Benefits of Standardization

The monitoring standardization provides several key benefits:

1. **Consistent Metrics Collection**: Ensures all nodes collect the same metrics in the same format.

2. **Dashboard Compatibility**: Guarantees that dashboards work correctly across all deployments.

3. **Simplified Troubleshooting**: Standardized monitoring makes troubleshooting easier.

4. **Easier Maintenance**: Simplified maintenance with standardized configurations.

5. **Better Alerting**: Consistent alert rules across all deployments.

## Validation and Testing

The standardized monitoring configuration has been tested in the following scenarios:

1. **Fresh Installation**: Verified that new installations correctly use the standardized monitoring.

2. **Upgrades**: Tested the compatibility with existing monitoring configurations.

3. **Dashboard Integration**: Verified that dashboards correctly integrate with the standardized metrics.

4. **Alert Testing**: Tested the standardized alert rules.

## Future Enhancements

Planned enhancements to the monitoring standardization include:

1. **Enhanced Validator Metrics**: More detailed validator performance metrics.

2. **Network Metrics**: Enhanced network performance monitoring.

3. **Custom Ephemery-Specific Metrics**: Ephemery-specific metrics for network reset monitoring.

4. **Advanced Alert Correlation**: Correlation of alerts across different components.

5. **ML-Based Anomaly Detection**: Machine learning-based anomaly detection for Ephemery nodes.

## Related Documents

- [Configuration Standardization](./CONFIGURATION_STANDARDIZATION.md)
- [Dashboard Implementation](../FEATURES/DASHBOARD_IMPLEMENTATION.md)
- [Validator Performance Monitoring](../FEATURES/VALIDATOR_PERFORMANCE_MONITORING.md)
