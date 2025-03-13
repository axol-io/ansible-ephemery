#!/bin/bash
#
# Ephemery Mainnet Deployment Fix Script
# ======================================
#
# This script addresses common issues with Ephemery mainnet deployments:
# 1. Fixes client container configuration with proper Ephemery-specific images
# 2. Sets up the Ephemery network directory with the latest genesis
# 3. Fixes container parameters to correctly reference the testnet directory
# 4. Fixes checkpoint sync issues
# 5. Restarts services to apply all fixes
#

set -e

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
INVENTORY=""
HOST=""
SSH_USER="root"
SSH_KEY=""
EPHEMERY_BASE_DIR="/opt/ephemery"
VERBOSE=false
DRY_RUN=false
FORCE=false
SKIP_RESTART=false
SKIP_CHECKPOINT=false

# Help function
function show_help {
  echo -e "${BLUE}Ephemery Mainnet Deployment Fix Script${NC}"
  echo ""
  echo "This script addresses common issues with Ephemery mainnet deployments."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -i, --inventory FILE     Ansible inventory file"
  echo "  -h, --host HOST          Target host (IP or hostname)"
  echo "  -u, --user USER          SSH user (default: root)"
  echo "  -k, --key FILE           SSH private key file"
  echo "  -d, --dir PATH           Ephemery base directory (default: /opt/ephemery)"
  echo "  --skip-restart           Skip service restart"
  echo "  --skip-checkpoint        Skip checkpoint sync fix"
  echo "  --dry-run                Show what would be done without making changes"
  echo "  --force                  Force operations without confirmation"
  echo "  -v, --verbose            Enable verbose output"
  echo "  --help                   Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --inventory production-inventory.yaml"
  echo "  $0 --host 192.168.1.100 --user admin --key ~/.ssh/id_rsa"
}

# Parse command line arguments
function parse_args {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--inventory)
        INVENTORY="$2"
        shift 2
        ;;
      -h|--host)
        HOST="$2"
        shift 2
        ;;
      -u|--user)
        SSH_USER="$2"
        shift 2
        ;;
      -k|--key)
        SSH_KEY="$2"
        shift 2
        ;;
      -d|--dir)
        EPHEMERY_BASE_DIR="$2"
        shift 2
        ;;
      --skip-restart)
        SKIP_RESTART=true
        shift
        ;;
      --skip-checkpoint)
        SKIP_CHECKPOINT=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        echo -e "${RED}Error: Unknown option '$1'${NC}"
        show_help
        exit 1
        ;;
    esac
  done

  # Validate arguments
  if [[ -z "${INVENTORY}" && -z "${HOST}" ]]; then
    echo -e "${RED}Error: Either --inventory or --host must be specified${NC}"
    show_help
    exit 1
  fi
}

# Get target hosts from inventory
function get_hosts_from_inventory {
  if [[ -n "${INVENTORY}" ]]; then
    if [[ ! -f "${INVENTORY}" ]]; then
      echo -e "${RED}Error: Inventory file '${INVENTORY}' not found${NC}"
      exit 1
    fi

    echo -e "${BLUE}Getting hosts from inventory file: ${INVENTORY}${NC}"
    # Use ansible-inventory to get hosts
    HOSTS=$(ansible-inventory -i "${INVENTORY}" --list | jq -r '.all.children.ephemery_nodes.hosts | keys[]' 2>/dev/null)

    if [[ -z "${HOSTS}" ]]; then
      echo -e "${RED}Error: No hosts found in inventory file${NC}"
      exit 1
    fi

    echo -e "${GREEN}Found hosts: ${HOSTS}${NC}"
    return 0
  else
    HOSTS=("${HOST}")
    echo -e "${GREEN}Using specified host: ${HOST}${NC}"
    return 0
  fi
}

# Build SSH command
function build_ssh_cmd {
  local target_host="$1"
  SSH_CMD="ssh"

  if [[ -n "${SSH_KEY}" ]]; then
    SSH_CMD="${SSH_CMD} -i ${SSH_KEY}"
  fi

  SSH_CMD="${SSH_CMD} ${SSH_USER}@${target_host}"

  if [[ "${VERBOSE}" == "true" ]]; then
    echo -e "${BLUE}SSH command: ${SSH_CMD}${NC}"
  fi
}

# Execute command on remote host
function remote_exec {
  local target_host="$1"
  local command="$2"

  build_ssh_cmd "${target_host}"

  if [[ "${VERBOSE}" == "true" ]]; then
    echo -e "${BLUE}Executing on ${target_host}: ${command}${NC}"
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN] Would execute: ${SSH_CMD} '${command}'${NC}"
    return 0
  fi

  ${SSH_CMD} "${command}"
  return $?
}

# Fix client container configuration
function fix_client_containers {
  local target_host="$1"

  echo -e "${BLUE}Fixing client container configuration on ${target_host}...${NC}"

  # Check current container configuration
  remote_exec "${target_host}" "docker ps -a | grep -E 'ephemery-(geth|lighthouse)'"

  # Update execution client image
  remote_exec "${target_host}" "sed -i 's|ethereum/client-go:.*|pk910/ephemery-geth:latest|g' ${EPHEMERY_BASE_DIR}/config/docker-compose.yaml"

  # Update consensus client image
  remote_exec "${target_host}" "sed -i 's|sigp/lighthouse:.*|pk910/ephemery-lighthouse:latest|g' ${EPHEMERY_BASE_DIR}/config/docker-compose.yaml"

  echo -e "${GREEN}✓ Client container configuration fixed${NC}"
}

