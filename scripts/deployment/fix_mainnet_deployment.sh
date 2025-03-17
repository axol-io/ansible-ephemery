#!/bin/bash
# Version: 1.0.0
#
# Ephemery Mainnet Deployment Fix Script
# =====================================
#
# This script addresses the issues identified in the mainnet deployment
# by fixing container configurations, setting up the proper network directory,
# and ensuring correct parameters for Ephemery-specific requirements.
#

# Exit immediately if a command exits with a non-zero status
set -e

# Colors for better readability in terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# Project root directory
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Default values
INVENTORY_FILE=""
REMOTE_HOST=""
REMOTE_USER="root"
REMOTE_PORT="22"
SKIP_PROMPTS=false
EPHEMERY_ITERATION="current" # Use 'current' for latest or specify like 'ephemery-143'
BASE_DIR="/opt/ephemery"
TESTNET_CONFIG_DIR="${BASE_DIR}/config/ephemery_network"
APPLY_FIXES=true

# Show banner
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}          Ephemery Mainnet Deployment Fix Script                ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""
echo -e "This script fixes issues with Ephemery mainnet deployment:"
echo -e " 1. Fixes client container configuration with proper images"
echo -e " 2. Sets up the Ephemery network directory with latest genesis"
echo -e " 3. Fixes container parameters to reference testnet directory"
echo -e " 4. Fixes checkpoint sync issues"
echo ""

# Show help message
show_help() {
  echo -e "Usage: $0 [options]"
  echo ""
  echo -e "Options:"
  echo -e "  -h, --help                  Show this help message"
  echo -e "  -i, --inventory FILE        Specify inventory file path"
  echo -e "  -H, --host HOST             Remote host (for direct SSH)"
  echo -e "  -u, --user USER             Remote user (default: root)"
  echo -e "  -p, --port PORT             SSH port (default: 22)"
  echo -e "  -e, --ephemery-iteration    Specify Ephemery iteration (default: current)"
  echo -e "  -d, --directory DIR         Base directory (default: /opt/ephemery)"
  echo -e "  -y, --yes                   Skip all prompts, use defaults"
  echo -e "  --check-only                Only check issues without applying fixes"
  echo ""
  echo -e "Examples:"
  echo -e "  $0 --inventory production-inventory.yaml   # Fix using inventory file"
  echo -e "  $0 --host REMOTE_HOST_IP                   # Direct fix via SSH"
  echo -e ""
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
      -h | --help)
        show_help
        exit 0
        ;;
      -i | --inventory)
        INVENTORY_FILE="$2"
        shift 2
        ;;
      -H | --host)
        REMOTE_HOST="$2"
        shift 2
        ;;
      -u | --user)
        REMOTE_USER="$2"
        shift 2
        ;;
      -p | --port)
        REMOTE_PORT="$2"
        shift 2
        ;;
      -e | --ephemery-iteration)
        EPHEMERY_ITERATION="$2"
        shift 2
        ;;
      -d | --directory)
        BASE_DIR="$2"
        TESTNET_CONFIG_DIR="${BASE_DIR}/config/ephemery_network"
        shift 2
        ;;
      -y | --yes)
        SKIP_PROMPTS=true
        shift
        ;;
      --check-only)
        APPLY_FIXES=false
        shift
        ;;
      *)
        echo -e "${RED}Unknown option: ${key}${NC}"
        show_help
        exit 1
        ;;
    esac
  done
}

# Validate arguments
validate_args() {
  if [[ -z "${INVENTORY_FILE}" && -z "${REMOTE_HOST}" ]]; then
    echo -e "${RED}Error: Either --inventory or --host must be specified${NC}"
    show_help
    exit 1
  fi
}

