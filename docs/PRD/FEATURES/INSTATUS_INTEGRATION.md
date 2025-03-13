---
id: instatus_integration
title: Instatus Integration
sidebar_label: Instatus Integration
description: Integration with Instatus for external status monitoring of Ephemery infrastructure
keywords:
  - instatus
  - monitoring
  - status page
  - infrastructure
---

# Instatus Integration for External Status Monitoring

## Overview

This document outlines the planned integration with Instatus to provide a public-facing status page for monitoring the health and performance of the Ansible Ephemery infrastructure. The integration will enable automatic updates to an external status page based on internal monitoring metrics, allowing users to monitor service status without requiring access to the internal systems.

## Key Features

### Automated Status Reporting

- **Real-time Service Status Updates**: Automatically update component status on Instatus based on internal monitoring metrics
- **Incident Management**: Automatically create, update, and resolve incidents based on detected issues
- **Component Mapping**: Map internal services to public-facing components with appropriate abstraction
- **Scheduled Status Checks**: Perform regular health checks and report status at configurable intervals

### Customized Status Page

- **Branded Interface**: Create a custom-branded status page with organization logo and theme
- **Component Hierarchy**: Organize components in a logical hierarchy with parent-child relationships
- **Historical Uptime Display**: Show historical uptime statistics for all monitored components
- **Custom Domain**: Configure a custom domain for the status page (e.g., status.ephemery.xyz)

### Integration with Existing Monitoring

- **Prometheus Alert Integration**: Connect Prometheus alerts to automatically update Instatus component status
- **Grafana Dashboard Integration**: Link Grafana dashboards for detailed metrics behind status indicators
- **Threshold-Based Status**: Define thresholds for determining component status (operational, degraded, outage)

### Notification System

- **Email Subscriptions**: Allow users to subscribe to status updates via email
- **SMS Notifications**: Enable SMS notifications for critical status changes
- **Webhook Integration**: Trigger external systems via webhooks when status changes occur
- **Scheduled Maintenance Announcements**: Publish upcoming maintenance windows with impact assessment

## Implementation Plan

### Phase 1: Basic Integration

1. **API Client Development**
   - Create a Python-based API client for Instatus
   - Implement authentication and authorization
   - Test basic API operations (status updates, incident creation)

2. **Component Mapping**
   - Define component structure in Instatus
   - Create mapping between internal services and public components
   - Implement status translation logic (internal metrics to Instatus status)

3. **Initial Automation**
   - Create basic cron job for status updates
   - Implement simple threshold-based status determination
   - Set up initial incident creation for critical issues

### Phase 2: Enhanced Features

1. **Advanced Metrics Integration**
   - Connect Prometheus alerts to Instatus updates
   - Implement metric aggregation for status determination
   - Create custom metrics display on the status page

2. **Notification System**
   - Set up email subscription system
   - Configure SMS notifications for critical components
   - Implement webhook triggers for external integrations

3. **UI Customization**
   - Configure branded interface with custom colors and logo
   - Set up custom domain for status page
   - Create component hierarchy with logical grouping

### Phase 3: Complete Integration

1. **Incident Management Workflow**
   - Implement detailed incident creation with automatic updates
   - Create templated communication for different incident types
   - Add incident history and resolution tracking

2. **Advanced Analytics**
   - Implement historical uptime tracking and reporting
   - Create SLA compliance monitoring
   - Generate periodic status reports for stakeholders

3. **Maintenance Management**
   - Create scheduled maintenance announcement system
   - Implement impact assessment for planned maintenance
   - Add maintenance calendar integration

## Technical Details

### API Integration

Instatus provides a RESTful API that allows programmatic updates to the status page. The integration will use this API to:

- Update component status
- Create and manage incidents
- Configure scheduled maintenance
- Retrieve historical data

Example API endpoint for updating component status:

```
PUT https://api.instatus.com/v1/{page_id}/components/{component_id}
```

Example payload:

```json
{
  "status": "degraded",
  "name": "Validator Client",
  "description": "Performance degradation detected"
}
```

### Component Structure

The following components will be tracked on the status page:

1. **Ethereum Services**
   - Execution Client
   - Consensus Client
   - Validator Client
   - Checkpoint Sync Service

2. **Monitoring Systems**
   - Prometheus
   - Grafana
   - Alert Manager

3. **Infrastructure**
   - Network
   - Storage
   - Server Health

### Status Determination Logic

Status will be determined based on the following metrics:

- **Operational**: All metrics within normal thresholds
- **Degraded**: Performance metrics indicating slowdown but service still functional
- **Partial Outage**: Some functionality impaired but service still partially available
- **Major Outage**: Service completely unavailable or non-functional

Specific thresholds will be defined for each component based on service-specific metrics.

## Resources

- [Instatus API Documentation](https://instatus.com/help/api)
- [Instatus Webhooks Documentation](https://instatus.com/help/webhooks)
- [Prometheus Alert Manager Integration](https://prometheus.io/docs/alerting/latest/configuration/)

## Implementation Timeline

- **Phase 1**: Q2 2024
- **Phase 2**: Q3 2024
- **Phase 3**: Q4 2024

## Related Topics

- [Monitoring](./MONITORING.md)
- [Validator Status Dashboard](./VALIDATOR_STATUS_DASHBOARD.md)
- [Checkpoint Sync Dashboard](./CHECKPOINT_SYNC_DASHBOARD.md) 