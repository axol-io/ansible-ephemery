#! /bin/bash

# Install Ansible collections
# Version: 1.0.0

# Check if ansible-galaxy is installed
if ! command -v ansible-galaxy &>/dev/null; then
  echo "ansible-galaxy could not be found"
  exit 1
fi

# Install collections
ansible-galaxy collection install community.docker

# Check if collections are installed
if ! ansible-galaxy collection list | grep -q "community.docker"; then
  echo "community.docker collection could not be found"
  exit 1
fi

echo "collections installed successfully"
