#!/bin/bash

# Ephemery Common Configuration File
# This file contains common configuration settings for all Ephemery scripts

# Visual formatting
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base directory
EPHEMERY_BASE_DIR=${EPHEMERY_BASE_DIR:-~/ephemery}

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
EPHEMERY_DISK_SPACE_THRESHOLD=${EPHEMERY_DISK_SPACE_THRESHOLD:-10}  # GB
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
  
  # Create backup directory if enabled
  if [ ! -z "${EPHEMERY_BACKUP_DIR}" ]; then
    mkdir -p "${EPHEMERY_BACKUP_DIR}"
  fi
}

# Function to verify docker is available
verify_docker() {
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in the PATH.${NC}"
    echo -e "${YELLOW}Please install Docker before running Ephemery scripts.${NC}"
    return 1
  fi
  
  if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker daemon is not running or current user doesn't have permission.${NC}"
    echo -e "${YELLOW}Please start Docker daemon or add user to the docker group.${NC}"
    return 1
  fi
  
  return 0
}

# Function to check if a container is running
is_container_running() {
  local container_name=$1
  if docker ps | grep -q "$container_name"; then
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
    openssl rand -hex 32 | tr -d "\n" > "${EPHEMERY_JWT_SECRET_PATH}"
    chmod 600 "${EPHEMERY_JWT_SECRET_PATH}"
  fi
}

# Function to log message with timestamp
log_message() {
  local message=$1
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${timestamp} - $message"
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

# Export functions
export -f ensure_directories
export -f verify_docker
export -f is_container_running
export -f ensure_docker_network
export -f ensure_jwt_secret
export -f log_message
