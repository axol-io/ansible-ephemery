#!/bin/bash

# Ephemery Path Configuration Script
# This script provides standardized path management for all Ephemery scripts
# Version: 1.0.0

# Initialize variable before use to avoid "unbound variable" error
: "${_EPHEMERY_PATH_CONFIG_LOADED:=}"

# Prevent sourcing more than once
[[ -n "${_EPHEMERY_PATH_CONFIG_LOADED}" ]] && return 0
readonly _EPHEMERY_PATH_CONFIG_LOADED=1

# Default environment if not specified
EPHEMERY_ENVIRONMENT="${EPHEMERY_ENVIRONMENT:-default}"
EPHEMERY_NETWORK="${EPHEMERY_NETWORK:-ephemery}"

# Base directories for different environments - using simpler approach for compatibility
# Default production path
DEFAULT_BASE_DIR="/opt/ephemery"
# Development environment path
DEV_BASE_DIR="${HOME}/ephemery"
# Testing environment path
TEST_BASE_DIR="/tmp/ephemery"

# Set base directory based on environment
case "${EPHEMERY_ENVIRONMENT}" in
  development) EPHEMERY_BASE_DIR="${EPHEMERY_BASE_DIR:-${DEV_BASE_DIR}}" ;;
  testing) EPHEMERY_BASE_DIR="${EPHEMERY_BASE_DIR:-${TEST_BASE_DIR}}" ;;
  *) EPHEMERY_BASE_DIR="${EPHEMERY_BASE_DIR:-${DEFAULT_BASE_DIR}}" ;;
esac

# Standard directory paths
EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"
EPHEMERY_SCRIPTS_DIR="${EPHEMERY_BASE_DIR}/scripts"
EPHEMERY_SECRETS_DIR="${EPHEMERY_BASE_DIR}/secrets"

# Client-specific data directories
EPHEMERY_GETH_DATA_DIR="${EPHEMERY_DATA_DIR}/geth"
EPHEMERY_LIGHTHOUSE_DATA_DIR="${EPHEMERY_DATA_DIR}/lighthouse"
EPHEMERY_VALIDATOR_DATA_DIR="${EPHEMERY_DATA_DIR}/lighthouse-validator"
EPHEMERY_VALIDATOR_KEYS_DIR="${EPHEMERY_DATA_DIR}/validator-keys"

# File paths
EPHEMERY_JWT_SECRET="${EPHEMERY_JWT_SECRET:-${EPHEMERY_BASE_DIR}/jwt.hex}"
EPHEMERY_PATHS_CONFIG="${EPHEMERY_CONFIG_DIR}/ephemery_paths.conf"
EPHEMERY_GETH_CONFIG="${EPHEMERY_CONFIG_DIR}/geth.toml"
EPHEMERY_LIGHTHOUSE_CONFIG="${EPHEMERY_CONFIG_DIR}/lighthouse.toml"
EPHEMERY_VALIDATOR_CONFIG="${EPHEMERY_CONFIG_DIR}/validator.toml"
EPHEMERY_PROMETHEUS_CONFIG="${EPHEMERY_CONFIG_DIR}/prometheus.yaml"

# Docker settings
EPHEMERY_DOCKER_NETWORK="${EPHEMERY_DOCKER_NETWORK:-ephemery-net}"

# Container naming convention based on network and client type
# This standardizes naming to follow the pattern: {network}-{role}-{client}
# For example: ephemery-execution-geth, ephemery-consensus-lighthouse, ephemery-validator-lighthouse
# This replaces inconsistent naming like ephemery-geth, ephemery-lighthouse, ephemery-validator-lighthouse
EPHEMERY_EXECUTION_CLIENT="${EPHEMERY_EXECUTION_CLIENT:-geth}"
EPHEMERY_CONSENSUS_CLIENT="${EPHEMERY_CONSENSUS_CLIENT:-lighthouse}"
EPHEMERY_VALIDATOR_CLIENT="${EPHEMERY_VALIDATOR_CLIENT:-lighthouse}"

