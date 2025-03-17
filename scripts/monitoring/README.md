# Monitoring Scripts

This directory contains scripts for monitoring Ephemery nodes and validators.

## Available Scripts

### Node Monitoring
- `monitor_logs.sh` - Monitor logs from Geth and Lighthouse clients
- `diagnose_output.sh` - Analyze and diagnose node output for issues
- `filter_ansible_output.sh` - Filter and format Ansible deployment output

### Validator Monitoring
- `demo_validator_monitoring.sh` - Demonstrates validator monitoring capabilities
- `ephemery_dashboard.sh` - Provides a comprehensive monitoring dashboard
- `ephemery_output.sh` - Formats and displays validator output

### Analysis Tools
- `analyze_ansible_output.sh` - Analyzes Ansible deployment logs for issues
- `monitor_logs.sh` - Advanced log monitoring and analysis

## Usage

Most monitoring scripts support these common options:
- `-h, --help` - Display help information
- `-v, --verbose` - Enable verbose output
- `-f, --follow` - Follow log output in real-time
- `-n, --lines N` - Show last N lines of output

## Features

- Real-time log monitoring
- Performance metrics collection
- Error detection and diagnosis
- Custom filtering and formatting
- Dashboard integration
- Alert generation for critical issues

## Best Practices

1. Regularly check monitoring output
2. Set up alerts for critical issues
3. Keep logs for troubleshooting
4. Monitor system resource usage
5. Review performance metrics periodically

For detailed usage instructions, refer to the main [README.md](../../README.md) or run each script with the `--help` flag.
