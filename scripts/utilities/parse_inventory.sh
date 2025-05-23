#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0

# Utility script to parse YAML inventory files
# This script can be used by both local and remote deployment scripts

# Function to check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Function to parse local inventory file
parse_local_inventory() {
  local inventory_file="$1"

  if [ ! -f "${inventory_file}" ]; then
    echo "Error: Inventory file '${inventory_file}' not found" >&2
    return 1
  fi

  # Check if yq is available
  if command_exists yq; then
    # Parse with yq
    BASE_DIR=$(yq '.local.base_dir // ""' "${inventory_file}" | tr -d '"')
    DATA_DIR=$(yq '.local.data_dir // ""' "${inventory_file}" | tr -d '"')
    LOGS_DIR=$(yq '.local.logs_dir // ""' "${inventory_file}" | tr -d '"')

    # Geth configuration
    GETH_IMAGE=$(yq '.local.geth.image // ""' "${inventory_file}" | tr -d '"')
    GETH_CACHE=$(yq '.local.geth.cache // ""' "${inventory_file}" | tr -d '"')
    GETH_MAX_PEERS=$(yq '.local.geth.max_peers // ""' "${inventory_file}" | tr -d '"')

    # Lighthouse configuration
    LIGHTHOUSE_IMAGE=$(yq '.local.lighthouse.image // ""' "${inventory_file}" | tr -d '"')
    LIGHTHOUSE_TARGET_PEERS=$(yq '.local.lighthouse.target_peers // ""' "${inventory_file}" | tr -d '"')
  else
    echo "Warning: 'yq' command not found. Using fallback method with grep (less reliable)" >&2

    # Fallback to grep (less reliable)
    BASE_DIR=$(grep -o 'base_dir:.*' "${inventory_file}" | head -1 | cut -d: -f2 | tr -d ' ')
    DATA_DIR=$(grep -o 'data_dir:.*' "${inventory_file}" | head -1 | cut -d: -f2 | tr -d ' ')
    LOGS_DIR=$(grep -o 'logs_dir:.*' "${inventory_file}" | head -1 | cut -d: -f2 | tr -d ' ')

    # Geth configuration - use awk for better handling of image references with colons
    GETH_IMAGE=$(awk -F 'image: ' '/geth:/{print $2}' "${inventory_file}" | head -1 | tr -d ' ')
    GETH_CACHE=$(grep -o 'cache:.*' "${inventory_file}" | head -1 | cut -d: -f2 | tr -d ' ')
    GETH_MAX_PEERS=$(grep -o 'max_peers:.*' "${inventory_file}" | head -1 | cut -d: -f2 | tr -d ' ')

    # Lighthouse configuration - use awk for better handling of image references with colons
    LIGHTHOUSE_IMAGE=$(awk -F 'image: ' '/lighthouse:/{print $2}' "${inventory_file}" | head -1 | tr -d ' ')
    LIGHTHOUSE_TARGET_PEERS=$(grep -o 'target_peers:.*' "${inventory_file}" | head -1 | cut -d: -f2 | tr -d ' ')
  fi

  # Export variables
  EPHEMERY_BASE_DIR="${BASE_DIR}"
  export EPHEMERY_BASE_DIR

  EPHEMERY_DATA_DIR="${DATA_DIR}"
  export EPHEMERY_DATA_DIR

  EPHEMERY_LOGS_DIR="${LOGS_DIR}"
  export EPHEMERY_LOGS_DIR

  GETH_IMAGE="${GETH_IMAGE}"
  export GETH_IMAGE

  export GETH_CACHE="${GETH_CACHE}"
  export GETH_MAX_PEERS="${GETH_MAX_PEERS}"

  LIGHTHOUSE_IMAGE="${LIGHTHOUSE_IMAGE}"
  export LIGHTHOUSE_IMAGE

  export LIGHTHOUSE_TARGET_PEERS="${LIGHTHOUSE_TARGET_PEERS}"

  echo "Inventory parsed successfully"
  return 0
}

# Function to parse remote inventory file
parse_remote_inventory() {
  local inventory_file="$1"

  if [ ! -f "${inventory_file}" ]; then
    echo "Error: Inventory file '${inventory_file}' not found" >&2
    return 1
  fi

  # Check if yq is available
  if command_exists yq; then
    # Parse with yq
    REMOTE_HOST=$(yq '.hosts[0].host // ""' "${inventory_file}" | tr -d '"')
    REMOTE_USER=$(yq '.hosts[0].user // ""' "${inventory_file}" | tr -d '"')
    REMOTE_PORT=$(yq '.hosts[0].port // "22"' "${inventory_file}" | tr -d '"')
  else
    echo "Warning: 'yq' command not found. Using fallback method with grep (less reliable)" >&2

    # Fallback to grep (less reliable)
    REMOTE_HOST=$(grep -o 'host:.*' "${inventory_file}" | head -1 | cut -d: -f2 | tr -d ' ' | tr -d '"')
    REMOTE_USER=$(grep -o 'user:.*' "${inventory_file}" | head -1 | cut -d: -f2 | tr -d ' ' | tr -d '"')
    REMOTE_PORT=$(grep -o 'port:.*' "${inventory_file}" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ' | tr -d '"' || echo "22")
  fi

  # Validate extracted values
  if [ -z "${REMOTE_HOST}" ] || [ -z "${REMOTE_USER}" ]; then
    echo "Error: Could not extract host and user from inventory file" >&2
    return 1
  fi

  # Export variables
  export REMOTE_HOST="${REMOTE_HOST}"
  export REMOTE_USER="${REMOTE_USER}"
  export REMOTE_PORT="${REMOTE_PORT}"

  echo "Inventory parsed successfully"
  return 0
}

# If script is executed directly, show usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script is meant to be sourced by other scripts, not executed directly."
  echo "Usage:"
  echo "  source $(basename "$0")"
  echo "  parse_local_inventory path/to/inventory.yaml"
  echo "  # or"
  echo "  parse_remote_inventory path/to/inventory.yaml"
  exit 1
fi
