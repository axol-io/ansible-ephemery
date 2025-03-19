#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0

# Script to generate inventory files with standardized naming convention

# Set default values
TEMPLATE_TYPE="local"
OUTPUT_FILE=""
INVENTORY_NAME=""
BASE_DIR="${HOME}/ephemery"
DATA_DIR="${HOME}/ephemery/data"
LOGS_DIR="${HOME}/ephemery/logs"
GETH_IMAGE="ethereum/client-go:latest"
GETH_CACHE="4096"
GETH_MAX_PEERS="25"
LIGHTHOUSE_IMAGE="sigp/lighthouse:latest"
LIGHTHOUSE_TARGET_PEERS="30"
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PORT="22"
ENABLE_VALIDATOR=false
ENABLE_MONITORING=false
ENABLE_DASHBOARD=false
USE_RELATIVE_PATHS=false

# Function to display usage
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Generate an inventory file from a template with standardized naming"
  echo ""
  echo "Options:"
  echo "  --type TYPE             Template type (local or remote) (default: local)"
  echo "  --output FILE           Custom output file path (optional)"
  echo "  --name NAME             Base name for inventory file (default: type name)"
  echo "  --base-dir DIR          Base directory for Ephemery (default: ${HOME}/ephemery)"
  echo "  --data-dir DIR          Data directory (default: \$BASE_DIR/data)"
  echo "  --logs-dir DIR          Logs directory (default: \$BASE_DIR/logs)"
  echo "  --geth-image IMAGE      Geth Docker image (default: ethereum/client-go:latest)"
  echo "  --geth-cache SIZE       Geth cache size in MB (default: 4096)"
  echo "  --geth-max-peers NUM    Geth max peers (default: 25)"
  echo "  --lighthouse-image IMG  Lighthouse Docker image (default: sigp/lighthouse:latest)"
  echo "  --lighthouse-peers NUM  Lighthouse target peers (default: 30)"
  echo "  --remote-host HOST      Remote host (required for remote type)"
  echo "  --remote-user USER      Remote user (required for remote type)"
  echo "  --remote-port PORT      Remote SSH port (default: 22)"
  echo "  --enable-validator      Enable validator support"
  echo "  --enable-monitoring     Enable sync monitoring"
  echo "  --enable-dashboard      Enable web dashboard"
  echo "  --use-relative-paths    Use relative paths for data directories"
  echo "  --help                  Display this help and exit"
  echo ""
  echo "Example local inventory:"
  echo "  $0 --type local --name my-local --base-dir /data/ephemery"
  echo "  # Generates: my-local-inventory-YYYY-MM-DD-HH-MM.yaml"
  echo ""
  echo "Example remote inventory:"
  echo "  $0 --type remote --name production --remote-host example.com --remote-user admin"
  echo "  # Generates: production-inventory-YYYY-MM-DD-HH-MM.yaml"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --type)
      TEMPLATE_TYPE="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --name)
      INVENTORY_NAME="$2"
      shift 2
      ;;
    --base-dir)
      BASE_DIR="$2"
      shift 2
      ;;
    --data-dir)
      DATA_DIR="$2"
      shift 2
      ;;
    --logs-dir)
      LOGS_DIR="$2"
      shift 2
      ;;
    --geth-image)
      GETH_IMAGE="$2"
      shift 2
      ;;
    --geth-cache)
      GETH_CACHE="$2"
      shift 2
      ;;
    --geth-max-peers)
      GETH_MAX_PEERS="$2"
      shift 2
      ;;
    --lighthouse-image)
      LIGHTHOUSE_IMAGE="$2"
      shift 2
      ;;
    --lighthouse-peers)
      LIGHTHOUSE_TARGET_PEERS="$2"
      shift 2
      ;;
    --remote-host)
      REMOTE_HOST="$2"
      shift 2
      ;;
    --remote-user)
      REMOTE_USER="$2"
      shift 2
      ;;
    --remote-port)
      REMOTE_PORT="$2"
      shift 2
      ;;
    --enable-validator)
      ENABLE_VALIDATOR=true
      shift
      ;;
    --enable-monitoring)
      ENABLE_MONITORING=true
      shift
      ;;
    --enable-dashboard)
      ENABLE_DASHBOARD=true
      shift
      ;;
    --use-relative-paths)
      USE_RELATIVE_PATHS=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option $1" >&2
      usage
      exit 1
      ;;
  esac
done

# Validate template type
if [ "${TEMPLATE_TYPE}" != "local" ] && [ "${TEMPLATE_TYPE}" != "remote" ]; then
  echo "Error: Template type must be 'local' or 'remote'" >&2
  usage
  exit 1
fi

# Validate remote parameters if template type is remote
if [ "${TEMPLATE_TYPE}" = "remote" ]; then
  if [ -z "${REMOTE_HOST}" ] || [ -z "${REMOTE_USER}" ]; then
    echo "Error: Remote host and user are required for remote template type" >&2
    usage
    exit 1
  fi
fi

# Set default inventory name if not provided
if [ -z "${INVENTORY_NAME}" ]; then
  INVENTORY_NAME="${TEMPLATE_TYPE}"
fi

# Generate standardized filename with timestamp if output file not specified
if [ -z "${OUTPUT_FILE}" ]; then
  TIMESTAMP=$(date +"%Y-%m-%d-%H-%M")
  OUTPUT_FILE="$(pwd)/${INVENTORY_NAME}-inventory-${TIMESTAMP}.yaml"
fi

