---
id: validator_status_dashboard
title: Validator Status Dashboard
sidebar_label: Validator Status Dashboard
description: A comprehensive dashboard for monitoring validator performance, diagnosing issues, and optimizing validator operations
keywords:
  - validator
  - dashboard
  - monitoring
  - performance
---

# Enhanced Validator Status Dashboard

## Overview

This document outlines the implemented enhancements to the validator status dashboard in the Ansible Ephemery project. The dashboard provides a comprehensive and user-friendly interface for monitoring validator performance, diagnosing issues, and optimizing validator operations.

## Implementation Status

The Enhanced Validator Status Dashboard has been implemented with the following features:

### Implemented Features

1. **Performance Visualization**
   - Status summary cards for at-a-glance metrics
   - Real-time attestation and proposal monitoring
   - Balance tracking with trend analysis
   - Performance distribution visualization

2. **Historical Data Analysis**
   - Balance history chart with 30-day trend
   - Attestation effectiveness over time
   - Performance stability metrics
   - Validator group comparisons

3. **Alert System**
   - Low attestation rate alerts
   - Balance deviation warnings
   - Configurable alert thresholds
   - Detailed alert history

4. **Validator Table View**
   - Sortable and filterable validator list
   - Individual validator status indicators
   - Quick action buttons for each validator
   - Search functionality for large validator sets

### Dashboard Components

The validator dashboard consists of several key components:

1. **Web Dashboard UI**
   - A modern responsive HTML/CSS/JavaScript interface
   - Real-time data visualization with Chart.js
   - Mobile-optimized view for monitoring on any device
   - Theme-based styling with accessibility considerations

2. **Backend API Server**
   - RESTful API for validator metrics data
   - Data caching for performance optimization
   - Integration with Lighthouse and Beacon APIs
   - Historical data persistence

3. **Metrics Collection**
   - Integration with the advanced validator monitoring script
   - Automatic metrics collection and storage
   - Performance trend analysis
   - Alert generation based on configurable thresholds

4. **Nginx Server Configuration**
   - Reverse proxy for API endpoints
   - Static file serving for dashboard assets
   - Cache control for performance optimization
   - Health check endpoints for monitoring

## Technical Implementation

### API Endpoints

The dashboard API provides the following endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/metrics` | GET | Get current validator metrics |
| `/api/history` | GET | Get historical validator metrics |
| `/api/alerts` | GET | Get recent validator alerts |
| `/api/run_check` | POST | Run a validator performance check |
| `/api/validators/live` | GET | Get live validator data from clients |
| `/api/status` | GET | Get API status information |
| `/health` | GET | Health check endpoint |

### Dashboard Features

The dashboard UI provides the following main features:

1. **Summary Metrics**
   - Active validators count with trend
   - Attestation effectiveness rate
   - Average validator balance
   - Recent proposal statistics

2. **Performance Charts**
   - Balance history line chart
   - Attestation performance bar chart
   - Real-time updates with auto-refresh

3. **Validator Table**
   - Complete validator list with status indicators
   - Key metrics for each validator
   - Search functionality for filtering
   - One-click access to detailed validator information

4. **Alert Panel**
   - Recently triggered alerts
   - Alert severity indication
   - Timestamp and detailed message
   - Auto-updating alerts list

5. **Action Buttons**
   - Manual refresh capability
   - Performance check trigger
   - Report export functionality
   - Settings configuration

### Deployment

The dashboard is deployed using Ansible with the following steps:

1. **Prerequisites Installation**
   - Python packages (Flask, Flask-CORS, Requests)
   - Nginx web server
   - System dependencies

2. **File Deployment**
   - Dashboard HTML interface
   - API backend script
   - Systemd service configuration
   - Nginx site configuration

3. **Service Configuration**
   - Systemd service setup
   - Automatic startup configuration
   - Logging setup

4. **Access Configuration**
   - URL path setup
   - Proxy configuration
   - Cache control settings

## Usage

### Accessing the Dashboard

The validator dashboard can be accessed at:

```
http://YOUR_SERVER_IP/validator-dashboard/
```

The API endpoints can be accessed at:

```
http://YOUR_SERVER_IP/validator-api/
```

### Interpreting the Dashboard

1. **Status Cards**
   - Green indicators show healthy metrics
   - Yellow indicators show warning conditions
   - Red indicators show critical issues
   - Trend arrows indicate performance direction

2. **Performance Charts**
   - Upward trends in balance indicate positive rewards
   - Attestation rates should remain above 95% for optimal performance
   - Sudden drops may indicate network or client issues

3. **Alerts**
   - Warning alerts (yellow) indicate potential issues
   - Critical alerts (red) require immediate attention
   - Informational alerts (blue) provide context

### Running a Performance Check

To manually run a validator performance check:

1. Click the "Run Performance Check" button
2. Wait for the check to complete
3. Review the updated metrics and alerts
4. Take action based on recommendations

## Customization

### Configurable Options

The dashboard can be customized through the following methods:

1. **Environment Variables**
   - `BEACON_NODE_ENDPOINT`: URL of the beacon node API
   - `VALIDATOR_ENDPOINT`: URL of the validator client API
   - `EPHEMERY_BASE_DIR`: Base directory for Ephemery installation

2. **Configuration File**
   - Alert thresholds
   - Refresh interval
   - Data retention settings
   - UI customization options

### Adding Custom Metrics

To add custom metrics to the dashboard:

1. Modify the advanced validator monitoring script to collect additional metrics
2. Update the API to expose the new metrics
3. Add visualization components to the dashboard UI

## Future Enhancements

The roadmap for future enhancements includes:

1. **Advanced Analytics**
   - Machine learning-based anomaly detection
   - Predictive performance forecasting
   - Comparative network analysis

2. **Enhanced Visualization**
   - 3D visualization of validator performance
   - Interactive exploration tools
   - Custom dashboard layouts

3. **Advanced Notification System**
   - SMS and email alert integration
   - Mobile push notifications
   - Webhook support for external systems

4. **Performance Optimization**
   - Recommendation engine for validator settings
   - Automated performance tuning
   - Enhanced troubleshooting tools

## Deployment Instructions

To deploy the validator dashboard:

```bash
ansible-playbook -i inventory.yaml ansible/playbooks/deploy_validator_dashboard.yaml
```

## Related Documentation

- [Validator Performance Monitoring](./VALIDATOR_PERFORMANCE_MONITORING.md)
- [Checkpoint Sync Dashboard](./CHECKPOINT_SYNC_DASHBOARD.md)
- [Advanced Validator Configuration](../OPERATIONS/ADVANCED_VALIDATOR_CONFIGURATION.md)
- [Monitoring](./MONITORING.md)
