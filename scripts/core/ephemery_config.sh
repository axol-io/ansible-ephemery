#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0

# Ephemery Common Configuration File
# This file contains common configuration settings for all Ephemery scripts

# Load standardized paths configuration
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "${CONFIG_FILE}" ]; then
  source "${CONFIG_FILE}"
else
  echo "Configuration file not found at ${CONFIG_FILE}, using fallback paths"

  # Fallback paths if config file isn't found
  EPHEMERY_BASE_DIR=~/ephemery
  EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
  EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"
  EPHEMERY_SECRETS_DIR="${EPHEMERY_BASE_DIR}/secrets"
  EPHEMERY_SCRIPTS_DIR="${EPHEMERY_BASE_DIR}/scripts"

  # Validator paths
  EPHEMERY_VALIDATOR_KEYS_DIR="${EPHEMERY_DATA_DIR}/validator_keys"
  EPHEMERY_VALIDATOR_PASSWORDS_DIR="${EPHEMERY_SECRETS_DIR}/validator_passwords"
  EPHEMERY_VALIDATOR_BACKUP_DIR="${EPHEMERY_BASE_DIR}/backups/validator_keys"

  # Container configuration
  EPHEMERY_DOCKER_NETWORK="ephemery-net"
  EPHEMERY_GETH_CONTAINER="ephemery-geth"
  EPHEMERY_LIGHTHOUSE_CONTAINER="ephemery-lighthouse"
  EPHEMERY_VALIDATOR_CONTAINER="ephemery-validator"

  # Checkpoint sync configuration
  EPHEMERY_CHECKPOINT_SYNC_ENABLED=true
  EPHEMERY_CHECKPOINT_SYNC_URL_FILE="${EPHEMERY_CONFIG_DIR}/checkpoint_sync_url.txt"
  EPHEMERY_DEFAULT_CHECKPOINT_URLS=(
    "https://checkpoint-sync.ephemery.dev"
    "https://checkpoint-sync.ephemery.ethpandaops.io"
    "https://checkpoint.ephemery.eth.limo"
  )
fi

# Visual formatting

