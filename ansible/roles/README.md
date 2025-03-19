# Ansible Roles

This directory contains standardized roles for Ephemery deployment and management.

## Core Roles

- **common**: Base configuration for all nodes
- **execution_client**: Configuration for execution clients (Geth, Nethermind, etc.)
- **consensus_client**: Configuration for consensus clients (Lighthouse, Prysm, etc.)
- **monitoring**: Monitoring and metrics collection
- **security**: Security hardening and management
- **backup**: Backup and recovery procedures

## Role Structure

Each role follows a standard Ansible role structure:
- `defaults/`: Default variable values
- `handlers/`: Event handlers
- `tasks/`: Main task files
- `templates/`: Jinja2 templates
- `vars/`: Role-specific variables

## Usage

Roles are modular and can be combined as needed in playbooks. The `common` role should always be included first.

Example:
```yaml
- hosts: ephemery_nodes
  roles:
    - common
    - execution_client
    - consensus_client
    - monitoring
```
