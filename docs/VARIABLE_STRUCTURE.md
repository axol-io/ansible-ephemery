# Ansible Ephemery Variable Structure

This document explains the variable structure and precedence in the Ansible Ephemery repository.

## Variable Hierarchy

Variables in Ansible follow a specific precedence order. In the Ephemery repository, the hierarchy from lowest to highest precedence is:

1. `defaults/main.yaml` - Default values for all variables
2. `vars/main.yaml` - Common variables that shouldn't be overridden by defaults
3. `group_vars/all.yaml` - Variables common to all hosts
4. `group_vars/<group>.yaml` - Variables specific to a group
5. `host_vars/<host>.yaml` - Variables specific to a host
6. `host_vars/secrets.yaml` - Encrypted secrets file (when present)
7. Command line `-e` variables - Override any of the above

## Main Variable Files

### defaults/main.yaml

Contains default values that can be overridden by any of the higher-precedence variable sources. This includes:

- Network and directory configurations
- Default client selections
- Resource management settings
- Monitoring configurations
- Backup settings
- Security configurations

### vars/main.yaml

Contains "hard-coded" variables that shouldn't be overridden by default variables. These include:

- Repository information
- Docker image references
- File path references
- Docker volume mounting configurations

### group_vars/all.yaml

Contains variables that apply to all hosts in the inventory:

- Global network settings
- SSH connection settings

### host_vars/<hostname>.yaml

Contains host-specific variables:

- Client selection (el, cl)
- Feature flags (monitoring_enabled, validator_enabled, etc.)
- Host-specific paths and configurations

### secrets.yaml

Contains sensitive information that should be encrypted with Ansible Vault:

- Passwords
- API tokens
- Private keys
- JWT secrets

## Example Usage

The example files provided (`example-host.yaml`, `secrets.yaml.example`, and `inventory.yaml.example`) demonstrate the recommended variable structure.

For a new deployment:

1. Copy `inventory.yaml.example` to `inventory.yaml` and customize for your environment
2. For each host in your inventory, create a host_vars file by copying `example-host.yaml`
3. Copy `secrets.yaml.example` to `secrets.yaml` and fill in your sensitive data
4. Encrypt `secrets.yaml` using: `ansible-vault encrypt host_vars/secrets.yaml`

## Client-Specific Variables

Client-specific variables (for different execution and consensus clients) are referenced through the `el` and `cl` variables:

```yaml
# Select clients in host_vars
el: "geth"
cl: "lighthouse"

# The system will then use the appropriate image from vars/main.yaml
# client_images.geth -> "ethereum/client-go:latest"
# client_images.lighthouse -> "sigp/lighthouse:latest"
```

## Best Practices

1. Keep sensitive data in `secrets.yaml` and encrypt it with Ansible Vault
2. Override defaults in inventory groups for common configurations
3. Use host_vars for host-specific settings
4. Use tags with playbooks to apply only relevant portions of configuration
