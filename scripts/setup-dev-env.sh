#!/usr/bin/env bash

# Script to set up the development environment for ansible-ephemery

set -e

echo "Setting up ansible-ephemery development environment..."

# Install Python requirements
if [ -f requirements-dev.txt ]; then
    echo "Installing Python development requirements..."
    pip install -r requirements-dev.txt
fi

if [ -f requirements.txt ]; then
    echo "Installing Python requirements..."
    pip install -r requirements.txt
fi

# Install Ansible collections
if [ -f requirements.yaml ]; then
    echo "Installing Ansible collections..."
    ansible-galaxy collection install -r requirements.yaml
fi

# Install pre-commit hooks
if [ -f .pre-commit-config.yaml ]; then
    echo "Installing pre-commit hooks..."
    pre-commit install
fi

echo "Development environment setup complete!"
echo ""
echo "You can now run:"
echo "  ansible-lint to check for linting issues"
echo "  pre-commit run --all-files to run all pre-commit hooks" 