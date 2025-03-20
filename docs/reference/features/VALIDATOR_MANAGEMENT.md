# Validator Management

This document describes the validator management system for Ephemery nodes.

## Overview

The validator management system provides a comprehensive set of tools for managing validators in Ephemery nodes. It includes functionality for:

- Generating and importing validator keys
- Monitoring validator status and performance
- Testing validator configuration
- Managing validator backups and restores

## Validator Management Scripts

The validator management system consists of several scripts:

1. **manage-validator.sh**: Main wrapper script that provides a unified interface to all validator management functionality
2. **manage_validator_keys.sh**: Script for managing validator keys (generate, import, list, backup, restore)
3. **monitor_validator.sh**: Script for monitoring validator status and performance
4. **test_validator_config.sh**: Script for testing validator configuration
5. **integration_test.sh**: Script for testing the integration of validator management scripts with the Ephemery deployment system

## Installation

The validator management scripts are automatically installed when you deploy an Ephemery node with validator support enabled. You can also deploy them separately:

```bash
ansible-playbook playbooks/deploy_validator_management.yaml -i your-inventory.yaml
```

## Using the Validator Management System

### Main Wrapper Script

The main wrapper script (`manage-validator.sh`) provides a unified interface to all validator management functionality:

```bash
./scripts/manage-validator.sh [command] [options]
```

Available commands:
- `keys`: Manage validator keys
- `monitor`: Monitor validator status and performance
- `test`: Test validator configuration
- `help`: Show help message

### Key Management

The key management functionality allows you to generate, import, list, backup, and restore validator keys:

```bash
# Generate new validator keys
./scripts/manage-validator.sh keys generate --key-count 10 --network ephemery

# Import existing validator keys
./scripts/manage-validator.sh keys import --source /path/to/keys

# List current validator keys
./scripts/manage-validator.sh keys list

# Backup validator keys
./scripts/manage-validator.sh keys backup

# Restore validator keys from backup
./scripts/manage-validator.sh keys restore
```

For detailed information about key management options, run:

```bash
./scripts/manage-validator.sh keys --help
```

### Validator Monitoring

The validator monitoring functionality allows you to monitor validator status, performance, and health:

```bash
# Check validator status
./scripts/manage-validator.sh monitor status

# Check validator performance
./scripts/manage-validator.sh monitor performance

# Check validator health
./scripts/manage-validator.sh monitor health

# Show live dashboard
./scripts/manage-validator.sh monitor dashboard --continuous
```

For detailed information about monitoring options, run:

```bash
./scripts/manage-validator.sh monitor --help
```

### Validator Testing

The validator testing functionality allows you to test your validator configuration:

```bash
# Test validator configuration
./scripts/manage-validator.sh test
```

For detailed information about testing options, run:

```bash
./scripts/manage-validator.sh test --help
```

## Configuration

The validator management system uses the standardized configuration approach defined in `/opt/ephemery/config/ephemery_paths.conf`. This ensures consistent path definitions across all components.

Key configuration paths:

- **Validator Keys**: `/opt/ephemery/data/validator_keys`
- **Validator Logs**: `/opt/ephemery/logs/validator`
- **Validator Monitoring**: `/opt/ephemery/data/monitoring/validator`
- **Validator Scripts**: `/opt/ephemery/scripts/validator`

## Integration with Other Components

### Dashboard Integration

The validator management system integrates with both terminal-based and Grafana dashboards:

- **Terminal Dashboard**: Available via `./scripts/manage-validator.sh monitor dashboard`
- **Grafana Dashboard**: Available when monitoring is enabled

For detailed information about dashboard integration, see the [Dashboard Integration Guide](DASHBOARD_INTEGRATION.md).

### Prometheus Integration

The validator management system integrates with Prometheus for metrics collection:

- **Validator Metrics**: Exposed at `http://localhost:8009/metrics`
- **Custom Metrics**: Available for validator performance and health

For detailed information about Prometheus integration, see the [Prometheus Integration Guide](PROMETHEUS_INTEGRATION.md).

## Troubleshooting

### Common Issues

1. **Keys not loading**:
   - Check that the keys are in the correct format
   - Verify that the keys directory exists and is readable
   - Check for error messages in the validator logs

2. **Monitoring not working**:
   - Verify that the validator client is running
   - Check that the API endpoints are accessible
   - Check for error messages in the monitoring logs

3. **Dashboard not showing data**:
   - Check that the validator client is running
   - Verify that the metrics are being collected
   - Check for error messages in the dashboard logs

### Debugging Commands

```bash
# Check validator client status
docker ps | grep validator

# Check validator logs
docker logs ephemery-validator

# Check validator API
curl -s http://localhost:5052/eth/v1/node/syncing

# Check validator metrics
curl -s http://localhost:8009/metrics | head
```

## Related Documentation

- [Validator Monitoring](VALIDATOR_MONITORING.md)
- [Dashboard Integration](DASHBOARD_INTEGRATION.md)
- [Prometheus Integration](PROMETHEUS_INTEGRATION.md)
- [Validator Integration Tests](VALIDATOR_INTEGRATION_TESTS.md)
