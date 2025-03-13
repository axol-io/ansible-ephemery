# Ansible Ephemery Repository Structure

This document outlines the organization of the Ansible Ephemery repository.

## Directory Structure

```bash
ansible-ephemery/
├── ansible/                # Ansible related files
│   ├── defaults/           # Default variables
│   │   └── main.yaml       # Main defaults
│   ├── tasks/              # Task definitions
│   │   ├── clients/        # Client-specific tasks
│   │   ├── backup.yaml     # Backup operations
│   │   ├── cadvisor.yaml   # Container monitoring
│   │   ├── ephemery.yaml   # Core Ephemery functions
│   │   ├── monitoring.yaml # Metrics collection
│   │   ├── security.yaml   # Consolidated security (JWT + firewall)
│   │   ├── setup-env.yaml  # Environment preparation
│   │   └── validator.yaml  # Validator configuration
│   ├── handlers/           # Event handlers
│   │   └── main.yaml       # Main handlers
│   ├── meta/               # Role metadata
│   │   └── main.yaml       # Dependencies and info
│   ├── vars/               # Non-default variables
│   │   └── main.yaml       # Main variables
│   ├── templates/          # Jinja2 templates
│   │   ├── docker-compose.yaml.j2 # Container orchestration
│   │   └── ...             # Additional templates
│   ├── files/              # Static files
│   │   └── ...             # Configs and resources
│   ├── host_vars/          # Host-specific variables
│   │   └── ...             # Per-host configuration
│   ├── group_vars/         # Group-specific variables
│   │   └── all.yaml        # All-hosts configuration
│   ├── playbooks/          # Additional playbooks
│   │   ├── update.yaml     # Update orchestration
│   │   └── ...             # Other playbooks
│   ├── clients/            # Client-specific configurations
│   └── inventory.yaml      # Inventory file
├── molecule/               # Testing framework
│   ├── clients/            # Client combinations
│   │   ├── geth-lighthouse/ # EL-CL client pair
│   │   ├── geth-prysm/     # EL-CL client pair
│   │   └── ...             # Other client pairs
│   ├── default/            # Basic tests
│   ├── backup/             # Backup tests
│   ├── monitoring/         # Monitoring tests
│   ├── resource-limits/    # Resource constraint tests
│   ├── security/           # Security tests
│   ├── validator/          # Validator tests
│   ├── shared/             # Common test resources
│   │   ├── scripts/        # Test utilities
│   │   │   ├── generate_scenario.sh  # Scenario generator
│   │   │   └── demo_scenario.sh      # Demo runner
│   │   └── templates/      # Test templates
│   ├── README.md           # Testing documentation
│   ├── requirements.yaml   # Test dependencies
│   └── run-tests.sh        # Test runner
├── scripts/                # Utility scripts
│   ├── health_check.sh     # Node health monitor
│   ├── generate-molecule-tests.sh # Generate molecule tests
│   ├── run-molecule-tests-macos.sh # Run tests on macOS
│   ├── manage-molecule.sh  # Molecule management
│   ├── repo-standards.sh   # Repository standardization
│   └── ...                 # Additional utilities
├── docs/                   # Documentation
│   ├── PRD/                # Product Requirements Documentation
│   │   ├── ARCHITECTURE/   # Architectural documentation
│   │   ├── DEPLOYMENT/     # Deployment guides
│   │   ├── DEVELOPMENT/    # Development guidelines
│   │   ├── FEATURES/       # Feature specifications
│   │   ├── OPERATIONS/     # Operational guides
│   │   └── DESIGN/         # Design principles
│   ├── roadmaps/           # Project roadmaps
│   └── ...                 # Legacy documentation
├── ephemery.yaml           # Main playbook
├── ansible.cfg             # Ansible configuration
├── example-inventory.yaml  # Example host inventory
├── README.md               # Main documentation
├── requirements.yaml       # Galaxy dependencies
├── requirements.txt        # Python dependencies
└── requirements-dev.txt    # Development dependencies
```

## File Naming Convention

- YAML files use `.yaml` extension (not `.yml`) except in molecule directory
- Files use lowercase with hyphens for multi-word names
- Task files named by function

## Variable Organization

Variables precedence (lowest to highest):

1. `ansible/defaults/main.yaml` - Default values
2. `ansible/vars/main.yaml` - Common variables
3. `ansible/group_vars/all.yaml` - All-hosts variables
4. `ansible/group_vars/<group>.yaml` - Group-specific variables
5. `ansible/host_vars/<host>.yaml` - Host-specific variables
6. Command line `-e` variables - Runtime overrides

## Task Organization

- Core tasks in `ansible/tasks/` directory
- Client-specific tasks in `ansible/tasks/clients/`
- Component-specific task files for modularity
- Consolidated security configuration in `security.yaml`

## Playbook Organization

- `main.yaml` serves as primary entry point
- Special-purpose playbooks in `ansible/playbooks/` directory
- Playbooks use tags for selective execution

## Molecule Testing Structure

The `molecule/` directory contains:

### Test Scenarios

- `default/` - Basic functionality
- `clients/` - Client combinations in subdirectories
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
- See `docs/PRD/DEVELOPMENT/SECURITY.md` for details
