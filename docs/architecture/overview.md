# Ephemery Architecture Overview

## Introduction

Ephemery is a project designed to simplify the deployment and management of Ethereum nodes using Ansible. This document provides a high-level overview of the system architecture.

## System Architecture

The Ephemery system consists of the following key components:

1. **Ansible Roles**: Modular components that handle specific aspects of node deployment and configuration
2. **Playbooks**: Orchestration scripts that apply roles to hosts
3. **Templates**: Configuration templates for various clients and tools
4. **Scripts**: Utilities for maintenance, monitoring, and troubleshooting

### Architecture Diagram

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

## Role-Based Architecture

The system follows a role-based architecture with three main roles:

### Common Role

The Common role handles base configuration for all nodes, including:

- System configuration
- User management
- Firewall setup
- JWT secret management
- Common dependencies

### Execution Client Role

The Execution Client role handles the deployment and configuration of Ethereum execution clients, including:

- Geth
- Nethermind
- Besu

### Consensus Client Role

The Consensus Client role handles the deployment and configuration of Ethereum consensus clients, including:

- Lighthouse
- Prysm
- Teku

## Workflow

1. **Inventory Definition**: Define target hosts and their configurations
2. **Playbook Selection**: Choose the appropriate playbook for the deployment
3. **Role Application**: The playbook applies roles to the target hosts
4. **Client Configuration**: Clients are configured based on variables and templates
5. **Validation**: Deployment is validated using monitoring scripts

## Data Flow

1. **Configuration Variables**: Flow from inventory files, role defaults, and command-line parameters
2. **Template Rendering**: Variables are used to render configuration templates
3. **Client Installation**: Clients are installed on target hosts
4. **Client Operation**: Clients operate and communicate with each other
5. **Monitoring**: Monitoring scripts collect and report on client status

## Security Considerations

- JWT secrets are managed securely with appropriate permissions
- Firewall rules are applied to restrict access
- Sensitive data is handled using Ansible Vault
- Ports are configured with minimal exposure
- Secure communications between clients

## Future Enhancements

1. Add support for additional client types
2. Implement role-based monitoring
3. Add comprehensive testing framework
4. Create specialized roles for validators and MEV-boost 