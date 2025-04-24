#!/bin/bash

# Simple test script to check for issues with library imports

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Testing library import..."
echo "Project root: ${PROJECT_ROOT}"

# Attempt to source each library file individually
echo "Sourcing common.sh..."
if [[ -f "${PROJECT_ROOT}/scripts/lib/common.sh" ]]; then
  source "${PROJECT_ROOT}/scripts/lib/common.sh" && echo "Success!" || echo "Failed!"
else
  echo "File not found!"
fi

echo "Sourcing common_basic.sh..."
if [[ -f "${PROJECT_ROOT}/scripts/lib/common_basic.sh" ]]; then
  source "${PROJECT_ROOT}/scripts/lib/common_basic.sh" && echo "Success!" || echo "Failed!"
else
  echo "File not found!"
fi

echo "Sourcing common_consolidated.sh..."
if [[ -f "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" ]]; then
  source "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" && echo "Success!" || echo "Failed!"
else
  echo "File not found!"
fi

echo "Testing complete"
