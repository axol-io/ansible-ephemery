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

# Check if we have connectivity to galaxy.ansible.com
echo "Checking connectivity to Ansible Galaxy..."
if ping -c 1 galaxy.ansible.com &>/dev/null; then
    HAVE_CONNECTIVITY=true
    echo "✅ Connectivity to galaxy.ansible.com is working"
else
    HAVE_CONNECTIVITY=false
    echo "⚠️ Cannot reach galaxy.ansible.com - will use local collections if available"

    # Check if collections already exist
    if ls -la "$COLLECTIONS_DIR/ansible_collections/" &>/dev/null; then
        echo "Found existing collections, will use those instead of downloading new ones"
    else
        echo "Warning: No connectivity to galaxy.ansible.com and no local collections found"
        echo "Proceeding with git commit anyway, but linting might fail"
    fi
fi

# Ensure we have pip and ansible
if ! command -v pip &> /dev/null; then
    echo "pip could not be found, installing..."
    if [ "$HAVE_CONNECTIVITY" = true ]; then
        curl -s https://bootstrap.pypa.io/get-pip.py -o get-pip.py
        python3 get-pip.py
        rm get-pip.py
    else
        echo "Cannot install pip without internet connectivity, skipping"
    fi
fi

# Install ansible if needed
if ! command -v ansible-galaxy &> /dev/null; then
    echo "ansible-galaxy could not be found, installing ansible-core..."
    if [ "$HAVE_CONNECTIVITY" = true ]; then
        pip install ansible-core
    else
        echo "Cannot install ansible-core without internet connectivity, skipping"
    fi
fi

# Make sure ansible-lint is installed
if ! command -v ansible-lint &> /dev/null; then
    echo "ansible-lint could not be found, installing..."
    if [ "$HAVE_CONNECTIVITY" = true ]; then
        pip install ansible-lint
    else
        echo "Cannot install ansible-lint without internet connectivity, skipping"
    fi
fi

# Install the collections from requirements.yaml to our local directory
if [ "$HAVE_CONNECTIVITY" = true ]; then
    echo "Installing Ansible collections from requirements.yaml to $COLLECTIONS_DIR..."
    ANSIBLE_COLLECTIONS_PATH="$COLLECTIONS_DIR" ansible-galaxy collection install -r "$REPO_ROOT/requirements.yaml" -f

    # Ensure community.docker is installed (try direct install if requirements.yaml failed)
    if ! ls -la "$COLLECTIONS_DIR/ansible_collections/community/docker/" &>/dev/null; then
        echo "community.docker not found after requirements.yaml install, trying direct install..."
        ANSIBLE_COLLECTIONS_PATH="$COLLECTIONS_DIR" ansible-galaxy collection install community.docker:4.4.0 -f
    fi

    echo "Collections installed successfully at $COLLECTIONS_DIR"
else
    echo "Skipping collection installation due to network connectivity issues"
fi

# Verify installations
echo "Verifying collection installations:"
collections_missing=0

if ls -la "$COLLECTIONS_DIR/ansible_collections/community/docker/" 2>/dev/null; then
    echo "✅ community.docker installed"
else
    echo "❌ community.docker NOT installed"
    if [ "$HAVE_CONNECTIVITY" = true ]; then
        collections_missing=1
    fi
fi

if ls -la "$COLLECTIONS_DIR/ansible_collections/ansible/posix/" 2>/dev/null; then
    echo "✅ ansible.posix installed"
else
    echo "❌ ansible.posix NOT installed"
    if [ "$HAVE_CONNECTIVITY" = true ]; then
        collections_missing=1
    fi
fi

if ls -la "$COLLECTIONS_DIR/ansible_collections/community/general/" 2>/dev/null; then
    echo "✅ community.general installed"
else
    echo "❌ community.general NOT installed"
    if [ "$HAVE_CONNECTIVITY" = true ]; then
        collections_missing=1
    fi
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

# Exit with error only if connectivity is working but collections are missing
if [ "$HAVE_CONNECTIVITY" = true ] && [ $collections_missing -eq 1 ]; then
    echo "Error: Some required collections are missing despite having connectivity!"
    exit 1
elif [ "$HAVE_CONNECTIVITY" = false ] && [ $collections_missing -eq 1 ]; then
    echo "Warning: Some collections are missing, but proceeding due to lack of connectivity"
    exit 0
fi
