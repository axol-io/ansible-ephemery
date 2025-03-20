#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: setup_test_env.sh
# Description: Setup the test environment
# Author: Ephemery Team
# Created: 2025-03-21
# Last Modified: 2025-03-21
#
# This script sets up the test environment by copying necessary library files
# to the testing/lib directory.

set -euo pipefail

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Create lib directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/lib"

# Copy required library files
echo "Setting up test environment..."

# Copy common library files
if [[ -f "${PROJECT_ROOT}/scripts/lib/common.sh" ]]; then
  echo "Copying common.sh to ${SCRIPT_DIR}/lib/"
  cp "${PROJECT_ROOT}/scripts/lib/common.sh" "${SCRIPT_DIR}/lib/"
else
  echo "Warning: common.sh not found in ${PROJECT_ROOT}/scripts/lib/"
fi

if [[ -f "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" ]]; then
  echo "Copying common_consolidated.sh to ${SCRIPT_DIR}/lib/"
  cp "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" "${SCRIPT_DIR}/lib/"
else
  echo "Warning: common_consolidated.sh not found in ${PROJECT_ROOT}/scripts/lib/"
fi

if [[ -f "${PROJECT_ROOT}/scripts/lib/test_config.sh" ]]; then
  echo "Copying test_config.sh to ${SCRIPT_DIR}/lib/"
  cp "${PROJECT_ROOT}/scripts/lib/test_config.sh" "${SCRIPT_DIR}/lib/"
else
  echo "Warning: test_config.sh not found in ${PROJECT_ROOT}/scripts/lib/"
fi

# Copy any other necessary library files
for file in "${PROJECT_ROOT}/scripts/lib/"*.sh; do
  if [[ -f "$file" ]]; then
    filename=$(basename "$file")
    if [[ ! -f "${SCRIPT_DIR}/lib/$filename" ]]; then
      echo "Copying $filename to ${SCRIPT_DIR}/lib/"
      cp "$file" "${SCRIPT_DIR}/lib/"
    fi
  fi
done

# Create README if it doesn't exist
if [[ ! -f "${SCRIPT_DIR}/lib/README.md" ]]; then
  cat > "${SCRIPT_DIR}/lib/README.md" << EOF
# Testing Library Directory

This directory contains local copies of common library files needed for the testing framework.

## Purpose

These files are maintained to ensure that tests can run properly in both development and CI environments. The test scripts will first look for library files in this directory, then fall back to the main scripts/lib directory.

## Files

- \`common.sh\`: Main common functions library
- \`common_consolidated.sh\`: Consolidated common library with all functions
- \`test_config.sh\`: Configuration for test environment

## CI Environment 

In the CI environment, these files are automatically copied from the main scripts/lib directory during the build process. This ensures that tests can run in isolation without depending on the global directory structure.

## Local Development

When developing locally, you may not see these files as they are automatically copied at runtime if needed. You can manually copy them from the main scripts/lib directory if you want to examine them.

## Updating

When making changes to the common library files, always update the main scripts/lib versions. The files in this directory are just copies and will be overwritten during test runs.
EOF
  echo "Created README.md in ${SCRIPT_DIR}/lib/"
fi

# Make the script executable
chmod +x "${SCRIPT_DIR}/run_tests.sh"
chmod +x "${SCRIPT_DIR}/ci_check.sh"

echo "Test environment setup complete!"
echo "You can now run tests using:"
echo "  ${SCRIPT_DIR}/run_tests.sh"
echo "Or run the CI check using:"
echo "  ${SCRIPT_DIR}/ci_check.sh" 