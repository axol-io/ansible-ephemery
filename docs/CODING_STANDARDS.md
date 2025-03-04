# Coding Standards for ansible-ephemery

This document outlines the coding standards and best practices to follow when contributing to the ansible-ephemery project.

## YAML File Naming

### File Extensions

- Use `.yaml` extension instead of `.yml` for all Ansible and configuration files (except in the `molecule` directory)
- In the `molecule` directory, use `.yml` extension for consistency with Molecule's default behavior

```bash
# Correct
tasks/main.yaml
vars/main.yaml
defaults/main.yaml

# Exception - Molecule directory
molecule/default/molecule.yml
molecule/default/converge.yml
```

## Ansible Role Structure

Follow the standard Ansible role structure for organizing files:

```plaintext
ansible-ephemery/
├── defaults/
│   └── main.yaml
├── tasks/
│   └── main.yaml
├── handlers/
│   └── main.yaml
├── templates/
│   └── *.j2
├── files/
│   └── *.conf
├── vars/
│   └── main.yaml
├── meta/
│   └── main.yaml
└── molecule/
    └── default/
        ├── molecule.yml
        ├── converge.yml
        └── verify.yml
```

## Ansible Variable Naming

- Use snake_case for all variable names
- Use descriptive names that clearly indicate the purpose of the variable
- Prefix variables with the role name to avoid conflicts

```yaml
# Good
ephemery_data_dir: "/data/ephemery"
ephemery_node_clients:
  el: "geth"
  cl: "lighthouse"

# Bad
dataDir: "/data/ephemery"
node-clients:
  EL: "geth"
  CL: "lighthouse"
```

## Ephemery Client Configuration

Use the supported client values for Execution Layer (EL) and Consensus Layer (CL) clients:

### Execution Layer Clients

- geth
- besu
- nethermind
- reth
- erigon

### Consensus Layer Clients

- lighthouse
- teku
- prysm
- lodestar

## Security Best Practices

- Never commit sensitive information like passwords, tokens, or keys directly in the code
- Use Ansible Vault for encrypting sensitive information
- Handle JWT secrets securely by using vault-encrypted values

```yaml
# Good
jwt_secret: '{{ vault_ephemery_jwt_secret }}'

# Bad
jwt_secret: "0x1234567890abcdef1234567890abcdef"
```

## Docker Configuration

- Specify version tags for Docker images rather than using 'latest'
- Set resource limits for Docker containers where appropriate

```yaml
# Good
image: "ethereum/client-go:v1.12.0"
memory_limit: "2048M"

# Bad
image: "ethereum/client-go:latest"
```

## YAML Formatting

- Use 2-space indentation for all YAML files
- Keep lines under 100 characters for readability
- Use `true`/`false` for boolean values (not `yes`/`no`)
- Always use quotes for string values that could be interpreted as numbers or booleans

## Task Documentation

- Provide descriptive names for all tasks
- Use comments to explain complex operations
- Document parameters and expected outcomes

```yaml
# Good
- name: Create Ethereum data directory
  file:
    path: '{{ ephemery_data_dir }}'
    state: directory
    mode: 0755
  # This directory will store blockchain data and needs appropriate permissions

# Bad
- file:
    path: '{{ ephemery_data_dir }}'
    state: directory
```
