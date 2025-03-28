#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
# check-yaml-extensions.sh
# Script to ensure YAML files use .yaml extension (except in molecule directory)
# This script is used as a pre-commit hook

set -euo pipefail

# Find all YAML files in the repository
yaml_files=$(git ls-files | grep -E '\.ya?ml$')

# Check each file
errors=0
for file in ${yaml_files}; do
  # Skip files in molecule directory
  if [[ ${file} == molecule/* ]]; then
    continue
  fi

  # Skip files in collections directory
  if [[ ${file} == collections/* ]]; then
    continue
  fi

  # Check if the file exists and has .yml extension
  if [[ -f "${file}" && ${file} == *.yml ]]; then
    echo "Error: ${file} uses .yml extension instead of .yaml"
    errors=$((errors + 1))
  fi
done

# Return error if any files with wrong extension were found
if [ ${errors} -gt 0 ]; then
  echo "Found ${errors} YAML files with incorrect extension."
  echo "Please rename them to use .yaml extension."
  exit 1
fi

exit 0
