# Ephemery Node Architecture

This document provides a high-level overview of the Ephemery Node architecture, its components, and how they interact.

## System Overview

Ephemery is an Ethereum testnet that restarts weekly, providing a clean environment for testing and development. The architecture consists of several key components:

1. **Execution Client**: Processes transactions and manages state (Geth, Nethermind, Besu, etc.)
2. **Consensus Client**: Handles consensus mechanism and block finalization (Lighthouse, Prysm, Teku, etc.)
3. **Validator Client** (optional): Participates in block validation and proposal
4. **Monitoring Stack**: Tracks node performance and health
5. **Ephemery Reset Mechanism**: Handles weekly network resets

## Architectural Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Host System                           │
├─────────────┬─────────────┬───────────────┬────────────────┤
│             │             │               │                │
│  Execution  │  Consensus  │   Validator   │   Monitoring   │
│   Client    │   Client    │    Client     │     Stack      │
│  (Docker)   │  (Docker)   │   (Docker)    │    (Docker)    │
│             │             │               │                │
├─────────────┴─────────────┴───────────────┴────────────────┤
│                                                             │
│                    Docker Network                           │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                Ephemery Reset Mechanism                     │
│           (Cron Jobs and Detection Scripts)                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Component Interactions

1. **Execution/Consensus Communication**:
   - Execution client and consensus client communicate via Engine API
   - JSON-RPC over HTTP/WebSocket

2. **Validator Operations**:
   - Validator client connects to consensus client
   - Submits attestations and block proposals

3. **Monitoring Integration**:
   - All components expose metrics endpoints
   - Prometheus scrapes metrics
   - Grafana visualizes collected data

4. **Ephemery Reset Process**:
   - Detection script polls for network resets
   - On reset detection, stops services
   - Resets blockchain data
   - Restarts services with new genesis state

## Deployment Architecture

The deployment architecture uses Ansible to provision and configure hosts:

1. **Inventory System**: Defines hosts and their roles
2. **Playbooks**: Define deployment steps and configurations
3. **Roles**: Modular components that can be applied to hosts
4. **Templates**: Dynamic configuration files
5. **Variables**: Customizable settings

## Data Flow

1. **Block Synchronization**:
   - Consensus client receives block headers from peers
   - Execution client receives block bodies and state data
   - Both clients validate and process data

2. **Validator Operations** (if running validator):
   - Consensus client notifies validator of duties
   - Validator creates attestations and block proposals
   - Proposals and attestations are broadcast to network

3. **Reset Process**:
   - Reset detection via API polling
   - Service shutdown sequence
   - Data directory cleanup
   - New genesis state application
   - Service restart sequence

## Related Documentation

- [Component Architecture](./COMPONENT_ARCHITECTURE.md)
- [Module Organization](./MODULE_ORGANIZATION.md)
- [Deployment Architecture](../DEPLOYMENT/DEPLOYMENT.md)
- [Monitoring Architecture](../FEATURES/MONITORING.md)
