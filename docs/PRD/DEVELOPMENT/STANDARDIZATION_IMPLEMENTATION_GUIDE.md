# Standardization Implementation Guide

This guide provides instructions for developers to adopt the standardized path configuration and shell script library in their code.

## Table of Contents
- [Using the Common Shell Library](#using-the-common-shell-library)
- [Using Standardized Path Configuration in Ansible](#using-standardized-path-configuration-in-ansible)
- [Migration Guide for Existing Scripts](#migration-guide-for-existing-scripts)
- [Validation and Testing](#validation-and-testing)

## Using the Common Shell Library

### Overview

The common shell library (`scripts/core/common.sh`) provides standardized functions for:
- Color definitions and text formatting
- Logging with timestamps and severity levels
- Error handling and trapping
- Path handling and directory management
- Command line argument parsing
- Docker helper functions

### Basic Usage

To use the common shell library in your scripts:

```bash
#!/bin/bash

# Source the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/scripts/core/common.sh" || {
  echo "Error: Failed to source common library" >&2
  exit 1
}

# Setup error handling
setup_error_handling

# Ensure all directories exist
ensure_standard_dirs || {
  log_error "Failed to create required directories"
  exit 1
}

# Example usage of logging functions
log_info "Starting script..."
log_debug "Debug message (only shown when EPHEMERY_DEBUG=true)"

# Example of command line argument parsing
for arg in "$@"; do
  # Handle boolean flags
  if parse_bool_flag "${arg}" "--verbose"; then
    export EPHEMERY_DEBUG=true
    continue
  fi
  
  # Handle flags with values
  value=$(parse_flag_value "${arg}" "${1:-}" "--base-dir")
  if [[ $? -eq 0 ]]; then
    export EPHEMERY_BASE_DIR="${value}"
    shift
    continue
  fi
done

# Using path functions
CONFIG_DIR=$(get_component_path "config")
log_info "Using config directory: ${CONFIG_DIR}"

# Docker checks
check_docker || {
  log_error "Docker is required but not available"
  exit 1
}

# Example of checking container status
if is_container_running "ephemery-geth"; then
  log_success "Geth container is running"
else
  log_warning "Geth container is not running"
fi

# Clean up on exit
trap cleanup EXIT
```

### Best Practices

1. **Always handle errors**: Use `setup_error_handling` at the beginning of your script
2. **Use logging functions**: Replace `echo` with the appropriate logging function
3. **Standardize paths**: Use `get_component_path` for consistent paths
4. **Clean up resources**: Use the `trap cleanup EXIT` pattern
5. **Check prerequisites**: Use helper functions like `check_docker`

## Using Standardized Path Configuration in Ansible

### Overview

The standardized path configuration (`ansible/vars/paths.yaml`) provides consistent path definitions for Ansible playbooks and roles.

### Basic Usage

To use the standardized paths in your Ansible playbooks:

```yaml
---
- name: Example playbook using standardized paths
  hosts: all
  vars_files:
    - "../vars/paths.yaml"
  
  tasks:
    - name: Ensure config directory exists
      ansible.builtin.file:
        path: "{{ ephemery_dirs.config }}"
        state: directory
        mode: '0755'
      
    - name: Copy configuration file
      ansible.builtin.template:
        src: templates/config.j2
        dest: "{{ ephemery_files.geth_config }}"
        mode: '0644'
      
    - name: Start Geth container
      community.docker.docker_container:
        name: "{{ ephemery_containers.geth }}"
        image: "{{ ephemery_images.geth }}"
        network_name: "{{ ephemery_docker_network }}"
        volumes:
          - "{{ ephemery_dirs.geth_data }}:/ethdata"
          - "{{ ephemery_files.jwt_secret }}:/config/jwt-secret"
        ports:
          - "{{ ephemery_ports.geth_http }}:8545"
          - "{{ ephemery_ports.geth_auth }}:8551"
        # Additional container configuration...
```

### Best Practices

1. **Always include paths.yaml**: Use `vars_files` to include the paths file
2. **Use variable namespaces**: Use the structured variables (e.g., `ephemery_dirs.config`)
3. **Environment awareness**: Set `ephemery_env` variable when invoking playbooks for different environments
4. **No hardcoded paths**: Replace all hardcoded paths with the variables from `paths.yaml`

## Migration Guide for Existing Scripts

### Shell Scripts Migration

To migrate an existing shell script to use the common library:

1. **Add the source line** at the beginning of your script:
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
   source "${SCRIPT_DIR}/scripts/core/common.sh" || {
     echo "Error: Failed to source common library" >&2
     exit 1
   }
   ```

2. **Replace color definitions**:
   ```bash
   # Before
   GREEN='\033[0;32m'
   YELLOW='\033[1;33m'
   
   # After
   # (No need to define colors as they're in the common library)
   ```

3. **Replace echo statements** with logging functions:
   ```bash
   # Before
   echo -e "${GREEN}Success${NC}: Container started"
   echo -e "${RED}Error${NC}: Failed to start container" >&2
   
   # After
   log_success "Container started"
   log_error "Failed to start container"
   ```

4. **Replace path definitions** with path functions:
   ```bash
   # Before
   EPHEMERY_BASE_DIR=~/ephemery
   CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
   
   # After
   # Base dir is set by common library
   CONFIG_DIR=$(get_component_path "config")
   ```

5. **Add error handling**:
   ```bash
   # After your source line
   setup_error_handling
   
   # At the end of your script
   trap cleanup EXIT
   ```

### Ansible Playbooks Migration

To migrate an existing Ansible playbook to use standardized paths:

1. **Include the paths file** at the top of your playbook:
   ```yaml
   vars_files:
     - "../vars/paths.yaml"
   ```

2. **Replace hardcoded paths** with variables:
   ```yaml
   # Before
   path: "/opt/ephemery/config"
   
   # After
   path: "{{ ephemery_dirs.config }}"
   ```

3. **Replace container names and image tags**:
   ```yaml
   # Before
   name: "ephemery-geth"
   image: "pk910/ephemery-geth:latest"
   
   # After
   name: "{{ ephemery_containers.geth }}"
   image: "{{ ephemery_images.geth }}"
   ```

## Validation and Testing

### Shell Script Validation

- Run scripts with `EPHEMERY_DEBUG=true` to view debug logs
- Test script with `shellcheck` to ensure compliance with best practices
- Run in testing environment first with `EPHEMERY_BASE_DIR=/tmp/ephemery`

### Ansible Playbook Validation

- Perform a dry run with `--check` mode:
  ```bash
  ansible-playbook -i inventory.yaml playbook.yaml --check
  ```
- Use different environments with `-e ephemery_env=testing`
- Verify path usage with `ansible-lint`

### Comprehensive Testing

Before submitting changes:
1. Run unit tests if available
2. Test in a staging/development environment
3. Verify that paths are consistent across all components
4. Ensure no hardcoded paths remain in your changes 