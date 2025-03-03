# Ansible Ephemery Repository Structure

This document outlines the organization of the Ansible Ephemery repository.

## Directory Structure

```
ansible-ephemery/
├── ansible.cfg               # Ansible configuration
├── defaults/                 # Default variables
│   └── main.yaml             # Main defaults
├── tasks/                    # Task definitions
│   ├── clients/              # Client-specific tasks
│   ├── backup.yaml           # Backup operations
│   ├── cadvisor.yaml         # Container monitoring
│   ├── ephemery.yaml         # Core Ephemery functions
│   ├── firewall.yaml         # Network security
│   ├── jwt-secret.yaml       # Authentication secrets
│   ├── monitoring.yaml       # Metrics collection
│   ├── setup-env.yaml        # Environment preparation
│   └── validator.yaml        # Validator configuration
├── handlers/                 # Event handlers
│   └── main.yaml             # Main handlers
├── meta/                     # Role metadata
│   └── main.yaml             # Dependencies and info
├── vars/                     # Non-default variables
│   └── main.yaml             # Main variables
├── templates/                # Jinja2 templates
│   ├── docker-compose.yaml.j2 # Container orchestration
│   └── ...                   # Additional templates
├── files/                    # Static files
│   └── ...                   # Configs and resources
├── host_vars/                # Host-specific variables
│   └── ...                   # Per-host configuration
├── group_vars/               # Group-specific variables
│   └── all.yaml              # All-hosts configuration
├── molecule/                 # Testing framework
│   ├── [client-scenarios]/   # Client combinations
│   ├── clients/              # Client templates
│   ├── default/              # Basic tests
│   ├── backup/               # Backup tests
│   ├── monitoring/           # Monitoring tests
│   ├── resource-limits/      # Resource constraint tests
│   ├── security/             # Security tests
│   ├── validator/            # Validator tests
│   ├── shared/               # Common test resources
│   │   ├── scripts/          # Test utilities
│   │   │   ├── generate_scenario.sh  # Scenario generator
│   │   │   └── demo_scenario.sh      # Demo runner
│   │   └── templates/        # Test templates
│   ├── README.md             # Testing documentation
│   ├── requirements.yaml     # Test dependencies
│   └── run-tests.sh          # Test runner
├── playbooks/                # Additional playbooks
│   ├── update.yaml           # Update orchestration
│   └── ...                   # Other playbooks
├── scripts/                  # Utility scripts
│   ├── health_check.sh       # Node health monitor
│   └── ...                   # Additional utilities
├── docs/                     # Documentation
│   ├── REPOSITORY_STRUCTURE.md  # This file
│   ├── REQUIREMENTS.md       # Prerequisites
│   ├── SECURITY.md           # Security guidelines
│   └── CI_CD_UPDATES.md      # Pipeline documentation
├── main.yaml                 # Main playbook
├── inventory.yaml.example    # Example host inventory
├── README.md                 # Main documentation
├── requirements.yaml         # Galaxy dependencies
├── requirements.txt          # Python dependencies
└── requirements-dev.txt      # Development dependencies
```

## File Naming Convention

- YAML files use `.yaml` extension (not `.yml`) except in molecule directory
- Files use lowercase with hyphens for multi-word names
- Task files named by function

## Variable Organization

Variables precedence (lowest to highest):

1. `defaults/main.yaml` - Default values
2. `vars/main.yaml` - Common variables
3. `group_vars/all.yaml` - All-hosts variables
4. `group_vars/<group>.yaml` - Group-specific variables
5. `host_vars/<host>.yaml` - Host-specific variables
6. Command line `-e` variables - Runtime overrides

## Task Organization

- Core tasks in `tasks/` directory
- Client-specific tasks in `tasks/clients/`
- Component-specific task files for modularity

## Playbook Organization

- `main.yaml` serves as primary entry point
- Special-purpose playbooks in `playbooks/` directory
- Playbooks use tags for selective execution

## Molecule Testing Structure

The `molecule/` directory contains:

### Test Scenarios
- `default/` - Basic functionality
- `[client-scenarios]/` - Client combinations
- `backup/`, `monitoring/`, etc. - Component tests

### Shared Resources
- `shared/scripts/` - Test automation
- `shared/templates/` - Test generation templates

### Running Tests
- `demo_scenario.sh` for quick tests
- `generate_scenario.sh` for creating scenarios
- `molecule test -s scenario_name` for targeted testing

## Security Considerations

- Sensitive data encrypted with Ansible Vault
- Firewall configuration for network security
- Container security settings enforced
- See `docs/SECURITY.md` for details