# Set paths based on whether relative paths are requested
if [ "${USE_RELATIVE_PATHS}" = true ]; then
  # Extract output directory
  OUTPUT_DIR=$(dirname "${OUTPUT_FILE}")
  
  # Make paths relative to the output directory
  REL_DATA_DIR="./data"
  REL_LOGS_DIR="./logs"
  REL_BASE_DIR="."
else
  # Use absolute paths
  REL_DATA_DIR="${DATA_DIR}"
  REL_LOGS_DIR="${LOGS_DIR}"
  REL_BASE_DIR="${BASE_DIR}"
fi

# Generate the inventory file
if [ "${TEMPLATE_TYPE}" = "local" ]; then
  # Generate local inventory file with Ansible-compatible format
  cat >"${OUTPUT_FILE}" <<EOF
# Local Ephemery Node Configuration
# Generated on: $(date)
all:
  children:
    ephemery:
      hosts:
        localhost:
          ansible_connection: local
      vars:
        # Base directory for Ephemery
        ephemery_base_dir: "${REL_BASE_DIR}"
        jwt_secret_path: "${REL_BASE_DIR}/jwt.hex"

        # Directories structure
        directories:
          base: "${REL_BASE_DIR}"
          data: "${REL_DATA_DIR}"
          secrets: "${REL_BASE_DIR}/secrets"
          logs: "${REL_LOGS_DIR}"
          scripts: "${REL_BASE_DIR}/scripts"
          backups: "${REL_BASE_DIR}/backups"

        # Security configuration
        security:
          jwt_secure_generation: true
          firewall_enabled: true
          firewall_default_policy: "deny"

        # Client selection
        clients:
          execution: "geth"
          consensus: "lighthouse"
          validator: "lighthouse"

          # Docker images
          images:
            geth: "${GETH_IMAGE}"
            lighthouse: "${LIGHTHOUSE_IMAGE}"
            validator: "${LIGHTHOUSE_IMAGE}"

        # Geth Configuration
        geth:
          config_dir: "${REL_DATA_DIR}/geth"
          cache: ${GETH_CACHE}
          max_peers: ${GETH_MAX_PEERS}
          extra_opts: "--txlookuplimit=0 --syncmode=snap"

        # Lighthouse Configuration
        lighthouse:
          config_dir: "${REL_DATA_DIR}/lighthouse"
          target_peers: ${LIGHTHOUSE_TARGET_PEERS}
          extra_opts: "--checkpoint-sync-url=https://checkpoint-sync.ephemery.ethpandaops.io --checkpoint-sync-url-timeout=300"

        # Sync configuration
        sync:
          use_checkpoint: true
          checkpoint_url: "https://checkpoint-sync.ephemery.ethpandaops.io"
          clear_database_on_start: true

        # Feature flags
        features:
          validator:
            enabled: ${ENABLE_VALIDATOR}
          monitoring:
            enabled: ${ENABLE_MONITORING}
          dashboard:
            enabled: ${ENABLE_DASHBOARD}
          backup:
            enabled: false

        # Network configuration
        network_mode: "host"
EOF
else
  # Generate remote inventory file with Ansible-compatible format
  cat >"${OUTPUT_FILE}" <<EOF
# Remote Ephemery Node Configuration
# Generated on: $(date)
all:
  children:
    ephemery:
      hosts:
        remote_host:
          ansible_host: ${REMOTE_HOST}
          ansible_user: ${REMOTE_USER}
          ansible_port: ${REMOTE_PORT}
      vars:
        # Base directory for Ephemery
        ephemery_base_dir: "${REL_BASE_DIR}"
        jwt_secret_path: "${REL_BASE_DIR}/jwt.hex"

        # Directories structure
        directories:
          base: "${REL_BASE_DIR}"
          data: "${REL_DATA_DIR}"
          secrets: "${REL_BASE_DIR}/secrets"
          logs: "${REL_LOGS_DIR}"
          scripts: "${REL_BASE_DIR}/scripts"
          backups: "${REL_BASE_DIR}/backups"

        # Security configuration
        security:
          jwt_secure_generation: true
          firewall_enabled: true
          firewall_default_policy: "deny"

        # Client selection
        clients:
          execution: "geth"
          consensus: "lighthouse"
          validator: "lighthouse"

          # Docker images
          images:
            geth: "${GETH_IMAGE}"
            lighthouse: "${LIGHTHOUSE_IMAGE}"
            validator: "${LIGHTHOUSE_IMAGE}"

        # Geth Configuration
        geth:
          config_dir: "${REL_DATA_DIR}/geth"
          cache: ${GETH_CACHE}
          max_peers: ${GETH_MAX_PEERS}
          extra_opts: "--txlookuplimit=0 --syncmode=snap"

        # Lighthouse Configuration
        lighthouse:
          config_dir: "${REL_DATA_DIR}/lighthouse"
          target_peers: ${LIGHTHOUSE_TARGET_PEERS}
          extra_opts: "--checkpoint-sync-url=https://checkpoint-sync.ephemery.ethpandaops.io --checkpoint-sync-url-timeout=300"

        # Sync configuration
        sync:
          use_checkpoint: true
          checkpoint_url: "https://checkpoint-sync.ephemery.ethpandaops.io"
          clear_database_on_start: true

        # Feature flags
        features:
          validator:
            enabled: ${ENABLE_VALIDATOR}
          monitoring:
            enabled: ${ENABLE_MONITORING}
          dashboard:
            enabled: ${ENABLE_DASHBOARD}
          backup:
            enabled: false

        # Network configuration
        network_mode: "host"
EOF
fi

echo "Inventory file generated: ${OUTPUT_FILE}"
exit 0
