#!/bin/bash
# Version: 1.0.0
# deploy_enhanced_key_restore.sh - Deploy the enhanced validator key restore system
#
# This script deploys the enhanced validator key restore system using Ansible

set -eo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLAYBOOK="${REPO_ROOT}/playbooks/setup_enhanced_key_restore.yml"

# Default settings
INVENTORY="${REPO_ROOT}/inventory.yaml"
VERBOSE=false
FORCE=false
INTERVAL="hourly"
CUSTOM_SCHEDULE="*/15 * * * *"
HOST_LIMIT=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage information
function print_usage() {
  echo -e "${BLUE}Deploy Enhanced Validator Key Restore System${NC}"
  echo
  echo "This script deploys the enhanced validator key restore system using Ansible."
  echo
  echo -e "${YELLOW}Usage:${NC}"
  echo "  $0 [options]"
  echo
  echo -e "${YELLOW}Options:${NC}"
  echo "  -i, --inventory FILE    Specify inventory file (default: ${INVENTORY})"
  echo "  -l, --limit HOST        Limit execution to specified host or group"
  echo "  --interval TYPE         Cron interval type: hourly, daily, custom (default: hourly)"
  echo "  --schedule CRON         Custom cron schedule (default: '*/15 * * * *')"
  echo "  -f, --force             Force install without confirmation"
  echo "  -v, --verbose           Enable verbose output"
  echo "  -h, --help              Show this help message"
  echo
  echo -e "${YELLOW}Examples:${NC}"
  echo "  # Deploy to all hosts in inventory"
  echo "  $0"
  echo
  echo "  # Deploy to specific host with daily schedule"
  echo "  $0 --limit ephemery1 --interval daily"
  echo
  echo "  # Deploy with custom schedule"
  echo "  $0 --interval custom --schedule '*/5 * * * *'"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case ${key} in
    -h | --help)
      print_usage
      exit 0
      ;;
    -i | --inventory)
      INVENTORY="$2"
      shift
      shift
      ;;
    -l | --limit)
      HOST_LIMIT="$2"
      shift
      shift
      ;;
    --interval)
      INTERVAL="$2"
      shift
      shift
      ;;
    --schedule)
      CUSTOM_SCHEDULE="$2"
      shift
      shift
      ;;
    -f | --force)
      FORCE=true
      shift
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      print_usage
      exit 1
      ;;
  esac
done

# Check if playbook exists
if [[ ! -f "${PLAYBOOK}" ]]; then
  echo -e "${RED}Error: Playbook not found: ${PLAYBOOK}${NC}"
  exit 1
fi

# Check if inventory exists
if [[ ! -f "${INVENTORY}" ]]; then
  echo -e "${RED}Error: Inventory file not found: ${INVENTORY}${NC}"
  exit 1
fi

# Display configuration
echo -e "${BLUE}Enhanced Validator Key Restore System Deployment Configuration:${NC}"
echo "  Playbook: ${PLAYBOOK}"
echo "  Inventory: ${INVENTORY}"
if [[ -n "${HOST_LIMIT}" ]]; then
  echo "  Host limit: ${HOST_LIMIT}"
fi
echo "  Cron interval: ${INTERVAL}"
if [[ "${INTERVAL}" == "custom" ]]; then
  echo "  Custom schedule: ${CUSTOM_SCHEDULE}"
fi
echo "  Force install: ${FORCE}"
echo "  Verbose mode: ${VERBOSE}"
echo

# Confirm deployment
if [[ "${FORCE}" != "true" ]]; then
  read -p "Deploy enhanced validator key restore system? (y/n) " -n 1 -r
  echo
  if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled.${NC}"
    exit 0
  fi
fi

# Build ansible command
ANSIBLE_CMD="ansible-playbook ${PLAYBOOK} -i ${INVENTORY}"

# Add limit if specified
if [[ -n "${HOST_LIMIT}" ]]; then
  ANSIBLE_CMD="${ANSIBLE_CMD} --limit ${HOST_LIMIT}"
fi

# Add extra vars
ANSIBLE_CMD="${ANSIBLE_CMD} --extra-vars \"cron_interval=${INTERVAL} custom_schedule='${CUSTOM_SCHEDULE}' force_install=${FORCE} verbose_mode=${VERBOSE}\""

# Display and execute command
echo -e "${GREEN}Executing:${NC} ${ANSIBLE_CMD}"
echo
eval "${ANSIBLE_CMD}"

exit_code=$?

if [[ ${exit_code} -eq 0 ]]; then
  echo -e "${GREEN}Enhanced validator key restore system deployed successfully!${NC}"
  echo
  echo -e "Next steps:"
  echo -e "1. Check logs in ~/ephemery/data/logs/ for system activity"
  echo -e "2. Test manual key restore with: ~/ephemery/scripts/utilities/ephemery_key_restore_wrapper.sh --dry-run"
  echo -e "3. Test reset handler with: ~/ephemery/scripts/core/ephemery_reset_handler.sh --dry-run"
  echo
  exit 0
else
  echo -e "${RED}Deployment failed with exit code ${exit_code}${NC}"
  exit ${exit_code}
fi
