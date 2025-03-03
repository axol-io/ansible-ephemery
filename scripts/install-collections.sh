#!/usr/bin/env bash

# Script to install Ansible collections needed for linting and testing

set -e

echo "Installing Ansible collections..."

# Determine the root of the repository
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Create a collections directory in the project
COLLECTIONS_DIR="$REPO_ROOT/collections"
mkdir -p "$COLLECTIONS_DIR"
export ANSIBLE_COLLECTIONS_PATH="$COLLECTIONS_DIR"

# Ensure we have pip and ansible
if ! command -v pip &> /dev/null; then
    echo "pip could not be found, installing..."
    curl -s https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python3 get-pip.py
    rm get-pip.py
fi

# Install ansible if needed
if ! command -v ansible-galaxy &> /dev/null; then
    echo "ansible-galaxy could not be found, installing ansible-core..."
    pip install ansible-core
fi

# Install the collections from requirements.yaml to our local directory
echo "Installing Ansible collections from requirements.yaml to $COLLECTIONS_DIR..."
ANSIBLE_COLLECTIONS_PATH="$COLLECTIONS_DIR" ansible-galaxy collection install -r "$REPO_ROOT/requirements.yaml" -f

echo "Collections installed successfully at $COLLECTIONS_DIR" 