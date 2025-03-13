#!/bin/bash
# install-collections.sh
# Script to install Ansible collections required for pre-commit hooks and linting
# This script is used as a pre-commit hook

set -euo pipefail

# Get the repository root directory
REPO_ROOT=$(git rev-parse --show-toplevel)

# Change to the repository root
cd "$REPO_ROOT"

# Check if requirements.yaml file exists
if [ ! -f "requirements.yaml" ]; then
    echo "Error: requirements.yaml file not found"
    exit 1
fi

# Create collections directory if it doesn't exist
mkdir -p collections

# Install collections to local directory
ANSIBLE_COLLECTIONS_PATH="$REPO_ROOT/collections" ansible-galaxy collection install -r requirements.yaml --force

echo "Ansible collections installed successfully to $REPO_ROOT/collections"
exit 0
