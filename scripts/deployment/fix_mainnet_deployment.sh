#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
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
  log_info "Ephemery Mainnet Deployment Fix Script"
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
      -i | --inventory)
        INVENTORY="$2"
        shift 2
        ;;
      -h | --host)
        HOST="$2"
        shift 2
        ;;
      -u | --user)
        SSH_USER="$2"
        shift 2
        ;;
      -k | --key)
        SSH_KEY="$2"
        shift 2
        ;;
      -d | --dir)
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
      -v | --verbose)
        VERBOSE=true
        shift
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        log_error "Error: Unknown option '$1'"
        show_help
        exit 1
        ;;
    esac
  done

  # Validate arguments
  if [[ -z "${INVENTORY}" && -z "${HOST}" ]]; then
    log_error "Error: Either --inventory or --host must be specified"
    show_help
    exit 1
  fi
}

# Get target hosts from inventory
function get_hosts_from_inventory {
  if [[ -n "${INVENTORY}" ]]; then
    if [[ ! -f "${INVENTORY}" ]]; then
      log_error "Error: Inventory file '${INVENTORY}' not found"
      exit 1
    fi

    log_info "Getting hosts from inventory file: ${INVENTORY}"
    # Use ansible-inventory to get hosts
    HOSTS=$(ansible-inventory -i "${INVENTORY}" --list | jq -r '.all.children.ephemery_nodes.hosts | keys[]' 2>/dev/null)

    if [[ -z "${HOSTS}" ]]; then
      log_error "Error: No hosts found in inventory file"
      exit 1
    fi

    log_success "Found hosts: ${HOSTS}"
    return 0
  else
    HOSTS=("${HOST}")
    log_success "Using specified host: ${HOST}"
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
    log_info "SSH command: ${SSH_CMD}"
  fi
}

# Execute command on remote host
function remote_exec {
  local target_host="$1"
  local command="$2"

  build_ssh_cmd "${target_host}"

  if [[ "${VERBOSE}" == "true" ]]; then
    log_info "Executing on ${target_host}: ${command}"
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_warn "[DRY RUN] Would execute: ${SSH_CMD} '${command}'"
    return 0
  fi

  ${SSH_CMD} "${command}"
  return $?
}

# Fix client container configuration
function fix_client_containers {
  local target_host="$1"

  log_info "Fixing client container configuration on ${target_host}..."

  # Check current container configuration
  remote_exec "${target_host}" "docker ps -a | grep -E 'ephemery-(geth|lighthouse)'"

  # Update execution client image
  remote_exec "${target_host}" "sed -i 's|ethereum/client-go:.*|pk910/ephemery-geth:latest|g' ${EPHEMERY_BASE_DIR}/config/docker-compose.yaml"

  # Update consensus client image
  remote_exec "${target_host}" "sed -i 's|sigp/lighthouse:.*|pk910/ephemery-lighthouse:latest|g' ${EPHEMERY_BASE_DIR}/config/docker-compose.yaml"

  log_success "Client container configuration fixed"
}

# Set up Ephemery network directory
function setup_network_directory {
  local target_host="$1"

  log_info "Setting up Ephemery network directory on ${target_host}..."

  # Create network directory if it doesn't exist
  remote_exec "${target_host}" "mkdir -p ${EPHEMERY_BASE_DIR}/network"

  # Download latest genesis files
  remote_exec "${target_host}" "curl -s -o ${EPHEMERY_BASE_DIR}/network/genesis.json https://ephemery.pk910.de/genesis.json"
  remote_exec "${target_host}" "curl -s -o ${EPHEMERY_BASE_DIR}/network/genesis.ssz https://ephemery.pk910.de/genesis.ssz"
  remote_exec "${target_host}" "curl -s -o ${EPHEMERY_BASE_DIR}/network/config.yaml https://ephemery.pk910.de/config.yaml"
  remote_exec "${target_host}" "curl -s -o ${EPHEMERY_BASE_DIR}/network/deploy_block.txt https://ephemery.pk910.de/deploy_block.txt"

  log_success "Ephemery network directory set up"
}

# Fix container parameters
function fix_container_parameters {
  local target_host="$1"

  log_info "Fixing container parameters on ${target_host}..."

  # Update execution client parameters
  remote_exec "${target_host}" "sed -i 's|--datadir=/data.*|--datadir=/data --networkid=\$(cat /network/config.yaml | grep DEPOSIT_NETWORK_ID | cut -d: -f2 | tr -d \" \") --genesis=/network/genesis.json|g' ${EPHEMERY_BASE_DIR}/config/docker-compose.yaml"

  # Update consensus client parameters
  remote_exec "${target_host}" "sed -i 's|--testnet-dir=/data/testnet.*|--testnet-dir=/network|g' ${EPHEMERY_BASE_DIR}/config/docker-compose.yaml"

  # Fix volume mappings
  remote_exec "${target_host}" "sed -i 's|${EPHEMERY_BASE_DIR}/data/testnet:/data/testnet|${EPHEMERY_BASE_DIR}/network:/network|g' ${EPHEMERY_BASE_DIR}/config/docker-compose.yaml"

  log_success "Container parameters fixed"
}

# Fix checkpoint sync
function fix_checkpoint_sync {
  local target_host="$1"

  if [[ "${SKIP_CHECKPOINT}" == "true" ]]; then
    log_warn "Skipping checkpoint sync fix"
    return 0
  fi

  log_info "Fixing checkpoint sync on ${target_host}..."

  # Get latest checkpoint from Ephemery website
  remote_exec "${target_host}" "CHECKPOINT_URL=\$(curl -s https://ephemery.pk910.de/checkpoint) && \
    sed -i \"s|--checkpoint-sync-url=.*|--checkpoint-sync-url=\${CHECKPOINT_URL}|g\" ${EPHEMERY_BASE_DIR}/config/docker-compose.yaml"

  log_success "Checkpoint sync fixed"
}

# Restart services
function restart_services {
  local target_host="$1"

  if [[ "${SKIP_RESTART}" == "true" ]]; then
    log_warn "Skipping service restart"
    return 0
  fi

  log_info "Restarting services on ${target_host}..."

  # Stop containers
  remote_exec "${target_host}" "cd ${EPHEMERY_BASE_DIR} && docker-compose down"

  # Remove old data
  if [[ "${FORCE}" == "true" ]]; then
    remote_exec "${target_host}" "rm -rf ${EPHEMERY_BASE_DIR}/data/geth/ephemery"
    remote_exec "${target_host}" "rm -rf ${EPHEMERY_BASE_DIR}/data/lighthouse/beacon"
  fi

  # Start containers
  remote_exec "${target_host}" "cd ${EPHEMERY_BASE_DIR} && docker-compose up -d"

  log_success "Services restarted"
}

# Verify fix
function verify_fix {
  local target_host="$1"

  log_info "Verifying fix on ${target_host}..."

  # Check if containers are running
  remote_exec "${target_host}" "docker ps | grep -E 'ephemery-(geth|lighthouse)'"

  # Check sync status
  remote_exec "${target_host}" "curl -s http://localhost:5052/eth/v1/node/syncing | jq"

  log_success "Verification complete"
}

# Main function
function main {
  parse_args "$@"
  get_hosts_from_inventory

  for host in ${HOSTS}; do
    log_info "Processing host: ${host}"

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

    log_success "All fixes applied to ${host}"
  done

  log_success "All hosts processed successfully"
}

# Execute main function
main "$@"
