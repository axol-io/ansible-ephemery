#!/bin/bash
# Version: 1.0.0
# Script to run the fix_checkpoint_sync.yaml playbook

# Set strict error handling
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Check if ansible-playbook command is available
if ! command -v ansible-playbook &>/dev/null; then
  echo -e "${RED}Error: ansible-playbook command not found.${NC}"
  echo -e "Please install Ansible before running this script."
  exit 1
fi

# Display banner
echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}    Ephemery Checkpoint Sync Fix Utility    ${NC}"
echo -e "${BLUE}======================================================${NC}"
echo ""
echo -e "${YELLOW}This script will run the fix_checkpoint_sync.yaml playbook${NC}"
echo -e "${YELLOW}to resolve checkpoint sync issues on your Ephemery node.${NC}"
echo ""
echo -e "Actions that will be performed:"
echo -e " * Test multiple checkpoint sync URLs"
echo -e " * Update your inventory file with working settings"
echo -e " * Reset Lighthouse database for a clean sync"
echo -e " * Configure Lighthouse with optimized parameters"
echo -e " * Create monitoring scripts for ongoing sync maintenance"
echo ""
echo -e "${RED}WARNING: This will stop and restart your Lighthouse container${NC}"
echo -e "${RED}and clear the database for a fresh checkpoint sync.${NC}"
echo ""

# Ask for confirmation
read -r -p "Do you want to continue? [y/N] " REPLY
echo ""
if [[ ! "${REPLY}" =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Operation cancelled.${NC}"
  exit 0
fi

# Check if inventory file exists
INVENTORY_FILE="${PROJECT_ROOT}/inventories/inventory.yaml"
if [ ! -f "${INVENTORY_FILE}" ]; then
  echo -e "${RED}Error: inventory.yaml not found.${NC}"
  echo -e "Please check that the inventory file exists at ${INVENTORY_FILE}"
  exit 1
fi

# Check if fix_checkpoint_sync.yaml exists
PLAYBOOK_FILE="${PROJECT_ROOT}/ansible/playbooks/fix_checkpoint_sync.yaml"
if [ ! -f "${PLAYBOOK_FILE}" ]; then
  echo -e "${RED}Error: fix_checkpoint_sync.yaml not found.${NC}"
  echo -e "The playbook file should be in the ansible/playbooks directory."
  exit 1
fi

# Backup inventory file
echo -e "${YELLOW}Creating backup of inventory file...${NC}"
BACKUP_FILE="${INVENTORY_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "${INVENTORY_FILE}" "${BACKUP_FILE}"
if [ $? -ne 0 ]; then
  echo -e "${RED}Error: Failed to create backup file.${NC}"
  exit 1
fi
echo -e "${GREEN}Backup created: ${BACKUP_FILE}${NC}"

# Run the playbook
echo -e "${YELLOW}Running the fix_checkpoint_sync.yaml playbook...${NC}"
echo -e "${BLUE}======================================================${NC}"
ansible-playbook "${PLAYBOOK_FILE}" -i "${INVENTORY_FILE}"
RESULT=$?
echo -e "${BLUE}======================================================${NC}"

# Check result
if [ ${RESULT} -eq 0 ]; then
  echo -e "${GREEN}Checkpoint sync fix completed successfully!${NC}"
  echo ""
  echo -e "Next steps:"
  echo -e "1. Check the sync status with: ${YELLOW}./scripts/check_sync_status.sh${NC}"
  echo -e "2. Monitor sync progress with: ${YELLOW}./scripts/checkpoint_sync_monitor.sh${NC}"
  echo -e "3. If issues persist, refer to: ${YELLOW}docs/CHECKPOINT_SYNC_FIX.md${NC}"
  echo ""
else
  echo -e "${RED}Checkpoint sync fix encountered errors.${NC}"
  echo -e "Please check the output above for specific error messages."
  echo -e "You can also check: ${YELLOW}docs/CHECKPOINT_SYNC_FIX.md${NC} for troubleshooting steps."
  echo ""
fi

echo -e "${BLUE}======================================================${NC}"
echo -e "For more information, see the documentation in:"
echo -e "${YELLOW}docs/CHECKPOINT_SYNC_FIX.md${NC}"
echo -e "${BLUE}======================================================${NC}"

exit ${RESULT}