# Function to extract host and user from inventory file
extract_from_inventory() {
  if [[ -z "${REMOTE_HOST}" && -n "${INVENTORY_FILE}" ]]; then
    # Try to extract host from inventory file
    if command -v yq &>/dev/null; then
      REMOTE_HOST=$(yq eval '.ephemery.children.*.hosts.*.ansible_host' "${INVENTORY_FILE}" | head -n1)
      TEMP_USER=$(yq eval '.ephemery.children.*.hosts.*.ansible_user' "${INVENTORY_FILE}" | head -n1)
      if [[ -n "${TEMP_USER}" && "${TEMP_USER}" != "null" ]]; then
        REMOTE_USER=${TEMP_USER}
      fi
    else
      echo -e "${YELLOW}Warning: yq command not found. Cannot extract host from inventory.${NC}"
      echo -e "${YELLOW}Please install yq or specify host directly with --host option.${NC}"
      exit 1
    fi
  fi

  if [[ -z "${REMOTE_HOST}" ]]; then
    echo -e "${RED}Error: Could not determine target host.${NC}"
    echo -e "${YELLOW}Please specify with --host option.${NC}"
    exit 1
  fi

  echo -e "${GREEN}Target host: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}${NC}"
}

# Function to check SSH connection
check_ssh_connection() {
  echo -e "${YELLOW}Checking SSH connection to ${REMOTE_USER}@${REMOTE_HOST}...${NC}"
  if ! ssh -p "${REMOTE_PORT}" -o ConnectTimeout=5 -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "echo Connection successful"; then
    echo -e "${RED}Error: Cannot connect to ${REMOTE_USER}@${REMOTE_HOST}${NC}"
    echo -e "${YELLOW}Please check host, user, and SSH key configuration.${NC}"
    exit 1
  fi
  echo -e "${GREEN}SSH connection successful.${NC}"
}

# Function to check container issues
check_container_issues() {
  echo -e "${YELLOW}Checking container issues...${NC}"

  # Check if Docker is installed
  if ! ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "command -v docker &> /dev/null"; then
    echo -e "${RED}Error: Docker not installed on remote host.${NC}"
    return 1
  fi

  # Check container status
  local container_status=$(ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "docker ps -a --format '{{.Names}} {{.Image}} {{.Status}}' | grep -E 'ephemery|geth|lighthouse'" || echo "")

  if [[ -z "${container_status}" ]]; then
    echo -e "${RED}No Ephemery containers found.${NC}"
    return 1
  fi

  echo -e "${YELLOW}Container status:${NC}"
  echo "${container_status}" | while read line; do
    if [[ "${line}" == *"Restarting"* ]]; then
      echo -e "${RED}${line}${NC}"
    else
      echo -e "${GREEN}${line}${NC}"
    fi
  done

  # Check for specific container image issues
  if [[ "${container_status}" != *"pk910/ephemery-geth"* ]]; then
    echo -e "${RED}Issue detected: Not using pk910/ephemery-geth image${NC}"
  fi

  if [[ "${container_status}" != *"pk910/ephemery-lighthouse"* ]]; then
    echo -e "${RED}Issue detected: Not using pk910/ephemery-lighthouse image${NC}"
  fi

  # Check container logs for specific errors
  echo -e "${YELLOW}Checking container logs for errors...${NC}"

  # Check Lighthouse logs
  local lighthouse_errors=$(ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "docker logs \$(docker ps -a --format '{{.Names}}' | grep -E 'ephemery-lighthouse|lighthouse' | head -1) 2>&1 | grep -E 'invalid value|--network' | tail -5" || echo "")

  if [[ -n "${lighthouse_errors}" ]]; then
    echo -e "${RED}Lighthouse errors found:${NC}"
    echo "${lighthouse_errors}"
  fi

  # Check Geth logs
  local geth_errors=$(ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "docker logs \$(docker ps -a --format '{{.Names}}' | grep -E 'ephemery-geth|geth' | head -1) 2>&1 | grep -E 'invalid command|geth' | tail -5" || echo "")

  if [[ -n "${geth_errors}" ]]; then
    echo -e "${RED}Geth errors found:${NC}"
    echo "${geth_errors}"
  fi
}