# Docker configuration
EPHEMERY_DOCKER_NETWORK=${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"}
EPHEMERY_LIGHTHOUSE_IMAGE=${EPHEMERY_LIGHTHOUSE_IMAGE:-"pk910/ephemery-lighthouse:latest"}
EPHEMERY_GETH_IMAGE=${EPHEMERY_GETH_IMAGE:-"pk910/ephemery-geth:latest"}

# Container names
EPHEMERY_GETH_CONTAINER=${EPHEMERY_GETH_CONTAINER:-"ephemery-geth"}
EPHEMERY_LIGHTHOUSE_CONTAINER=${EPHEMERY_LIGHTHOUSE_CONTAINER:-"ephemery-lighthouse"}
EPHEMERY_VALIDATOR_CONTAINER=${EPHEMERY_VALIDATOR_CONTAINER:-"ephemery-validator"}

# Port mappings
EPHEMERY_GETH_HTTP_PORT=${EPHEMERY_GETH_HTTP_PORT:-8545}
EPHEMERY_GETH_WS_PORT=${EPHEMERY_GETH_WS_PORT:-8546}
EPHEMERY_GETH_AUTH_PORT=${EPHEMERY_GETH_AUTH_PORT:-8551}
EPHEMERY_GETH_METRICS_PORT=${EPHEMERY_GETH_METRICS_PORT:-6060}
EPHEMERY_LIGHTHOUSE_HTTP_PORT=${EPHEMERY_LIGHTHOUSE_HTTP_PORT:-5052}
EPHEMERY_LIGHTHOUSE_METRICS_PORT=${EPHEMERY_LIGHTHOUSE_METRICS_PORT:-5054}
EPHEMERY_VALIDATOR_METRICS_PORT=${EPHEMERY_VALIDATOR_METRICS_PORT:-5064}

# Network settings
EPHEMERY_TARGET_PEERS=${EPHEMERY_TARGET_PEERS:-100}
EPHEMERY_P2P_ENABLED=${EPHEMERY_P2P_ENABLED:-true}

# Directory structure
EPHEMERY_DATA_DIR=${EPHEMERY_DATA_DIR:-"${EPHEMERY_BASE_DIR}/data"}
EPHEMERY_CONFIG_DIR=${EPHEMERY_CONFIG_DIR:-"${EPHEMERY_BASE_DIR}/config"}
EPHEMERY_LOGS_DIR=${EPHEMERY_LOGS_DIR:-"${EPHEMERY_BASE_DIR}/logs"}
EPHEMERY_SECRETS_DIR=${EPHEMERY_SECRETS_DIR:-"${EPHEMERY_BASE_DIR}/secrets"}

# Client data directories
EPHEMERY_GETH_DIR=${EPHEMERY_GETH_DIR:-"${EPHEMERY_DATA_DIR}/geth"}
EPHEMERY_LIGHTHOUSE_DIR=${EPHEMERY_LIGHTHOUSE_DIR:-"${EPHEMERY_DATA_DIR}/lighthouse"}
EPHEMERY_LIGHTHOUSE_VALIDATOR_DIR=${EPHEMERY_LIGHTHOUSE_VALIDATOR_DIR:-"${EPHEMERY_DATA_DIR}/lighthouse-validator"}

# Validator configuration
EPHEMERY_VALIDATOR_KEYS_DIR=${EPHEMERY_VALIDATOR_KEYS_DIR:-"${EPHEMERY_DATA_DIR}/validator-keys"}
EPHEMERY_VALIDATOR_PASSWORDS_DIR=${EPHEMERY_VALIDATOR_PASSWORDS_DIR:-"${EPHEMERY_SECRETS_DIR}/validator-passwords"}
EPHEMERY_FEE_RECIPIENT=${EPHEMERY_FEE_RECIPIENT:-"0x0000000000000000000000000000000000000000"}

# JWT Secret
EPHEMERY_JWT_SECRET_PATH=${EPHEMERY_JWT_SECRET_PATH:-"${EPHEMERY_SECRETS_DIR}/jwt-secret"}

# Checkpoint sync
EPHEMERY_CHECKPOINT_SYNC_ENABLED=${EPHEMERY_CHECKPOINT_SYNC_ENABLED:-true}
EPHEMERY_CHECKPOINT_SYNC_URL=${EPHEMERY_CHECKPOINT_SYNC_URL:-""}
EPHEMERY_CHECKPOINT_URL_FILE=${EPHEMERY_CHECKPOINT_URL_FILE:-"${EPHEMERY_BASE_DIR}/checkpoint_url.txt"}

# Backup configuration
EPHEMERY_BACKUP_DIR=${EPHEMERY_BACKUP_DIR:-~/ephemery_backups}

# Health check thresholds
EPHEMERY_DISK_SPACE_THRESHOLD=${EPHEMERY_DISK_SPACE_THRESHOLD:-10} # GB
EPHEMERY_PEER_COUNT_THRESHOLD=${EPHEMERY_PEER_COUNT_THRESHOLD:-20}
EPHEMERY_MAX_SLOTS_BEHIND=${EPHEMERY_MAX_SLOTS_BEHIND:-50}

# Function to ensure directories exist
ensure_directories() {
  mkdir -p "${EPHEMERY_DATA_DIR}"
  mkdir -p "${EPHEMERY_CONFIG_DIR}"
  mkdir -p "${EPHEMERY_LOGS_DIR}"
  mkdir -p "${EPHEMERY_SECRETS_DIR}"
  mkdir -p "${EPHEMERY_GETH_DIR}"
  mkdir -p "${EPHEMERY_LIGHTHOUSE_DIR}"
  mkdir -p "${EPHEMERY_LIGHTHOUSE_VALIDATOR_DIR}"
  mkdir -p "${EPHEMERY_VALIDATOR_KEYS_DIR}"
  mkdir -p "${EPHEMERY_VALIDATOR_PASSWORDS_DIR}"
  mkdir -p "${EPHEMERY_VALIDATOR_BACKUP_DIR}"

  # Set appropriate permissions
  chmod 750 "${EPHEMERY_SECRETS_DIR}"
  chmod 750 "${EPHEMERY_VALIDATOR_KEYS_DIR}"
  chmod 750 "${EPHEMERY_VALIDATOR_PASSWORDS_DIR}"

  # Create backup directory if enabled
  if [ ! -z "${EPHEMERY_BACKUP_DIR}" ]; then
    mkdir -p "${EPHEMERY_BACKUP_DIR}"
  fi
}

# Function to verify docker is available
verify_docker() {
  if ! command -v docker &>/dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in the PATH.${NC}"
    echo -e "${YELLOW}Please install Docker before running Ephemery scripts.${NC}"
    return 1
  fi

  if ! docker info &>/dev/null; then
    echo -e "${RED}Error: Docker daemon is not running or current user doesn't have permission.${NC}"
    echo -e "${YELLOW}Please start Docker daemon or add user to the docker group.${NC}"
    return 1
  fi

  return 0
}

# Function to check if a container is running
is_container_running() {
  local container_name=$1
  if docker ps | grep -q "${container_name}"; then
    return 0
  else
    return 1
  fi
}

# Function to create Docker network if it doesn't exist
ensure_docker_network() {
  if ! docker network ls | grep -q "${EPHEMERY_DOCKER_NETWORK}"; then
    echo -e "${BLUE}Creating Docker network: ${EPHEMERY_DOCKER_NETWORK}${NC}"
    docker network create "${EPHEMERY_DOCKER_NETWORK}"
  fi
}

# Function to generate JWT secret if it doesn't exist
ensure_jwt_secret() {
  if [ ! -f "${EPHEMERY_JWT_SECRET_PATH}" ]; then
    echo -e "${BLUE}Generating JWT secret...${NC}"
    openssl rand -hex 32 | tr -d "\n" >"${EPHEMERY_JWT_SECRET_PATH}"
    chmod 600 "${EPHEMERY_JWT_SECRET_PATH}"
  fi
}

# Function to log message with timestamp
log_message() {
  local message=$1
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${timestamp} - ${message}"
}

# Function to ensure Docker network exists
ensure_network() {
  if ! docker network ls | grep -q "${EPHEMERY_DOCKER_NETWORK}"; then
    echo -e "${BLUE}Creating Docker network: ${EPHEMERY_DOCKER_NETWORK}${NC}"
    docker network create "${EPHEMERY_DOCKER_NETWORK}"
  fi
}

# Function to find best checkpoint URL
find_best_checkpoint_url() {
  local best_url=""
  local fastest_time=999

  for url in "${EPHEMERY_DEFAULT_CHECKPOINT_URLS[@]}"; do
    echo -e "${BLUE}Testing checkpoint URL: ${url}${NC}"

    # Test URL with a timeout
    local start_time=$(date +%s.%N)
    if curl --silent --fail --max-time 10 --output /dev/null "${url}"; then
      local end_time=$(date +%s.%N)
      local response_time=$(echo "${end_time} - ${start_time}" | bc)

      echo -e "${GREEN}URL is accessible, response time: ${response_time} seconds${NC}"

      # Keep the fastest URL
      if (($(echo "${response_time} < ${fastest_time}" | bc -l))); then
        fastest_time=${response_time}
        best_url=${url}
      fi
    else
      echo -e "${RED}URL is not accessible${NC}"
    fi
  done

  if [[ -n "${best_url}" ]]; then
    echo -e "${GREEN}Best checkpoint sync URL: ${best_url} (response time: ${fastest_time} seconds)${NC}"
    echo "${best_url}"
    return 0
  else
    echo -e "${RED}No working checkpoint sync URLs found${NC}"
    return 1
  fi
}

# Function to validate validator keys
validate_validator_keys() {
  local count=0
  local valid=0
  local invalid=0

  if [[ ! -d "${EPHEMERY_VALIDATOR_KEYS_DIR}" ]]; then
    echo -e "${RED}Error: Validator keys directory '${EPHEMERY_VALIDATOR_KEYS_DIR}' does not exist${NC}"
    return 1
  fi

  count=$(find "${EPHEMERY_VALIDATOR_KEYS_DIR}" -name "*.json" | wc -l)
  echo -e "${BLUE}Found ${count} validator key files${NC}"

  if [[ ${count} -eq 0 ]]; then
    echo -e "${YELLOW}No validator keys found to validate${NC}"
    return 1
  fi

  # Check each key file
  for key_file in "${EPHEMERY_VALIDATOR_KEYS_DIR}"/*.json; do
    if [[ -f "${key_file}" ]]; then
      # Check if file is valid JSON
      if jq . "${key_file}" &>/dev/null; then
        # Check if file contains required fields
        if jq -e '.pubkey' "${key_file}" &>/dev/null; then
          valid=$((valid + 1))
        else
          invalid=$((invalid + 1))
          echo -e "${RED}Invalid key file: ${key_file} (missing required fields)${NC}"
        fi
      else
        invalid=$((invalid + 1))
        echo -e "${RED}Invalid key file: ${key_file} (not valid JSON)${NC}"
      fi
    fi
  done

  echo -e "${BLUE}Validation summary:${NC}"
  echo -e "${GREEN}Valid keys: ${valid}${NC}"
  if [[ "${invalid}" -gt 0 ]]; then
    echo -e "${RED}Invalid keys: ${invalid}${NC}"
    return 1
  else
    echo -e "${GREEN}Invalid keys: ${invalid}${NC}"
    return 0
  fi
}

# Export all variables and functions
export GREEN YELLOW RED BLUE NC
export EPHEMERY_BASE_DIR
export EPHEMERY_DOCKER_NETWORK EPHEMERY_LIGHTHOUSE_IMAGE EPHEMERY_GETH_IMAGE
export EPHEMERY_GETH_CONTAINER EPHEMERY_LIGHTHOUSE_CONTAINER EPHEMERY_VALIDATOR_CONTAINER
export EPHEMERY_GETH_HTTP_PORT EPHEMERY_GETH_WS_PORT EPHEMERY_GETH_AUTH_PORT EPHEMERY_GETH_METRICS_PORT
export EPHEMERY_LIGHTHOUSE_HTTP_PORT EPHEMERY_LIGHTHOUSE_METRICS_PORT EPHEMERY_VALIDATOR_METRICS_PORT
export EPHEMERY_TARGET_PEERS EPHEMERY_P2P_ENABLED
export EPHEMERY_DATA_DIR EPHEMERY_CONFIG_DIR EPHEMERY_LOGS_DIR EPHEMERY_SECRETS_DIR
export EPHEMERY_GETH_DIR EPHEMERY_LIGHTHOUSE_DIR EPHEMERY_LIGHTHOUSE_VALIDATOR_DIR
export EPHEMERY_VALIDATOR_KEYS_DIR EPHEMERY_VALIDATOR_PASSWORDS_DIR EPHEMERY_FEE_RECIPIENT
export EPHEMERY_JWT_SECRET_PATH
export EPHEMERY_CHECKPOINT_SYNC_ENABLED EPHEMERY_CHECKPOINT_SYNC_URL EPHEMERY_CHECKPOINT_URL_FILE
export EPHEMERY_BACKUP_DIR
export EPHEMERY_DISK_SPACE_THRESHOLD EPHEMERY_PEER_COUNT_THRESHOLD EPHEMERY_MAX_SLOTS_BEHIND
export EPHEMERY_VALIDATOR_BACKUP_DIR
export EPHEMERY_DEFAULT_CHECKPOINT_URLS

# Export functions
export -f ensure_directories
export -f verify_docker
export -f is_container_running
export -f ensure_docker_network
export -f ensure_jwt_secret
export -f log_message
export -f ensure_network
export -f find_best_checkpoint_url
export -f validate_validator_keys
