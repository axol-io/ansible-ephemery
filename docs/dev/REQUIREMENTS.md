# Requirements

This document explains the dependencies and requirements for the ansible-ephemery project.

## Requirement Files

| File | Purpose | Install Command |
|------|---------|----------------|
| `requirements.yaml` | Ansible Galaxy collections | `ansible-galaxy collection install -r requirements.yaml` |
| `requirements.txt` | Python dependencies | `pip install -r requirements.txt` |
| `requirements-dev.txt` | Development dependencies | `pip install -r requirements-dev.txt` |

## Ansible Requirements

### Core Ansible Components

- Ansible Core 2.15.0 or newer
- Ansible Lint 25.1.3 or newer
- Python 3.11 or newer (recommended)

### Required Collections

```yaml
---
- ansible.posix (2.0.0+)      # POSIX system operations
- community.docker (4.4.0+)   # Docker container management
- community.general (8.0.0+)  # General utilities and modules
```

## Host Requirements

### Control Node Requirements

- Ansible installed
- Python 3.11+ recommended
- SSH access to managed nodes
- Required Python packages installed

### Managed Node Requirements

- Docker installed and running
- SSH server accessible
- Python 3 installed
- Sufficient disk space (20GB+ recommended)
- 4+ CPU cores recommended
- 8GB+ RAM recommended

## Development Requirements

For contributing to or testing this project, you need:

1. All production requirements
2. Additional Python packages from `requirements-dev.txt`
3. Docker for running tests
4. Pre-commit hooks installed (`pre-commit install`)

## Client Requirements

Ephemery client wrapper images require:

- Docker with volume support
- Internet connectivity for image pulling
- Sufficient resources for selected client combinations:
  - Lightweight: 4GB RAM, 2 cores (Lighthouse + Geth)
  - Full: 16GB RAM, 4+ cores (Teku + Erigon)

## Version Pinning

All dependencies are pinned to specific versions to ensure:

- Reproducible environments
- Consistent functionality
- Security patching through regular updates