# Function to fix container configuration
fix_container_configuration() {
  echo -e "${YELLOW}Fixing container configuration...${NC}"

  if [[ "${APPLY_FIXES}" != "true" ]]; then
    echo -e "${YELLOW}Check-only mode: Skipping container configuration fixes${NC}"
    return 0
  fi

  if [[ -n "${INVENTORY_FILE}" ]]; then
    # Update inventory file with correct images
    if [[ -f "${INVENTORY_FILE}" ]]; then
      echo -e "${YELLOW}Updating inventory file with correct images...${NC}"

      # Create backup of inventory file
      cp "${INVENTORY_FILE}" "${INVENTORY_FILE}.bak.$(date +%Y%m%d%H%M%S)"

      # Update image configurations in inventory file
      sed -i 's|geth_image:.*|geth_image: "pk910/ephemery-geth:v1.15.3"|g' "${INVENTORY_FILE}"
      sed -i 's|lighthouse_image:.*|lighthouse_image: "pk910/ephemery-lighthouse:v5.3.0"|g' "${INVENTORY_FILE}"
      sed -i 's|validator_image:.*|validator_image: "pk910/ephemery-lighthouse:v5.3.0"|g' "${INVENTORY_FILE}"

      echo -e "${GREEN}Updated inventory file with correct images.${NC}"
    else
      echo -e "${RED}Error: Inventory file not found: ${INVENTORY_FILE}${NC}"
      return 1
    fi
  else
    # Direct SSH approach to fix containers
    echo -e "${YELLOW}Stopping existing containers...${NC}"
    ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "docker stop \$(docker ps -a --format '{{.Names}}' | grep -E 'ephemery|geth|lighthouse') || true"

    echo -e "${YELLOW}Removing existing containers...${NC}"
    ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "docker rm \$(docker ps -a --format '{{.Names}}' | grep -E 'ephemery|geth|lighthouse') || true"

    echo -e "${YELLOW}Pulling correct images...${NC}"
    ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "docker pull pk910/ephemery-geth:v1.15.3"
    ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "docker pull pk910/ephemery-lighthouse:v5.3.0"

    echo -e "${GREEN}Container images updated.${NC}"
  fi
}

# Function to setup network directory
setup_network_directory() {
  echo -e "${YELLOW}Setting up Ephemery network directory...${NC}"

  if [[ "${APPLY_FIXES}" != "true" ]]; then
    echo -e "${YELLOW}Check-only mode: Skipping network directory setup${NC}"
    return 0
  fi

  # Create network config directory
  ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${TESTNET_CONFIG_DIR}"

  # Get the latest iteration if 'current' is specified
  if [[ "${EPHEMERY_ITERATION}" == "current" ]]; then
    echo -e "${YELLOW}Determining latest Ephemery iteration...${NC}"
    LATEST_URL=$(ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "curl -s https://ephemery.dev/ | grep -o 'ephemery-[0-9]*' | sort -Vr | head -1" || echo "")

    if [[ -n "${LATEST_URL}" ]]; then
      EPHEMERY_ITERATION="${LATEST_URL}"
      echo -e "${GREEN}Latest iteration: ${EPHEMERY_ITERATION}${NC}"
    else
      echo -e "${RED}Error: Could not determine latest Ephemery iteration${NC}"
      echo -e "${YELLOW}Using default: ephemery-143${NC}"
      EPHEMERY_ITERATION="ephemery-143"
    fi
  fi

  # Download and extract network configuration
  echo -e "${YELLOW}Downloading Ephemery network configuration for ${EPHEMERY_ITERATION}...${NC}"
  ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "cd ${TESTNET_CONFIG_DIR} && \
    wget -q https://ephemery.dev/${EPHEMERY_ITERATION}/testnet-all.tar.gz && \
    tar -xzf testnet-all.tar.gz && \
    rm testnet-all.tar.gz"

  echo -e "${GREEN}Network directory setup complete.${NC}"
}

