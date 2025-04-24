#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: standardize_configuration_files.sh
# Description: Standardizes configuration files and creates symlinks
# Author: Ephemery Team
# Created: 2025-03-19
# Last Modified: 2025-03-19
#
# Usage: ./standardize_configuration_files.sh [--help]

# Root-level config files we want in the project root
declare -A root_files=(
  ["config/ansible/.ansible-lint"]=".ansible-lint"
  ["config/ansible/.yamllint"]=".yamllint"
)

# Config file locations - ensure these are available in Docker images
BASE_CONFIG_DIR="config"
ANSIBLE_CONFIG_DIR="${BASE_CONFIG_DIR}/ansible"
MOLECULE_CONFIG_DIR=".dev/molecule"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Function to create directories
create_dirs() {
  echo "Creating standardized config directories..."
  mkdir -p "${PROJECT_ROOT}/${ANSIBLE_CONFIG_DIR}"
  mkdir -p "${PROJECT_ROOT}/${MOLECULE_CONFIG_DIR}"
}

# Function to standardize Ansible config files
standardize_ansible_config() {
  echo "Standardizing Ansible configuration files..."

  # Create standard .ansible-lint if it doesn't exist
  if [[ ! -f "${PROJECT_ROOT}/${ANSIBLE_CONFIG_DIR}/.ansible-lint" ]]; then
    cat >"${PROJECT_ROOT}/${ANSIBLE_CONFIG_DIR}/.ansible-lint" <<'EOF'
---
exclude_paths:
  - collections/
  - .git/
  - molecule/
  - .github/
  - .vscode/
  - scripts/testing/fixtures/

skip_list:
  - yaml[line-length]
  - yaml[truthy]
  - var-naming[no-role-prefix]
  - name[casing]
  - name[template]
  - jinja[spacing]
  - schema[tasks]
  - no-handler
  - no-changed-when
  - no-relative-paths
  - fqcn[action-core]
  - fqcn[action]
  - command-instead-of-shell
  - key-order
  - risky-file-permissions
  - risky-shell-pipe

warn_list:
  - experimental
  - unnamed-task

use_default_rules: true
parseable: true

offline: false
verbosity: 1
EOF
    echo "Created default .ansible-lint"
  fi

  # Create standard .yamllint if it doesn't exist
  if [[ ! -f "${PROJECT_ROOT}/${ANSIBLE_CONFIG_DIR}/.yamllint" ]]; then
    cat >"${PROJECT_ROOT}/${ANSIBLE_CONFIG_DIR}/.yamllint" <<'EOF'
---
extends: default

rules:
  line-length:
    max: 140
    level: warning
  truthy:
    allowed-values: ["true", "false", "yes", "no"]
    check-keys: false
  indentation:
    spaces: 2
    indent-sequences: consistent
  braces:
    max-spaces-inside: 1
    level: error
  comments:
    min-spaces-from-content: 1
  comments-indentation: false
  octal-values:
    forbid-implicit-octal: true
    forbid-explicit-octal: true

ignore: |
  collections/
  .git/
EOF
    echo "Created default .yamllint"
  fi
}

# Function to standardize Molecule config
standardize_molecule_config() {
  echo "Standardizing Molecule configuration..."

  # Create standard molecule config.yaml if it doesn't exist
  if [[ ! -f "${PROJECT_ROOT}/${MOLECULE_CONFIG_DIR}/config.yaml" ]]; then
    cat >"${PROJECT_ROOT}/${MOLECULE_CONFIG_DIR}/config.yaml" <<'EOF'
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: ephemery-test
    image: docker.io/geerlingguy/docker-ubuntu2204-ansible:latest
    command: ""
    pre_build_image: true
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
provisioner:
  name: ansible
  env:
    ANSIBLE_FORCE_COLOR: "true"
verifier:
  name: ansible
EOF
    echo "Created default Molecule config.yaml"
  fi
}

# Function to create symlinks for root config files
create_symlinks() {
  echo "Creating symlinks for root configuration files..."

  for source in "${!root_files[@]}"; do
    target="${root_files[${source}]}"

    if [[ -f "${PROJECT_ROOT}/${source}" ]]; then
      # Check if target exists and is not a symlink
      if [[ -f "${PROJECT_ROOT}/${target}" && ! -L "${PROJECT_ROOT}/${target}" ]]; then
        echo "Warning: ${target} already exists as a regular file. Backing it up before replacing."
        mv "${PROJECT_ROOT}/${target}" "${PROJECT_ROOT}/${target}.bak"
      fi

      # Create symlink if it doesn't exist or if it points to wrong location
      if [[ ! -L "${PROJECT_ROOT}/${target}" || $(readlink "${PROJECT_ROOT}/${target}") != "${PROJECT_ROOT}/${source}" ]]; then
        echo "Creating symlink from ${source} to ${target}"
        ln -sf "${PROJECT_ROOT}/${source}" "${PROJECT_ROOT}/${target}"
      fi
    else
      echo "Warning: Source file ${source} does not exist. Skipping."
    fi
  done
}

# Function to copy root config files
copy_configs() {
  echo "Copying configuration files instead of symlinking..."

  for source in "${!root_files[@]}"; do
    target="${root_files[${source}]}"

    if [[ -f "${PROJECT_ROOT}/${source}" ]]; then
      echo "Copying ${source} to ${target}"
      cp "${PROJECT_ROOT}/${source}" "${PROJECT_ROOT}/${target}"
    else
      echo "Warning: Source file ${source} does not exist. Skipping."
    fi
  done
}

# Display help message
show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Standardizes configuration files and creates symlinks for Ansible and Molecule.

Options:
  --copy    Copy configuration files instead of creating symlinks
  --help    Show this help message and exit
EOF
}

# Main function
main() {
  local copy_files=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --copy)
        copy_files=true
        shift
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        echo "Error: Unknown option $1"
        show_help
        exit 1
        ;;
    esac
  done

  create_dirs
  standardize_ansible_config
  standardize_molecule_config

  if [[ "${copy_files}" = true ]]; then
    copy_configs
  else
    create_symlinks
  fi

  echo "Configuration standardization complete!"
}

# Run the main function with all arguments
main "$@"
