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

# Make sure ansible-lint is installed
if ! command -v ansible-lint &> /dev/null; then
    echo "ansible-lint could not be found, installing..."
    pip install ansible-lint
fi

# Install the collections from requirements.yaml to our local directory
echo "Installing Ansible collections from requirements.yaml to $COLLECTIONS_DIR..."
ANSIBLE_COLLECTIONS_PATH="$COLLECTIONS_DIR" ansible-galaxy collection install -r "$REPO_ROOT/requirements.yaml" -f

echo "Collections installed successfully at $COLLECTIONS_DIR"

# Verify installations
echo "Verifying collection installations:"
collections_missing=0

if ls -la "$COLLECTIONS_DIR/ansible_collections/community/docker/" 2>/dev/null; then
    echo "✅ community.docker installed"
else
    echo "❌ community.docker NOT installed"
    collections_missing=1
fi

if ls -la "$COLLECTIONS_DIR/ansible_collections/ansible/posix/" 2>/dev/null; then
    echo "✅ ansible.posix installed"
else
    echo "❌ ansible.posix NOT installed"
    collections_missing=1
fi

if ls -la "$COLLECTIONS_DIR/ansible_collections/community/general/" 2>/dev/null; then
    echo "✅ community.general installed"
else
    echo "❌ community.general NOT installed"
    collections_missing=1
fi

# Print ansible collections path for debugging
echo "ANSIBLE_COLLECTIONS_PATH: $ANSIBLE_COLLECTIONS_PATH"

# Validate ansible-lint can find the collections
if which ansible-lint >/dev/null; then
    echo "Testing ansible-lint can find collections..."
    ANSIBLE_COLLECTIONS_PATH="$COLLECTIONS_DIR" ansible-lint --version
else
    echo "Warning: ansible-lint not found, cannot validate collection discovery"
fi

# Exit with error if any collections are missing
if [ $collections_missing -eq 1 ]; then
    echo "Error: Some required collections are missing!"
    exit 1
fi
