#!/bin/bash

# Ephemery Node Setup Script
# This script automates the setup of Ephemery nodes based on best practices
# Version: 1.2.0

# Source core utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
CORE_DIR="${SCRIPT_DIR}/scripts/core"

# Source path configuration
if [ -f "${CORE_DIR}/path_config.sh" ]; then
  source "${CORE_DIR}/path_config.sh"
else
  echo "Error: Path configuration not found at ${CORE_DIR}/path_config.sh"
  echo "Please ensure the core scripts are properly installed."
  exit 1
fi

# Source error handling
if [ -f "${CORE_DIR}/error_handling.sh" ]; then
  source "${CORE_DIR}/error_handling.sh"
  # Set up error handling
  setup_error_handling
  # Allow the script to continue on errors
  ERROR_CONTINUE_ON_ERROR=true
else
  echo "Error: Error handling script not found at ${CORE_DIR}/error_handling.sh"
  echo "Please ensure the core scripts are properly installed."
  exit 1
fi

# Source common utilities
if [ -f "${CORE_DIR}/common.sh" ]; then
  source "${CORE_DIR}/common.sh"
else
  echo "Error: Common utilities script not found at ${CORE_DIR}/common.sh"
  echo "Please ensure the core scripts are properly installed."
  exit 1
fi

# Declare version information for dependencies
declare -A VERSIONS=(
  [GETH]="1.13.14"
  [LIGHTHOUSE]="4.5.0"
  [PRYSM]="4.1.1"
  [TEKU]="24.3.0"
  [DOCKER]="24.0.0"
  [DOCKER_COMPOSE]="2.24.0"
)

# Define default checkpoint sync URLs in order of preference
EPHEMERY_CHECKPOINT_URLS=(
  "https://checkpoint-sync.ephemery.ethpandaops.io"
  "https://beaconstate-ephemery.chainsafe.io"
  "https://checkpoint-sync.ephemery.dev"
)

# Color definitions if not defined by common config
GREEN=${GREEN:-'\033[0;32m'}
YELLOW=${YELLOW:-'\033[1;33m'}
RED=${RED:-'\033[0;31m'}
BLUE=${BLUE:-'\033[0;34m'}
NC=${NC:-'\033[0m'}

# Define script-specific settings
USE_CHECKPOINT_SYNC=true
RESET_DATABASE=false
CHECKPOINT_URL=""

# Function to show help
show_help() {
  echo -e "${BLUE}Ephemery Node Setup Script${NC}"
  echo ""
  echo "This script automates the setup of Ephemery nodes with optimized settings."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --checkpoint-sync       Enable checkpoint sync (default: enabled)"
  echo "  --no-checkpoint-sync    Disable checkpoint sync"
  echo "  --checkpoint-url URL    Specify a custom checkpoint sync URL"
  echo "  --reset                 Reset database before starting"
  echo "  --base-dir PATH         Specify a custom base directory (default: ${EPHEMERY_BASE_DIR:-~/ephemery})"
  echo "  --geth-cache SIZE       Specify Geth cache size in MB (default: ${EPHEMERY_GETH_CACHE:-4096})"
  echo "  --target-peers COUNT    Specify target peer count (default: ${EPHEMERY_TARGET_PEERS:-100})"
  echo "  --help                  Display this help message"
  echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --checkpoint-sync)
      USE_CHECKPOINT_SYNC=true
      shift
      ;;
    --no-checkpoint-sync)
      USE_CHECKPOINT_SYNC=false
      shift
      ;;
    --checkpoint-url)
      CHECKPOINT_URL="$2"
      shift 2
      ;;
    --reset)
      RESET_DATABASE=true
      shift
      ;;
    --base-dir)
      EPHEMERY_BASE_DIR="$2"
      shift 2
      ;;
    --geth-cache)
      EPHEMERY_GETH_CACHE="$2"
      shift 2
      ;;
    --target-peers)
      EPHEMERY_TARGET_PEERS="$2"
      shift 2
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      if type handle_error &>/dev/null; then
        handle_error "ERROR" "Unknown option: $1" "${EXIT_CODES[INVALID_ARGUMENT]}"
      else
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 1
      fi
      ;;
  esac
done

echo -e "${BLUE}Setting up Ephemery node environment...${NC}"

# Create directories
if type ensure_ephemery_directories &>/dev/null; then
  ensure_ephemery_directories
