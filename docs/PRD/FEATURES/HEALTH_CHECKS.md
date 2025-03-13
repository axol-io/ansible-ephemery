# Health Checks

This document describes the health check features implemented for Ephemery nodes, including various types of health checks, their implementation, and usage.

## Table of Contents

- [Overview](#overview)
- [Health Check Types](#health-check-types)
  - [Basic Health Checks](#basic-health-checks)
  - [Full Health Checks](#full-health-checks)
  - [Performance Checks](#performance-checks)
  - [Network Checks](#network-checks)
- [Implementation](#implementation)
  - [Design Principles](#design-principles)
  - [Script Architecture](#script-architecture)
  - [Error Handling](#error-handling)
- [Usage](#usage)
  - [Command Line Options](#command-line-options)
  - [Example Output](#example-output)
  - [Integration with Monitoring](#integration-with-monitoring)
- [Related Documentation](#related-documentation)

## Overview

The health check functionality provides operators with a comprehensive set of tools to verify the operational status of their Ephemery nodes. These checks help identify issues early, ensure optimal performance, and maintain reliable operation of both execution and consensus layer clients.

Health checks are particularly important for validator operators, as they help ensure that validators are participating effectively in consensus and proposal activities.

## Health Check Types

The health check system supports multiple types of checks, ranging from basic status verification to detailed performance analysis.

### Basic Health Checks

Basic health checks verify the fundamental aspects of node operation:

- Container status (running/stopped)
- Service availability (ports listening)
- Chain sync status (in sync/syncing)
- Disk space availability
- Service age (uptime)
- Log error analysis

These checks provide a quick overview of node health and identify obvious issues.

### Full Health Checks

Full health checks include all basic checks plus more detailed verification:

- Detailed sync status (slots, epochs behind)
- Attestation effectiveness
- Block proposal readiness
- Database integrity
- Configuration validation
- JWT authentication status
- Resource allocation validation
- Log analysis for warnings and errors

Full health checks are comprehensive and can identify subtle issues that may affect node performance.

### Performance Checks

Performance checks focus on resource utilization and operational efficiency:

- CPU utilization (overall and per container)
- Memory usage and allocation
- Disk I/O performance and bottlenecks
- Network bandwidth utilization
- Response time measurements for RPC endpoints
- Peer count and peer quality
- Block processing time
- Attestation processing time

These checks help optimize node performance and identify resource constraints.

### Network Checks

Network checks focus on connectivity and peer relationships:

- Peer count verification
- Peer distribution analysis
- Network traffic analysis
- Discovery protocol status
- NAT traversal verification
- Bandwidth utilization
- Gossip propagation timing
- Connectivity to critical services

Network checks help ensure that the node is well-connected and can effectively communicate with the network.

## Implementation

The health check functionality is implemented in the `health_check_ephemery.sh` script with a modular, extensible design.

### Design Principles

The health check implementation follows these design principles:

1. **Progressive Detail**: Provides information at increasing levels of detail based on user needs
2. **Non-Invasive**: Checks don't interfere with normal node operation
3. **Comprehensive Coverage**: Spans both execution and consensus layers
4. **Actionable Results**: Provides clear guidance for addressing identified issues
5. **Extensibility**: Designed to easily incorporate new types of checks
6. **Efficiency**: Minimizes resource usage during checks

### Script Architecture

The script is organized into modular functions for each type of check:

- Core utility functions for common operations
- Container status verification functions
- Sync status verification functions
- Resource verification functions
- Network verification functions
- Performance measurement functions
- Result formatting and reporting functions

This modular design allows for easy maintenance and extension.

### Error Handling

The health check script includes robust error handling:

- Graceful degradation when certain checks can't be performed
- Clear error messages with suggestion actions
- Non-zero exit codes for failed checks (for integration with monitoring systems)
- Warning levels for issues that are concerning but not critical
- Filtering of known and harmless errors

## Usage

The health check script is designed to be easy to use with sensible defaults but flexible configuration options.

### Command Line Options

```bash
./health_check_ephemery.sh [options]

Options:
  -b, --basic         Run basic health checks (default)
  -f, --full          Run comprehensive health checks
  -p, --performance   Run performance checks
  -n, --network       Run network checks
  --base-dir PATH     Specify a custom base directory
  -h, --help          Show this help message
```

### Example Output

Basic health check output includes status indicators and essential metrics:

```
===== Ephemery Node Health Check =====
Status: ✅ Healthy

Container Status:
  ✅ ephemery-geth: Running (Uptime: 3d 2h 15m)
  ✅ ephemery-lighthouse: Running (Uptime: 3d 2h 10m)
  ✅ ephemery-validator: Running (Uptime: 3d 2h 5m)

Sync Status:
  ✅ Execution client: Synced (Block: 12345678)
  ✅ Consensus client: Synced (Slot: 456789, Epoch: 14274)

Resources:
  ✅ Disk space: 234.5 GB available
  ✅ Memory usage: 4.2 GB / 16.0 GB (26%)
  ✅ CPU usage: 15%

Validator Status:
  ✅ Active validators: 10
  ✅ Recent attestations: 100%
  ✅ Recent proposals: 1/1 (100%)
```

Full health check output includes more detailed information and additional checks.

### Integration with Monitoring

The health check script can be integrated with monitoring systems:

- Scheduled execution via cron jobs
- Integration with Prometheus using the textfile collector
- Alerting based on exit codes
- Custom metrics export

## Related Documentation

- [Monitoring](./MONITORING.md)
- [Validator Performance Monitoring](./VALIDATOR_PERFORMANCE_MONITORING.md)
- [Troubleshooting](../DEVELOPMENT/TROUBLESHOOTING.md)
- [Operations Guide](../OPERATIONS/OPERATIONS_GUIDE.md)
