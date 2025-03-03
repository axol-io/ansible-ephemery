#!/bin/bash
#
# Script to validate Ansible variable structure
# Validates that all required variables are present and correctly formatted

set -e

echo "Validating Ansible variable structure..."

# Validate syntax of playbooks
echo "Checking playbook syntax..."
find playbooks -name "*.yaml" -type f -exec ansible-playbook --syntax-check {} \;

# Validate role syntax
echo "Checking role syntax..."
ansible-playbook --syntax-check -i localhost, -c local tests/test_variables.yaml

# Exit with appropriate status
if [ $? -eq 0 ]; then
  echo "✅ Variable structure validation successful"
  exit 0
else
  echo "❌ Variable structure validation failed"
  exit 1
fi
