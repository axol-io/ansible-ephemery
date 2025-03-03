#!/bin/bash
#
# Script to set up a complete Ansible Ephemery repository structure

echo "Setting up complete Ansible Ephemery repository structure..."

# Create main directory structure if not exists
directories=(
  "group_vars"
  "playbooks"
  "scripts"
  "docs"
  "roles/ephemery"
)

for dir in "${directories[@]}"; do
  if [ ! -d "$dir" ]; then
    echo "Creating directory: $dir"
    mkdir -p "$dir"
  else
    echo "Directory already exists: $dir"
  fi
done

# Create initial content for new directories
if [ ! -f "group_vars/all.yaml" ]; then
  echo "Creating group_vars/all.yaml"
  cat > "group_vars/all.yaml" << EOF
---
# Common variables for all hosts
# Override in host_vars or with -e flag

# Global settings
ansible_user: ubuntu
ansible_become: true
EOF
fi

if [ ! -f "playbooks/update.yaml" ]; then
  echo "Creating playbooks/update.yaml"
  cat > "playbooks/update.yaml" << EOF
---
# Playbook for updating Ephemery nodes
- name: Update Ephemery Nodes
  hosts: all
  become: true
  vars_files:
    - file: ../defaults/main.yaml
  tasks:
    - name: Pull latest Docker images
      community.docker.docker_image:
        name: "{{ item }}"
        source: pull
        force_source: true
      loop:
        - "{{ el_docker_image }}"
        - "{{ cl_docker_image }}"
      tags:
        - update
        - docker
EOF
fi

if [ ! -f "scripts/health_check.sh" ]; then
  echo "Creating scripts/health_check.sh"
  cat > "scripts/health_check.sh" << EOF
#!/bin/bash
#
# Health check script for Ephemery nodes

set -e

# Check execution client
check_el() {
  local host=\$1
  echo "Checking execution client on \$host..."
  curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' "http://\$host:8545"
}

# Check consensus client
check_cl() {
  local host=\$1
  echo "Checking consensus client on \$host..."
  curl -s "http://\$host:5052/eth/v1/node/health"
}

# Main
if [ -z "\$1" ]; then
  echo "Usage: \$0 <hostname>"
  exit 1
fi

check_el "\$1"
check_cl "\$1"
EOF
  chmod +x "scripts/health_check.sh"
fi

if [ ! -f "docs/SECURITY.md" ]; then
  echo "Creating docs/SECURITY.md"
  cat > "docs/SECURITY.md" << EOF
# Security Considerations

This document outlines security best practices for Ephemery node deployment.

## JWT Secret Management

- JWT secrets should always be handled using Ansible Vault
- Do not commit unencrypted secrets to the repository
- Rotate secrets periodically

## Firewall Configuration

The default firewall configuration allows the following ports:
- 22 (SSH)
- 30303 (Execution P2P)
- 9000 (Consensus P2P)
- 8545 (Execution API) - restricted to certain IPs
- 5052 (Consensus API) - restricted to certain IPs

## Docker Security

- The containers run with limited capabilities
- Container resource limits are enforced
- Images are pinned to specific versions
EOF
fi

echo "Completed setting up repository structure."
echo "Adjust files as needed for your specific requirements."
