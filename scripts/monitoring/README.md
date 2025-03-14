# Monitoring Scripts

Advanced monitoring and alerting scripts for validator performance.

## System Components

The Advanced Validator Performance Monitoring system consists of several key components:

1. **Validator Alerts System** (`validator_alerts_system.sh`): 
   - Provides real-time alerting for validator performance issues
   - Monitors attestations, proposals, inclusion distance, and balance
   - Configurable thresholds and notification channels

2. **Predictive Analytics System** (`validator_predictive_analytics.sh`):
   - Analyzes historical performance data to identify trends
   - Forecasts future validator performance
   - Provides optimization recommendations

3. **External Integration** (`validator_external_integration.sh`):
   - Connects to external monitoring systems
   - Provides webhooks and API endpoints
   - Exports metrics in various formats

4. **Dashboard** (`validator_dashboard.sh`):
   - Displays validator performance metrics
   - Shows alerts history and analytics
   - Provides a unified view of the monitoring system

## Installation

1. Ensure you have all dependencies installed:
   ```
   sudo apt-get update
   sudo apt-get install -y jq bc curl
   ```

2. Create the necessary directories:
   ```
   sudo mkdir -p /var/lib/validator/data
   sudo mkdir -p /var/lib/validator/metrics
   sudo mkdir -p /etc/validator
   ```

3. Copy the sample configuration:
   ```
   cp config/alerts_config.sample.json /etc/validator/alerts_config.json
   cp config/predictive_analytics.sample.json /etc/validator/predictive_analytics.json
   ```

## Usage

### Validator Alerts System

```bash
./validator_alerts_system.sh --config-file /etc/validator/alerts_config.json
```

Testing alerts:

```bash
./validator_alerts_system.sh --config-file /etc/validator/alerts_config.json --test-mode \
  --test-data '{"missed_attestations": 3}' --alert-type missed_attestation
```

### Predictive Analytics

```bash
./validator_predictive_analytics.sh --config-file /etc/validator/predictive_analytics.json \
  --output json --output-file /var/lib/validator/analytics_results.json
```

### Generate Test Data

To generate test data for development and testing:

```bash
./generate_test_data.sh --validators 5 --days 60
```

## Configuration

### Alerts Configuration

The alerts configuration file defines thresholds for various alert conditions and notification methods. See `config/README.md` for details.

### Predictive Analytics Configuration

The predictive analytics configuration defines analysis parameters, forecast settings, and recommendation types. See `config/README.md` for details.

## Scripts

- `advanced_validator_monitoring.sh`: Main monitoring script that orchestrates all components
- `validator_alerts_system.sh`: Real-time alerting system
- `validator_predictive_analytics.sh`: Historical data analysis and forecasting
- `validator_external_integration.sh`: Integration with external systems
- `validator_dashboard.sh`: Performance visualization dashboard
- `generate_test_data.sh`: Creates test data for development and testing
- `check_ephemery_status.sh`: Checks Ephemery network status
- `check_sync_status.sh`: Verifies node synchronization
- `run_validator_monitoring.sh`: Simple wrapper to run monitoring tasks
- `checkpoint_sync_alert.sh`: Alerts for checkpoint synchronization issues
- `fix_checkpoint_sync.sh`: Fixes common checkpoint sync problems

## Integration

The monitoring system can be integrated with:

- Prometheus/Grafana for metrics visualization
- Email/SMS/Slack for notifications
- External monitoring services
- Custom dashboards and reporting tools

Please refer to the individual script comments or `validator_external_integration.sh` for integration details.
