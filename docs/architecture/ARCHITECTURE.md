# Ephemery Node Architecture

This document provides a comprehensive overview of the Ephemery Node architecture, its components, modules, and how they interact.

## Introduction

Ephemery is an Ethereum testnet that restarts weekly, providing a clean environment for testing and development. The project is designed to simplify the deployment and management of Ethereum nodes using Ansible.

## System Overview

The architecture consists of several key components:

1. **Execution Client**: Processes transactions and manages state (Geth, Nethermind, Besu, etc.)
2. **Consensus Client**: Handles consensus mechanism and block finalization (Lighthouse, Prysm, Teku, etc.)
3. **Validator Client** (optional): Participates in block validation and proposal
4. **Monitoring Stack**: Tracks node performance and health
5. **Ephemery Reset Mechanism**: Handles weekly network resets
6. **Ansible Controller**: Manages deployment and configuration
7. **Target Nodes**: Hosts running the Ethereum clients

## High-Level Architecture Diagram

```
┌─────────────────────┐     ┌──────────────────┐
│                     │     │                  │
│  Ansible Controller │────▶│  Target Nodes    │
│                     │     │                  │
└─────────────────────┘     └──────────────────┘
          │                           ▲
          │                           │
          ▼                           │
┌─────────────────────┐               │
│                     │               │
│  Playbooks          │───────────────┘
│                     │
└─────────────────────┘
          │
          │
          ▼
┌─────────────────────────────────────────────┐
│                                             │
│                   Roles                     │
│                                             │
├─────────────┬─────────────┬─────────────┐   │
│             │             │             │   │
│   Common    │  Execution  │  Consensus  │   │
│             │   Client    │   Client    │   │
│             │             │             │   │
└─────────────┴─────────────┴─────────────┘   │
│                                             │
└─────────────────────────────────────────────┘
```

## Node Architecture Diagram

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

## Component Architecture

### Role-Based Components

1. **Common Role**
   - System configuration
   - User management
   - Firewall setup
   - JWT secret management
   - Common dependencies

2. **Execution Client Role**
   - Geth deployment and configuration
   - Nethermind deployment and configuration
   - Besu deployment and configuration

3. **Consensus Client Role**
   - Lighthouse deployment and configuration
   - Prysm deployment and configuration
   - Teku deployment and configuration

### Component Interactions

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

## Module Organization

The codebase follows a modular organization approach that separates concerns and promotes reusability:

1. **Core Modules**
   - Essential functionality required by all components
   - Base configuration and utilities
   - Common interfaces and types

2. **Client Modules**
   - Client-specific implementation
   - Configuration templates
   - Client management scripts

3. **Validator Modules**
   - Validator key management
   - Validator configuration
   - Validator monitoring

4. **Monitoring Modules**
   - Metrics collection
   - Alert configuration
   - Dashboard templates

5. **Deployment Modules**
   - Ansible playbooks
   - Role definitions
   - Inventory management

6. **Utility Modules**
   - Helper functions
   - Common utilities
   - Shared libraries

## Data Flow

1. **Configuration Flow**:
   - Variables flow from inventory files, role defaults, and command-line parameters
   - Templates are rendered using configuration variables
   - Configurations are applied to clients

2. **Block Synchronization**:
   - Consensus client receives block headers from peers
   - Execution client receives block bodies and state data
   - Both clients validate and process data

3. **Validator Operations** (if running validator):
   - Consensus client notifies validator of duties
   - Validator creates attestations and block proposals
   - Proposals and attestations are broadcast to network

4. **Reset Process**:
   - Reset detection via API polling
   - Service shutdown sequence
   - Data directory cleanup
   - New genesis state application
   - Service restart sequence

## Security Considerations

1. **Access Control**
   - JWT secrets are managed securely with appropriate permissions
   - Firewall rules restrict access to necessary ports
   - Role-based access control for different components

2. **Data Security**
   - Sensitive data handled using Ansible Vault
   - Secure storage of validator keys
   - Encrypted communication between components

3. **Network Security**
   - Minimal port exposure
   - Secure client communication
   - Protected API endpoints

## Future Enhancements

1. **Client Support**
   - Add support for additional execution clients
   - Add support for additional consensus clients
   - Implement specialized validator configurations

2. **Monitoring**
   - Implement role-based monitoring
   - Enhanced metrics collection
   - Advanced alerting capabilities

3. **Testing**
   - Comprehensive testing framework
   - Automated integration tests
   - Performance benchmarking

4. **MEV Support**
   - MEV-boost integration
   - MEV monitoring
   - MEV-related metrics

## Related Documentation

- [Repository Structure](./REPOSITORY_STRUCTURE.md)
- [System Architecture Details](./system_architecture.md)
- [Deployment Guide](../playbooks/deploy_ephemery.md)
- [Monitoring Guide](../reference/managing_ansible_output.md)
