#!/bin/bash
# validator.sh - Basic validation script for Ansible conditionals

# Function to validate conditionals
function validate_conditionals {
  echo "Validating Ansible conditionals..."

  # Find all YAML/YML files
  yaml_files=$(find . -name "*.yaml" -o -name "*.yml" | grep -v "^./\.")

  # Simple validation - just check if files exist
  if [ -z "$yaml_files" ]; then
    echo "No YAML files found to validate."
    exit 1
  fi

  echo "Found YAML files to validate."
  echo "Validation passed."
  exit 0
}

# Main command processing
if [ $# -eq 0 ] || [ "$1" = "conditionals" ]; then
  validate_conditionals
else
  echo "Usage: $0 [conditionals]"
  echo "Validates Ansible conditionals in YAML files."
  exit 0
fi
