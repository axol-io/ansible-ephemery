#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
# Fast sync script for Ephemery nodes

NC='\033[0m' # No Color

# Load configuration if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "${CONFIG_FILE}" ]; then
  echo -e "${BLUE}Loading configuration from ${CONFIG_FILE}${NC}"
  source "${CONFIG_FILE}"
else
  echo -e "${YELLOW}Configuration file not found, using default paths${NC}"
  # Default paths if config not available
  EPHEMERY_BASE_DIR="/opt/ephemery"
  EPHEMERY_SCRIPTS_DIR="${EPHEMERY_BASE_DIR}/scripts"
fi

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Ephemery Fast Sync Setup${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Check if ansible-playbook is installed
if ! command -v ansible-playbook &>/dev/null; then
  echo -e "${RED}ansible-playbook not found. Please install Ansible first.${NC}"
  exit 1
fi

# Check if user wants to clear existing data
read -p "Clear existing databases for a fresh sync? (y/n): " clear_db
if [[ ${clear_db} == "y" || ${clear_db} == "Y" ]]; then
  echo -e "${YELLOW}Will clear databases for fresh sync${NC}"
  export ANSIBLE_EXTRA_VARS="clear_database=true"
else
  echo -e "${YELLOW}Using existing databases${NC}"
  export ANSIBLE_EXTRA_VARS=""
fi

# Option to specify target host
read -p "Enter target host IP (leave blank for localhost): " target_host
if [[ -n ${target_host} ]]; then
  echo -e "${YELLOW}Updating inventory file with target host: ${target_host}${NC}"
  sed -i.bak "s/ansible_host: [0-9.]*\$/ansible_host: ${target_host}/g" ansible/fast-sync-inventory.yaml
fi

# Option to customize username
read -p "Enter username for SSH connection (leave blank for root): " username
if [[ -n ${username} ]]; then
  echo -e "${YELLOW}Updating inventory file with username: ${username}${NC}"
  sed -i.bak "s/ansible_user: root/ansible_user: ${username}/g" ansible/fast-sync-inventory.yaml
fi

echo -e "${GREEN}Running optimized Ephemery sync...${NC}"
ansible-playbook ansible/playbooks/fast-sync.yaml -i ansible/fast-sync-inventory.yaml -e "${ANSIBLE_EXTRA_VARS}"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Sync started! Monitor progress with:${NC}"
echo -e "${YELLOW}ssh <user>@<host> '${EPHEMERY_SCRIPTS_DIR}/check_sync_status.sh'${NC}"
echo -e "${BLUE}==========================================${NC}"