else
  mkdir -p "${EPHEMERY_BASE_DIR}"/data/geth
  mkdir -p "${EPHEMERY_BASE_DIR}"/data/lighthouse
  mkdir -p "${EPHEMERY_BASE_DIR}"/config
  mkdir -p "${EPHEMERY_BASE_DIR}"/logs
  mkdir -p "${EPHEMERY_BASE_DIR}"/secrets
fi

# Network Configuration
echo -e "${BLUE}Creating Docker network...${NC}"
if ! command -v docker &>/dev/null; then
  if type handle_error &>/dev/null; then
    handle_error "ERROR" "Docker is not installed or not in PATH" "${EXIT_CODES[DEPENDENCY_ERROR]}"
  else
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
  fi
fi

# Create Docker network
docker network create "${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"}" 2>/dev/null || true

# JWT Authentication
echo -e "${BLUE}Creating JWT secret...${NC}"
JWT_PATH=${EPHEMERY_JWT_SECRET:-"${EPHEMERY_BASE_DIR}/jwt.hex"}
if [ ! -f "${JWT_PATH}" ]; then
  if type run_with_error_handling &>/dev/null; then
    run_with_error_handling "Generate JWT secret" openssl rand -hex 32 >"${JWT_PATH}"
    run_with_error_handling "Set JWT permissions" chmod 600 "${JWT_PATH}"
  else
    openssl rand -hex 32 >"${JWT_PATH}"
    chmod 600 "${JWT_PATH}"
  fi
fi

# Checkpoint sync setup
if [ "${USE_CHECKPOINT_SYNC}" = true ]; then
  echo -e "${BLUE}Setting up checkpoint sync...${NC}"

  # If no custom URL specified, test default URLs and find best one
  if [ -z "${CHECKPOINT_URL}" ]; then
    echo -e "${YELLOW}Testing checkpoint sync URLs for availability...${NC}"
    for url in "${EPHEMERY_CHECKPOINT_URLS[@]}"; do
      echo -e "Testing ${url}..."
      if curl --connect-timeout 5 --max-time 10 -s "${url}" >/dev/null; then
        echo -e "${GREEN}✓ URL is accessible${NC}"
        CHECKPOINT_URL="${url}"
        break
      else
        echo -e "${RED}✗ URL is not accessible${NC}"
      fi
    done

    if [ -z "${CHECKPOINT_URL}" ]; then
      echo -e "${RED}No accessible checkpoint sync URL found. Falling back to genesis sync.${NC}"
      USE_CHECKPOINT_SYNC=false
    else
      echo -e "${GREEN}Using checkpoint sync URL: ${CHECKPOINT_URL}${NC}"
    fi
  else
    echo -e "${BLUE}Using provided checkpoint sync URL: ${CHECKPOINT_URL}${NC}"
    # Verify the provided URL is accessible
    if ! curl --connect-timeout 5 --max-time 10 -s "${CHECKPOINT_URL}" >/dev/null; then
      echo -e "${RED}Warning: Provided checkpoint URL doesn't seem to be accessible.${NC}"
      echo -e "${YELLOW}Will continue with this URL, but sync may fail.${NC}"
    fi
  fi
fi

