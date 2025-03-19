# Deploy Ephemery Playbook

> **Summary:** The `deploy_ephemery.yaml` playbook is the primary playbook for deploying Ephemery nodes with any combination of execution and consensus clients.

## Overview

The `deploy_ephemery.yaml` playbook provides a unified approach to deploying Ephemery nodes. It handles all necessary setup steps including:

- System preparation
- Client installation and configuration
- JWT secret management
- Directory creation
- Service setup
- Initial synchronization

This consolidated playbook replaces multiple client-specific playbooks, providing a more maintainable and consistent deployment process.

## Playbook Structure

```yaml
- name: Deploy Ephemery Node
  hosts: ephemery_nodes
  become: true
  vars:
    el_client_name: geth  # Default execution client
    cl_client_name: lighthouse  # Default consensus client
    # Other default variables

  roles:
    - role: common
    - role: execution_client
    - role: consensus_client
```

## Usage

### Basic Usage

Deploy Ephemery nodes using the default client configuration:

```bash
ansible-playbook -i inventory.yaml playbooks/deploy_ephemery.yaml
```

### Specifying Client Combinations

Specify different client combinations:

```bash
ansible-playbook -i inventory.yaml playbooks/deploy_ephemery.yaml -e "el=nethermind cl=prysm"
```

Multiple client parameters:

```bash
ansible-playbook -i inventory.yaml playbooks/deploy_ephemery.yaml \
  -e "el=geth cl=lighthouse validator_enabled=true"
```

### Execution Client-Only Deployment

Deploy only the execution client:

```bash
ansible-playbook -i inventory.yaml playbooks/deploy_ephemery.yaml --tags execution
```

### Common Configuration Only

Deploy only common configurations:

```bash
ansible-playbook -i inventory.yaml playbooks/deploy_ephemery.yaml --tags common
```

### JWT and Services Setup Only

Deploy only JWT and service configurations:

```bash
ansible-playbook -i inventory.yaml playbooks/deploy_ephemery.yaml --tags jwt,services
```

## Supported Client Combinations

| Execution Client | Consensus Client | Supported |
|------------------|------------------|-----------|
| Geth             | Lighthouse       | ✅         |
| Geth             | Prysm            | ✅         |
| Nethermind       | Lighthouse       | ✅         |
| Nethermind       | Prysm            | ✅         |
| Besu             | Lighthouse       | ✅         |
| Besu             | Prysm            | ✅         |
| Erigon           | Teku             | ⚠️ (Beta)  |
| Any              | Nimbus           | ⚠️ (Beta)  |
| Any              | Lodestar         | ⚠️ (Beta)  |

## Variables

### Required Variables

| Variable Name | Description |
|---------------|-------------|
| `el_client_name` | Name of the execution client to deploy (geth, nethermind, etc.) |
| `cl_client_name` | Name of the consensus client to deploy (lighthouse, prysm, etc.) |

### Optional Variables

| Variable Name | Default Value | Description |
|---------------|---------------|-------------|
| `data_dir` | `/opt/ephemery` | Base data directory |
| `jwt_secret_path` | `/opt/ephemery/jwt/jwt.hex` | Path to JWT secret |
| `enable_monitoring` | `true` | Enable monitoring components |
| `network_id` | `13337` | Network ID for the Ephemery chain |
| `chain_id` | `13337` | Chain ID for the Ephemery chain |

## Tags

The playbook includes tags to allow running specific parts:

| Tag | Description |
|-----|-------------|
| `common` | Run only common role tasks |
| `execution` | Run only execution client tasks |
| `consensus` | Run only consensus client tasks |
| `jwt` | Run only JWT management tasks |
| `services` | Run only service setup tasks |

Example of using tags:

```bash
ansible-playbook -i inventory.ini deploy_ephemery.yaml --tags execution
```

## Idempotency

The playbook is designed to be idempotent. You can run it multiple times without causing harm. It will:

- Skip client installation if already installed
- Preserve existing data directories
- Backup any existing configuration before modifying
- Only restart services when needed

## Common Issues and Solutions

### Issue 1: Client Installation Fails

**Symptoms:**
- Package installation errors
- Repository issues

**Solution:**
Ensure package repositories are up to date:
```bash
ansible-playbook -i inventory.ini deploy_ephemery.yaml --tags common
```

### Issue 2: Services Not Starting

**Symptoms:**
- Services in failed state
- Connection errors between clients

**Solution:**
Check JWT configuration and service logs:
```bash
ansible-playbook -i inventory.ini deploy_ephemery.yaml --tags jwt,services
```

## Related Documentation

- [Common Role](../roles/common.md)
- [Execution Client Role](../roles/execution_client.md)
- [Consensus Client Role](../roles/consensus_client.md)
- [Fix Ephemery Node Playbook](fix_ephemery_node.md)
- [Client Migration Tutorial](../tutorials/client_migration.md)

---

*Last Updated: 2023-03-18*