EPHEMERY_EXECUTION_CONTAINER="${EPHEMERY_NETWORK}-execution-${EPHEMERY_EXECUTION_CLIENT}"
EPHEMERY_CONSENSUS_CONTAINER="${EPHEMERY_NETWORK}-consensus-${EPHEMERY_CONSENSUS_CLIENT}"
EPHEMERY_VALIDATOR_CONTAINER="${EPHEMERY_NETWORK}-validator-${EPHEMERY_VALIDATOR_CLIENT}"

# For backward compatibility - these will be deprecated in future versions
EPHEMERY_GETH_CONTAINER="${EPHEMERY_EXECUTION_CONTAINER}"
EPHEMERY_LIGHTHOUSE_CONTAINER="${EPHEMERY_CONSENSUS_CONTAINER}"

# Export all variables
export EPHEMERY_ENVIRONMENT
export EPHEMERY_NETWORK
export EPHEMERY_BASE_DIR
export EPHEMERY_CONFIG_DIR
export EPHEMERY_DATA_DIR
export EPHEMERY_LOGS_DIR
export EPHEMERY_SCRIPTS_DIR
export EPHEMERY_SECRETS_DIR
export EPHEMERY_GETH_DATA_DIR
export EPHEMERY_LIGHTHOUSE_DATA_DIR
export EPHEMERY_VALIDATOR_DATA_DIR
export EPHEMERY_VALIDATOR_KEYS_DIR
export EPHEMERY_JWT_SECRET
export EPHEMERY_PATHS_CONFIG
export EPHEMERY_GETH_CONFIG
export EPHEMERY_LIGHTHOUSE_CONFIG
export EPHEMERY_VALIDATOR_CONFIG
export EPHEMERY_PROMETHEUS_CONFIG
export EPHEMERY_DOCKER_NETWORK
export EPHEMERY_EXECUTION_CLIENT
export EPHEMERY_CONSENSUS_CLIENT
export EPHEMERY_VALIDATOR_CLIENT
export EPHEMERY_EXECUTION_CONTAINER
export EPHEMERY_CONSENSUS_CONTAINER
export EPHEMERY_VALIDATOR_CONTAINER
export EPHEMERY_GETH_CONTAINER
export EPHEMERY_LIGHTHOUSE_CONTAINER

# Function to generate paths configuration file for persistent storage
generate_paths_config() {
  local output_file="${1:-${EPHEMERY_PATHS_CONFIG}}"
  local config_dir="$(dirname "${output_file}")"

  # Create directory if it doesn't exist
  mkdir -p "${config_dir}"

  # Generate configuration file
  cat >"${output_file}" <<EOF
# Ephemery paths configuration
# Generated on $(date)
# WARNING: This file is automatically generated. Manual changes will be overwritten.

# Environment
EPHEMERY_ENVIRONMENT="${EPHEMERY_ENVIRONMENT}"
EPHEMERY_NETWORK="${EPHEMERY_NETWORK}"

# Base directories
EPHEMERY_BASE_DIR="${EPHEMERY_BASE_DIR}"
EPHEMERY_CONFIG_DIR="${EPHEMERY_CONFIG_DIR}"
EPHEMERY_DATA_DIR="${EPHEMERY_DATA_DIR}"
EPHEMERY_LOGS_DIR="${EPHEMERY_LOGS_DIR}"
EPHEMERY_SCRIPTS_DIR="${EPHEMERY_SCRIPTS_DIR}"
EPHEMERY_SECRETS_DIR="${EPHEMERY_SECRETS_DIR}"

# Client-specific data directories
EPHEMERY_GETH_DATA_DIR="${EPHEMERY_GETH_DATA_DIR}"
EPHEMERY_LIGHTHOUSE_DATA_DIR="${EPHEMERY_LIGHTHOUSE_DATA_DIR}"
EPHEMERY_VALIDATOR_DATA_DIR="${EPHEMERY_VALIDATOR_DATA_DIR}"
EPHEMERY_VALIDATOR_KEYS_DIR="${EPHEMERY_VALIDATOR_KEYS_DIR}"

# File paths
EPHEMERY_JWT_SECRET="${EPHEMERY_JWT_SECRET}"
EPHEMERY_PATHS_CONFIG="${EPHEMERY_PATHS_CONFIG}"
EPHEMERY_GETH_CONFIG="${EPHEMERY_GETH_CONFIG}"
EPHEMERY_LIGHTHOUSE_CONFIG="${EPHEMERY_LIGHTHOUSE_CONFIG}"
EPHEMERY_VALIDATOR_CONFIG="${EPHEMERY_VALIDATOR_CONFIG}"
EPHEMERY_PROMETHEUS_CONFIG="${EPHEMERY_PROMETHEUS_CONFIG}"

# Docker settings
EPHEMERY_DOCKER_NETWORK="${EPHEMERY_DOCKER_NETWORK}"

# Client configuration
EPHEMERY_EXECUTION_CLIENT="${EPHEMERY_EXECUTION_CLIENT}"
EPHEMERY_CONSENSUS_CLIENT="${EPHEMERY_CONSENSUS_CLIENT}"
EPHEMERY_VALIDATOR_CLIENT="${EPHEMERY_VALIDATOR_CLIENT}"

# Container names
EPHEMERY_EXECUTION_CONTAINER="${EPHEMERY_EXECUTION_CONTAINER}"
EPHEMERY_CONSENSUS_CONTAINER="${EPHEMERY_CONSENSUS_CONTAINER}"
EPHEMERY_VALIDATOR_CONTAINER="${EPHEMERY_VALIDATOR_CONTAINER}"

# Legacy container names (for backward compatibility)
EPHEMERY_GETH_CONTAINER="${EPHEMERY_GETH_CONTAINER}"
EPHEMERY_LIGHTHOUSE_CONTAINER="${EPHEMERY_LIGHTHOUSE_CONTAINER}"
EOF

  chmod 644 "${output_file}"
  echo "Generated paths configuration at ${output_file}"
}