# Set up Ephemery network directory
function setup_network_directory {
  local target_host="$1"

  echo -e "${BLUE}Setting up Ephemery network directory on ${target_host}...${NC}"

  # Create network directory if it doesn't exist
  remote_exec "${target_host}" "mkdir -p ${EPHEMERY_BASE_DIR}/network"

  # Download latest genesis files
  remote_exec "${target_host}" "curl -s -o ${EPHEMERY_BASE_DIR}/network/genesis.json https://ephemery.pk910.de/genesis.json"
  remote_exec "${target_host}" "curl -s -o ${EPHEMERY_BASE_DIR}/network/genesis.ssz https://ephemery.pk910.de/genesis.ssz"
  remote_exec "${target_host}" "curl -s -o ${EPHEMERY_BASE_DIR}/network/config.yaml https://ephemery.pk910.de/config.yaml"
  remote_exec "${target_host}" "curl -s -o ${EPHEMERY_BASE_DIR}/network/deploy_block.txt https://ephemery.pk910.de/deploy_block.txt"

  echo -e "${GREEN}✓ Ephemery network directory set up${NC}"
}

# Fix container parameters
function fix_container_parameters {
  local target_host="$1"

  echo -e "${BLUE}Fixing container parameters on ${target_host}...${NC}"

  # Update execution client parameters
  remote_exec "${target_host}" "sed -i 's|--datadir=/data.*|--datadir=/data --networkid=\$(cat /network/config.yaml | grep DEPOSIT_NETWORK_ID | cut -d: -f2 | tr -d \" \") --genesis=/network/genesis.json|g' ${EPHEMERY_BASE_DIR}/config/docker-compose.yaml"

  # Update consensus client parameters
  remote_exec "${target_host}" "sed -i 's|--testnet-dir=/data/testnet.*|--testnet-dir=/network|g' ${EPHEMERY_BASE_DIR}/config/docker-compose.yaml"

  # Fix volume mappings
  remote_exec "${target_host}" "sed -i 's|${EPHEMERY_BASE_DIR}/data/testnet:/data/testnet|${EPHEMERY_BASE_DIR}/network:/network|g' ${EPHEMERY_BASE_DIR}/config/docker-compose.yaml"

  echo -e "${GREEN}✓ Container parameters fixed${NC}"
}

# Fix checkpoint sync
function fix_checkpoint_sync {
  local target_host="$1"

  if [[ "${SKIP_CHECKPOINT}" == "true" ]]; then
    echo -e "${YELLOW}Skipping checkpoint sync fix${NC}"
    return 0
  fi

  echo -e "${BLUE}Fixing checkpoint sync on ${target_host}...${NC}"

  # Get latest checkpoint from Ephemery website
  remote_exec "${target_host}" "CHECKPOINT_URL=\$(curl -s https://ephemery.pk910.de/checkpoint) && \
    sed -i \"s|--checkpoint-sync-url=.*|--checkpoint-sync-url=\${CHECKPOINT_URL}|g\" ${EPHEMERY_BASE_DIR}/config/docker-compose.yaml"

  echo -e "${GREEN}✓ Checkpoint sync fixed${NC}"
}

# Restart services
function restart_services {
  local target_host="$1"

  if [[ "${SKIP_RESTART}" == "true" ]]; then
    echo -e "${YELLOW}Skipping service restart${NC}"
    return 0
  fi

  echo -e "${BLUE}Restarting services on ${target_host}...${NC}"

  # Stop containers
  remote_exec "${target_host}" "cd ${EPHEMERY_BASE_DIR} && docker-compose down"

  # Remove old data
  if [[ "${FORCE}" == "true" ]]; then
    remote_exec "${target_host}" "rm -rf ${EPHEMERY_BASE_DIR}/data/geth/ephemery"
    remote_exec "${target_host}" "rm -rf ${EPHEMERY_BASE_DIR}/data/lighthouse/beacon"
  fi

  # Start containers
  remote_exec "${target_host}" "cd ${EPHEMERY_BASE_DIR} && docker-compose up -d"

  echo -e "${GREEN}✓ Services restarted${NC}"
}

# Verify fix
function verify_fix {
  local target_host="$1"

  echo -e "${BLUE}Verifying fix on ${target_host}...${NC}"

  # Check if containers are running
  remote_exec "${target_host}" "docker ps | grep -E 'ephemery-(geth|lighthouse)'"

  # Check sync status
  remote_exec "${target_host}" "curl -s http://localhost:5052/eth/v1/node/syncing | jq"

  echo -e "${GREEN}✓ Verification complete${NC}"
}

# Main function
function main {
  parse_args "$@"
  get_hosts_from_inventory

  for host in ${HOSTS}; do
    echo -e "${BLUE}Processing host: ${host}${NC}"

    # Fix client container configuration
    fix_client_containers "${host}"

    # Set up Ephemery network directory
    setup_network_directory "${host}"

    # Fix container parameters
    fix_container_parameters "${host}"

    # Fix checkpoint sync
    fix_checkpoint_sync "${host}"

    # Restart services
    restart_services "${host}"

    # Verify fix
    verify_fix "${host}"

    echo -e "${GREEN}✓ All fixes applied to ${host}${NC}"
  done

  echo -e "${GREEN}✓ All hosts processed successfully${NC}"
}

# Execute main function
main "$@"
