# Common Role

The Common role provides base system configuration shared by all Ephemery nodes. It sets up foundational components necessary for running Ethereum nodes, including system tuning, security configurations, and shared services.

## Role Overview

This role performs the following tasks:

- System tuning and optimization for Ethereum nodes
- Firewall configuration and security hardening
- JWT secret management for secure client communication
- Docker installation (when required)
- Common directory structure creation
- System user and group management
- Basic monitoring setup

## Variables

### Required Variables

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `common_user` | User to run Ethereum services | `ethereum` |
| `common_group` | Group for the Ethereum user | `ethereum` |
| `base_dir` | Base directory for Ethereum data | `/opt/ethereum` |
| `config_dir` | Configuration directory | `{{ base_dir }}/config` |
| `jwt_secret_path` | Path to JWT secret file | `{{ config_dir }}/jwt-secret` |

### Optional Variables

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `common_install_docker` | Whether to install Docker | `false` |
| `common_firewall_enabled` | Whether to configure the firewall | `true` |
| `common_system_tuning` | Whether to apply system tuning | `true` |
| `common_open_ports` | List of ports to open in the firewall | `[22, 30303, 9000]` |
| `common_max_open_files` | Maximum number of open files | `65535` |
| `common_install_monitoring` | Whether to install basic monitoring tools | `true` |
| `common_timezone` | System timezone | `UTC` |

## Example Usage

```yaml
# In your playbook or inventory
- name: Apply common configuration
  hosts: ethereum_nodes
  roles:
    - role: common
      vars:
        common_user: ethereum
        common_group: ethereum
        base_dir: /data/ethereum
        common_install_docker: true
        common_firewall_enabled: true
        common_open_ports:
          - 22    # SSH
          - 30303 # P2P Execution
          - 9000  # P2P Consensus
          - 3000  # Grafana
          - 9090  # Prometheus
```

## Dependencies

- Requires Ansible 2.9 or higher
- Requires a Debian/Ubuntu-based system (or similar with apt) for full functionality
- Some tasks may require root privileges

## Handlers

| Handler Name | Description |
|--------------|-------------|
| `restart systemd-journald` | Restart the journald service after configuration changes |
| `reload sysctl` | Reload system configuration after tuning parameters |
| `reload firewall` | Reload firewall rules after changes |

## File Structure

```
common/
├── defaults/
│   └── main.yml         # Default variable values
├── tasks/
│   ├── main.yml         # Main task entry point
│   ├── directories.yml  # Directory setup tasks  
│   ├── firewall.yml     # Firewall configuration
│   ├── jwt.yml          # JWT management
│   ├── system_tuning.yml # System optimization
│   └── docker.yml       # Docker installation
├── handlers/
│   └── main.yml         # Handlers for the role
└── templates/
    ├── limits.conf.j2   # System limits template
    └── sysctl.conf.j2   # System tuning template
```

## Notes

- This role should be applied to all nodes before any client-specific roles
- The JWT secret is used for secure communication between execution and consensus clients
- System tuning parameters are optimized for Ethereum node operation
- Firewall rules are configured to allow necessary Ethereum network traffic

## Related Documentation

- [Execution Client Role](execution_client.md)
- [Consensus Client Role](consensus_client.md)
- [JWT Authentication Troubleshooting](../troubleshooting/jwt_authentication.md)

---

*Last Updated: 2023-03-18*