# Function to fix container parameters
fix_container_parameters() {
  echo -e "${YELLOW}Fixing container parameters...${NC}"

  if [[ "${APPLY_FIXES}" != "true" ]]; then
    echo -e "${YELLOW}Check-only mode: Skipping container parameter fixes${NC}"
    return 0
  fi

  if [[ -n "${INVENTORY_FILE}" ]]; then
    # Update inventory file with correct parameters
    if [[ -f "${INVENTORY_FILE}" ]]; then
      echo -e "${YELLOW}Updating inventory file with correct parameters...${NC}"

      # Update lighthouse parameters
      sed -i "s|cl_extra_opts:.*|cl_extra_opts: \"--testnet-dir=${TESTNET_CONFIG_DIR} --target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting\"|g" "${INVENTORY_FILE}"

      # Update execution client parameters if needed
      sed -i "s|el_extra_opts:.*|el_extra_opts: \"--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100 --db.engine=pebble\"|g" "${INVENTORY_FILE}"

      echo -e "${GREEN}Updated inventory file with correct parameters.${NC}"
    else
      echo -e "${RED}Error: Inventory file not found: ${INVENTORY_FILE}${NC}"
      return 1
    fi
  else
    # Direct SSH approach
    echo -e "${YELLOW}Creating/updating docker-compose.yml with correct parameters...${NC}"

    # Create docker-compose.yml with correct parameters
    ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "cat > ${BASE_DIR}/docker-compose.yml << 'EOF'
version: '3'
services:
  geth:
    container_name: ephemery-geth
    image: pk910/ephemery-geth:v1.15.3
    restart: unless-stopped
    volumes:
      - ${BASE_DIR}/data/geth:/data
      - ${BASE_DIR}/config/jwt.hex:/config/jwt.hex
    ports:
      - '8545:8545'
      - '8546:8546'
      - '30303:30303/tcp'
      - '30303:30303/udp'
    command: --cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100 --db.engine=pebble

  lighthouse:
    container_name: ephemery-lighthouse
    image: pk910/ephemery-lighthouse:v5.3.0
    restart: unless-stopped
    volumes:
      - ${BASE_DIR}/data/lighthouse:/data
      - ${BASE_DIR}/config/jwt.hex:/config/jwt.hex
      - ${TESTNET_CONFIG_DIR}:${TESTNET_CONFIG_DIR}
    ports:
      - '5052:5052'
      - '9000:9000/tcp'
      - '9000:9000/udp'
    command: --testnet-dir=${TESTNET_CONFIG_DIR} --target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting

  validator:
    container_name: ephemery-validator-lighthouse
    image: pk910/ephemery-lighthouse:v5.3.0
    restart: unless-stopped
    volumes:
      - ${BASE_DIR}/data/lighthouse_validator:/data
      - ${BASE_DIR}/config/validator:/config/validator_keys
      - ${TESTNET_CONFIG_DIR}:${TESTNET_CONFIG_DIR}
    command: validator --testnet-dir=${TESTNET_CONFIG_DIR}
EOF"

    echo -e "${GREEN}docker-compose.yml updated with correct parameters.${NC}"

    # Create JWT token if it doesn't exist
    ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${BASE_DIR}/config && \
      if [ ! -f ${BASE_DIR}/config/jwt.hex ]; then \
        openssl rand -hex 32 > ${BASE_DIR}/config/jwt.hex; \
        chmod 600 ${BASE_DIR}/config/jwt.hex; \
      fi"
  fi
}

# Function to fix checkpoint sync
fix_checkpoint_sync() {
  echo -e "${YELLOW}Fixing checkpoint sync...${NC}"

  if [[ "${APPLY_FIXES}" != "true" ]]; then
    echo -e "${YELLOW}Check-only mode: Skipping checkpoint sync fixes${NC}"
    return 0
  fi

  if [[ -n "${INVENTORY_FILE}" ]]; then
    # Use the existing fix_checkpoint_sync.sh script with the inventory file
    echo -e "${YELLOW}Running checkpoint sync fix script...${NC}"

    if [[ -f "${SCRIPT_DIR}/fix_checkpoint_sync.sh" ]]; then
      "${SCRIPT_DIR}/fix_checkpoint_sync.sh" --inventory "${INVENTORY_FILE}"
    else
      echo -e "${RED}Error: Checkpoint sync fix script not found: ${SCRIPT_DIR}/fix_checkpoint_sync.sh${NC}"
      return 1
    fi
  else
    # Direct SSH approach to fix checkpoint sync
    echo -e "${YELLOW}Checking available checkpoint sync options...${NC}"

    # Test checkpoint sync URLs
    local checkpoint_urls=(
      "https://checkpoint.ephemery.dev/checkpoint"
      "https://checkpoint.pk910.de/ephemery/checkpoint"
      "https://ephemery.pk910.de/checkpoint"
    )

    local best_url=""
    local best_response_time=9999

    for url in "${checkpoint_urls[@]}"; do
      echo -e "${YELLOW}Testing checkpoint URL: ${url}${NC}"
      local start_time=$(date +%s.%N)
      local response=$(ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "curl -s -o /dev/null -w '%{http_code}' -m 10 ${url}" || echo "000")
      local end_time=$(date +%s.%N)
      local response_time=$(echo "${end_time} - ${start_time}" | bc)

      if [[ "${response}" == "200" ]]; then
        echo -e "${GREEN}URL ${url} is working (response time: ${response_time} seconds)${NC}"
        if (($(echo "${response_time} < ${best_response_time}" | bc -l))); then
          best_url="${url}"
          best_response_time="${response_time}"
        fi
      else
        echo -e "${RED}URL ${url} is not working (HTTP code: ${response})${NC}"
      fi
    done

    if [[ -n "${best_url}" ]]; then
      echo -e "${GREEN}Best checkpoint URL: ${best_url} (response time: ${best_response_time} seconds)${NC}"

      # Update lighthouse parameters to include checkpoint sync
      echo -e "${YELLOW}Updating lighthouse parameters for checkpoint sync...${NC}"
      ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "sed -i 's|--testnet-dir=${TESTNET_CONFIG_DIR}|--testnet-dir=${TESTNET_CONFIG_DIR} --checkpoint-sync-url=${best_url}|g' ${BASE_DIR}/docker-compose.yml"

      echo -e "${GREEN}Checkpoint sync configuration updated.${NC}"
    else
      echo -e "${RED}Error: No working checkpoint sync URL found.${NC}"
      echo -e "${YELLOW}Will continue without checkpoint sync.${NC}"
    fi
  fi
}