# Reset database if requested
if [ "${RESET_DATABASE}" = true ]; then
  echo -e "${YELLOW}Resetting database as requested...${NC}"
  if type run_with_error_handling &>/dev/null; then
    run_with_error_handling "Remove Geth data" rm -rf "${EPHEMERY_GETH_DATA_DIR:-${EPHEMERY_BASE_DIR}/data/geth}/*"
    run_with_error_handling "Remove Lighthouse data" rm -rf "${EPHEMERY_LIGHTHOUSE_DATA_DIR:-${EPHEMERY_BASE_DIR}/data/lighthouse}/*"
  else
    rm -rf "${EPHEMERY_BASE_DIR}"/data/geth/*
    rm -rf "${EPHEMERY_BASE_DIR}"/data/lighthouse/*
  fi
  echo -e "${GREEN}Database reset complete${NC}"
fi

# Stop and remove any existing containers
echo -e "${BLUE}Cleaning up any existing containers...${NC}"
if type run_with_error_handling &>/dev/null; then
  run_with_error_handling "Stop Geth container" docker stop ephemery-geth 2>/dev/null || true
  run_with_error_handling "Stop Lighthouse container" docker stop ephemery-lighthouse 2>/dev/null || true
  run_with_error_handling "Remove Geth container" docker rm ephemery-geth 2>/dev/null || true
  run_with_error_handling "Remove Lighthouse container" docker rm ephemery-lighthouse 2>/dev/null || true
else
  docker stop ephemery-geth ephemery-lighthouse 2>/dev/null || true
  docker rm ephemery-geth ephemery-lighthouse 2>/dev/null || true
fi

# Start Geth (Execution Layer) with optimized parameters
echo -e "${BLUE}Starting Geth execution layer...${NC}"
if type run_with_error_handling &>/dev/null; then
  run_with_error_handling "Start Geth container" docker run -d --name ephemery-geth --network "${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"}" \
    -v "${EPHEMERY_GETH_DATA_DIR:-"${EPHEMERY_BASE_DIR}/data/geth"}":/ethdata \
    -v "${EPHEMERY_JWT_SECRET:-"${EPHEMERY_BASE_DIR}/jwt.hex"}":/config/jwt-secret \
    -p 8545-8546:8545-8546 -p 8551:8551 -p 30303:30303 -p 30303:30303/udp \
    "${EPHEMERY_GETH_IMAGE:-"pk910/ephemery-geth:latest"}" \
    --http.addr 0.0.0.0 --authrpc.addr 0.0.0.0 --authrpc.vhosts "*" \
    --authrpc.jwtsecret /config/jwt-secret \
    --cache="${EPHEMERY_GETH_CACHE:-4096}" --txlookuplimit=0 --syncmode=snap --maxpeers="${EPHEMERY_TARGET_PEERS:-100}"
else
  docker run -d --name ephemery-geth --network "${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"}" \
    -v "${EPHEMERY_BASE_DIR}"/data/geth:/ethdata \
    -v "${EPHEMERY_JWT_SECRET:-"${EPHEMERY_BASE_DIR}/jwt.hex"}":/config/jwt-secret \
    -p 8545-8546:8545-8546 -p 8551:8551 -p 30303:30303 -p 30303:30303/udp \
    "${EPHEMERY_GETH_IMAGE:-"pk910/ephemery-geth:latest"}" \
    --http.addr 0.0.0.0 --authrpc.addr 0.0.0.0 --authrpc.vhosts "*" \
    --authrpc.jwtsecret /config/jwt-secret \
    --cache="${EPHEMERY_GETH_CACHE}" --txlookuplimit=0 --syncmode=snap --maxpeers="${EPHEMERY_TARGET_PEERS}"
fi

echo -e "${BLUE}Waiting 10 seconds for Geth to initialize...${NC}"
sleep 10

# Prepare Lighthouse command with base parameters
LIGHTHOUSE_CMD="lighthouse beacon --datadir /ethdata --testnet-dir=/ephemery_config \
  --execution-jwt /config/jwt-secret --execution-endpoint http://ephemery-geth:8551 \
  --http --http-address 0.0.0.0 --http-port 5052 \
  --metrics --metrics-address 0.0.0.0 --metrics-port 8008 \
  --target-peers ${EPHEMERY_TARGET_PEERS:-100} --execution-timeout-multiplier ${EPHEMERY_EXECUTION_TIMEOUT:-10} \
  --disable-deposit-contract-sync"

# Add checkpoint sync if enabled
if [ "${USE_CHECKPOINT_SYNC}" = true ] && [ ! -z "${CHECKPOINT_URL}" ]; then
  LIGHTHOUSE_CMD="${LIGHTHOUSE_CMD} --checkpoint-sync-url=${CHECKPOINT_URL}"
else
  # Add genesis sync optimizations if not using checkpoint sync
  LIGHTHOUSE_CMD="${LIGHTHOUSE_CMD} --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"
fi

# Start Lighthouse (Consensus Layer)
echo -e "${BLUE}Starting Lighthouse consensus layer...${NC}"
if type run_with_error_handling &>/dev/null; then
  run_with_error_handling "Start Lighthouse container" docker run -d --name ephemery-lighthouse --network "${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"}" \
    -v "${EPHEMERY_LIGHTHOUSE_DATA_DIR:-"${EPHEMERY_BASE_DIR}/data/lighthouse"}":/ethdata \
    -v "${EPHEMERY_JWT_SECRET:-"${EPHEMERY_BASE_DIR}/jwt.hex"}":/config/jwt-secret \
    -v "${EPHEMERY_CONFIG_DIR:-"${EPHEMERY_BASE_DIR}/config"}":/ephemery_config \
    -p 5052:5052 -p 9000:9000 -p 9000:9000/udp -p 8008:8008 \
    "${EPHEMERY_LIGHTHOUSE_IMAGE:-"pk910/ephemery-lighthouse:latest"}" \
    "${LIGHTHOUSE_CMD}"
else
  docker run -d --name ephemery-lighthouse --network "${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"}" \
    -v "${EPHEMERY_BASE_DIR}"/data/lighthouse:/ethdata \
    -v "${EPHEMERY_JWT_SECRET:-"${EPHEMERY_BASE_DIR}/jwt.hex"}":/config/jwt-secret \
    -v "${EPHEMERY_BASE_DIR}"/config:/ephemery_config \
    -p 5052:5052 -p 9000:9000 -p 9000:9000/udp -p 8008:8008 \
    "${EPHEMERY_LIGHTHOUSE_IMAGE:-"pk910/ephemery-lighthouse:latest"}" \
    "${LIGHTHOUSE_CMD}"
fi

# Save checkpoint URL for future reference
if [ "${USE_CHECKPOINT_SYNC}" = true ] && [ ! -z "${CHECKPOINT_URL}" ]; then
  echo "${CHECKPOINT_URL}" >"${EPHEMERY_BASE_DIR}"/checkpoint_url.txt
fi

# Generate configuration file for persistence if available
if type generate_paths_config &>/dev/null; then
  echo -e "${BLUE}Generating paths configuration file...${NC}"
  generate_paths_config
fi

echo -e "${GREEN}Ephemery node setup complete!${NC}"
echo ""
if [ "${USE_CHECKPOINT_SYNC}" = true ] && [ ! -z "${CHECKPOINT_URL}" ]; then
  echo -e "${GREEN}Checkpoint sync enabled with URL: ${CHECKPOINT_URL}${NC}"
  echo -e "${YELLOW}Initial sync should be significantly faster than genesis sync.${NC}"
else
  if [ "${USE_CHECKPOINT_SYNC}" = true ]; then
    echo -e "${RED}Checkpoint sync was enabled but no working URL was found.${NC}"
    echo -e "${YELLOW}Falling back to genesis sync which will take longer.${NC}"
  else
    echo -e "${YELLOW}Running with genesis sync. This may take several hours.${NC}"
  fi
fi
echo ""
echo -e "${BLUE}Verification:${NC}"
echo "- Geth API (after initialization): curl -X POST -H \"Content-Type: application/json\" --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}' http://localhost:8545"
echo "- Lighthouse API: curl -X GET http://localhost:5052/eth/v1/node/syncing -H \"Content-Type: application/json\""

# Function to check required tools with version validation
check_dependencies() {
  local missing_deps=false

  log_info "Checking dependencies..."

  # Check Docker with version validation
  if ! command -v docker &>/dev/null; then
    log_error "Docker is not installed. Please install Docker v${VERSIONS[DOCKER]} or later."
    missing_deps=true
  else
    local docker_version
    docker_version=$(docker --version | sed -n 's/Docker version \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
    if ! version_greater_equal "${docker_version}" "${VERSIONS[DOCKER]}"; then
      log_warning "Docker version ${docker_version} is older than recommended version ${VERSIONS[DOCKER]}"
    else
      log_success "Docker version ${docker_version} is installed (✓)"
    fi
  fi

  # Check Docker Compose with version validation
  if ! command -v docker-compose &>/dev/null; then
    log_error "Docker Compose is not installed. Please install Docker Compose v${VERSIONS[DOCKER_COMPOSE]} or later."
    missing_deps=true
  else
    local compose_version
    compose_version=$(docker-compose --version | sed -n 's/.*version \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
    if ! version_greater_equal "${compose_version}" "${VERSIONS[DOCKER_COMPOSE]}"; then
      log_warning "Docker Compose version ${compose_version} is older than recommended version ${VERSIONS[DOCKER_COMPOSE]}"
    else
      log_success "Docker Compose version ${compose_version} is installed (✓)"
    fi
  fi

  if [ "${missing_deps}" = true ]; then
    log_fatal "Missing required dependencies. Please install them and try again."
    exit 1
  fi
}

# Helper function to compare versions
version_greater_equal() {
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}