# Create a function to ensure all standard directories exist
ensure_directories() {
  mkdir -p "${EPHEMERY_CONFIG_DIR}"
  mkdir -p "${EPHEMERY_DATA_DIR}"
  mkdir -p "${EPHEMERY_GETH_DATA_DIR}"
  mkdir -p "${EPHEMERY_LIGHTHOUSE_DATA_DIR}"
  mkdir -p "${EPHEMERY_LOGS_DIR}"
  mkdir -p "${EPHEMERY_SCRIPTS_DIR}"
  mkdir -p "${EPHEMERY_SECRETS_DIR}"
  mkdir -p "${EPHEMERY_VALIDATOR_KEYS_DIR}"
}

# Create a function to get a path by name
get_path() {
  local path_name="$1"

  case "${path_name}" in
    base) echo "${EPHEMERY_BASE_DIR}" ;;
    config) echo "${EPHEMERY_CONFIG_DIR}" ;;
    data) echo "${EPHEMERY_DATA_DIR}" ;;
    logs) echo "${EPHEMERY_LOGS_DIR}" ;;
    scripts) echo "${EPHEMERY_SCRIPTS_DIR}" ;;
    secrets) echo "${EPHEMERY_SECRETS_DIR}" ;;
    geth) echo "${EPHEMERY_GETH_DATA_DIR}" ;;
    lighthouse) echo "${EPHEMERY_LIGHTHOUSE_DATA_DIR}" ;;
    validator) echo "${EPHEMERY_VALIDATOR_DATA_DIR}" ;;
    keys) echo "${EPHEMERY_VALIDATOR_KEYS_DIR}" ;;
    jwt) echo "${EPHEMERY_JWT_SECRET}" ;;
    *) echo "${EPHEMERY_BASE_DIR}/${path_name}" ;;
  esac
}

# If this script is executed directly, generate the config file
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Parse command line arguments
  output_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output | -o)
        output_file="$2"
        shift 2
        ;;
      --help | -h)
        echo "Usage: $0 [--output FILE]"
        echo "Generate standardized path configuration for Ephemery"
        echo ""
        echo "Options:"
        echo "  --output, -o FILE   Specify output file (default: ${EPHEMERY_PATHS_CONFIG})"
        echo "  --help, -h          Show this help message"
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done

  # Generate configuration file
  generate_paths_config "${output_file}"
fi