# Function to restart services
restart_services() {
  echo -e "${YELLOW}Restarting services...${NC}"

  if [[ "${APPLY_FIXES}" != "true" ]]; then
    echo -e "${YELLOW}Check-only mode: Skipping service restart${NC}"
    return 0
  fi

  if [[ -n "${INVENTORY_FILE}" ]]; then
    # Use Ansible playbook to restart services
    echo -e "${YELLOW}Running Ansible playbook to restart services...${NC}"
    ansible-playbook -i "${INVENTORY_FILE}" "${PROJECT_ROOT}/ansible/playbooks/restart.yaml" || {
      echo -e "${RED}Error: Failed to restart services using Ansible${NC}"
      return 1
    }
  else
    # Direct SSH approach to restart services
    echo -e "${YELLOW}Restarting Docker containers...${NC}"
    ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "cd ${BASE_DIR} && docker-compose down && docker-compose up -d"
  fi

  echo -e "${GREEN}Services restarted.${NC}"
}

# Main function
main() {
  parse_args "$@"
  validate_args

  # Extract host and user from inventory file if needed
  extract_from_inventory

  # Check SSH connection
  check_ssh_connection

  # Check for container issues
  check_container_issues

  # Ask for confirmation before proceeding with fixes
  if [[ "${SKIP_PROMPTS}" != "true" && "${APPLY_FIXES}" == "true" ]]; then
    echo ""
    echo -e "${YELLOW}WARNING: This script will make changes to your Ephemery deployment.${NC}"
    echo -e "${YELLOW}It may stop and restart services, which could cause downtime.${NC}"
    echo ""
    read -p "Do you want to continue with the fixes? [y/N] " -n 1 -r
    echo ""
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}Operation cancelled by user.${NC}"
      exit 0
    fi
  fi

  # Apply fixes
  fix_container_configuration
  setup_network_directory
  fix_container_parameters
  fix_checkpoint_sync
  restart_services

  echo ""
  echo -e "${GREEN}================================================================${NC}"
  echo -e "${GREEN}          Ephemery Mainnet Deployment Fix Complete              ${NC}"
  echo -e "${GREEN}================================================================${NC}"
  echo ""
  echo -e "Next steps:"
  echo -e "1. Check container status: ${YELLOW}docker ps${NC}"
  echo -e "2. Check container logs:"
  echo -e "   ${YELLOW}docker logs ephemery-geth${NC}"
  echo -e "   ${YELLOW}docker logs ephemery-lighthouse${NC}"
  echo -e "3. Verify node is syncing: ${YELLOW}./scripts/check_sync_status.sh${NC}"
  echo ""

  if [[ "${APPLY_FIXES}" != "true" ]]; then
    echo -e "${YELLOW}This was a check-only run. No changes were made.${NC}"
    echo -e "${YELLOW}Run without --check-only to apply the fixes.${NC}"
    echo ""
  fi
}

# Run the script
main "$@"
