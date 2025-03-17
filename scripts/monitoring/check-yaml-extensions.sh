#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
# Script to check for YAML files with inconsistent extensions
# (excluding the molecule directory where .yml is standard)

echo "Checking YAML file extensions for consistency..."
echo "Rule: Use .yaml extension except in molecule/ directory"
echo ""

# Check for .yml files outside the molecule directory and collections directory
yml_files=$(find . -name "*.yml" -not -path "./molecule/*" -not -path "./.github/*" -not -path "./collections/*" | sort)

if [ -n "${yml_files}" ]; then
  echo "Found .yml files outside the molecule directory:"
  echo "${yml_files}"
  echo ""
  echo "These files should use .yaml extension instead. To fix them, run:"
  echo "./scripts/fix-yaml-extensions.sh"
else
  echo "✅ No inconsistent .yml files found outside the molecule directory."
fi

# Check for .yaml files inside the molecule directory
yaml_files=$(find ./molecule -name "*.yaml" | sort)

if [ -n "${yaml_files}" ]; then
  echo "Found .yaml files inside the molecule directory:"
  echo "${yaml_files}"
  echo ""
  echo "These files should use .yml extension instead. To fix them, run:"
  echo "./scripts/fix-yaml-extensions.sh --reverse"
else
  echo "✅ No inconsistent .yaml files found inside the molecule directory."
fi

# Summary
if [ -n "${yml_files}" ] || [ -n "${yaml_files}" ]; then
  echo ""
  echo "❌ Found inconsistent YAML file extensions."
  exit 1
else
  echo ""
  echo "✅ All YAML file extensions are consistent with the coding standards."
  exit 0
fi
