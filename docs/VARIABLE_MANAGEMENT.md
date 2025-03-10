# Variable Management System

This document explains the centralized variable management system used in the ansible-ephemery role.

## Overview

The ansible-ephemery role uses a hierarchical, modular variable system that provides:

1. **Centralized configuration** - Core variables are defined in one place
2. **Layered overrides** - Environment and host-specific values can override defaults
3. **Structured organization** - Variables are organized by function and component
4. **Reduced duplication** - Common settings are defined once and reused

## Variable Hierarchy

Variables are loaded in the following order (later definitions override earlier ones):

1. Core variables (`vars/ephemery_variables.yaml`)
2. Resource management (`vars/resource_management.yaml`)
3. Network-specific variables (`vars/networks/[network].yaml`)
4. Client-specific variables (`vars/clients/[type]/[client].yaml`)
5. Environment-specific variables (`vars/environments/[environment].yaml`)
6. Host-specific variables (`host_vars/[hostname].yaml`)

## Directory Structure

```bash
ansible/
├── vars/
│   ├── ephemery_variables.yaml    # Core variables
│   ├── resource_management.yaml   # Resource allocation settings
│   ├── clients/                   # Client-specific settings
│   │   ├── execution/
│   │   │   ├── geth.yaml
│   │   │   └── ... (other clients)
│   │   └── consensus/
│   │       ├── lighthouse.yaml
│   │       └── ... (other clients)
│   ├── networks/                  # Network-specific settings
│   │   └── ephemery.yaml
│   └── environments/              # Environment configurations
│       ├── production.yaml
│       └── development.yaml
└── vars_management.yaml           # Variable import system
```

## Resource Management

The `resource_management.yaml` file provides a comprehensive system for allocating system resources to various components of Ephemery. Key features include:

- **Dynamic allocation** - Resources are calculated based on available system resources
- **Component distribution** - Resources are distributed between execution, consensus, and validator clients
- **Minimum requirements** - Ensures components get minimum required resources
- **Service-specific allocation** - Different allocation strategies for different services

Example resource allocation:

```yaml
# System with 16GB RAM
system.memory_total: 16384  # MB

# 90% allocation to Ephemery services
allocation.memory_total_percentage: 0.9  # 90%
# Total available: 14745 MB (14.4 GB)

# Component distribution
allocation.memory_distribution:
  execution_client: 0.5     # 7372 MB (7.2 GB)
  consensus_client: 0.4     # 5898 MB (5.8 GB)
  validator_client: 0.1     # 1474 MB (1.4 GB)
```

## Client-Specific Configuration

Each supported client has its own configuration file with:

- **Common settings** - Standard options that apply to all clients
- **Specialized options** - Client-specific configuration options
- **Container settings** - Docker-specific configuration
- **Command templates** - Templates for launching client containers

## Environment-Specific Configuration

Different deployment environments can have different settings:

- **Production** - Optimized for stability, security, and reliability
- **Development** - Optimized for ease of use and development workflow
- **Testing** - Optimized for testing and validation

## Using the Variable System

To use the variable system in playbooks:

```yaml
- name: Import variables
  include_tasks: ../vars_management.yaml

# Now all variables are available
- name: Deploy execution client
  include_tasks: clients/execution_client.yaml
  vars:
    client_type: "{{ clients.execution }}"
```

## Customizing Variables

To customize variables for a specific host:

1. Create a file in `host_vars/[hostname].yaml`
2. Override any variables needed for that host

Example host-specific override:

```yaml
# host_vars/validator-node-1.yaml
features:
  validator:
    enabled: true  # Enable validator on this node

# Override resource allocation for this node
allocation:
  memory_distribution:
    execution_client: 0.4  # Less memory for execution
    consensus_client: 0.3  # Less memory for consensus
    validator_client: 0.3  # More memory for validator
```

## Adding New Clients

To add support for a new client:

1. Create a new client file in `vars/clients/[type]/[client].yaml`
2. Define all client-specific settings in that file
3. Update the main `ephemery_variables.yaml` if needed
