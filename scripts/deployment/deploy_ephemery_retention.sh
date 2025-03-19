#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
#
# Deploy Ephemery Retention Script
# ================================
#
# This script deploys the Ephemery retention setup to enable automatic genesis resets.
# It uses Ansible to:
# - Copy the retention script to the server
# - Set up the cron job
# - Run the script for the first time
# - Validate the installation
#

# Exit immediately if a command exits with a non-zero status
set -e

# Colors for better readability in terminal output

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  Deploying Ephemery Retention Script and Cron Job  ${NC}"
echo -e "${GREEN}====================================================${NC}"

# ========================
# Environment Validation
# ========================

# Verify we're in the correct directory by checking for inventory file
if [ ! -f "inventory.yaml" ]; then
  echo -e "${RED}Error: This script must be run from the ansible-ephemery directory${NC}"
  echo -e "${YELLOW}Change to the ansible-ephemery directory and try again${NC}"
  exit 1
fi

# Verify the Ansible playbook exists
if [ ! -f "playbooks/deploy_ephemery_retention.yml" ]; then
  echo -e "${RED}Error: deploy_ephemery_retention.yml playbook not found${NC}"
  exit 1
fi

# ========================
# Playbook Execution
# ========================

# Run the Ansible playbook with verbose output
echo -e "${YELLOW}Running Ansible playbook to deploy Ephemery retention...${NC}"
ansible-playbook playbooks/deploy_ephemery_retention.yml -v

# ========================
# Deployment Verification
# ========================

# Check if playbook execution was successful
if [ $? -eq 0 ]; then
  echo -e "${GREEN}====================================================${NC}"
  echo -e "${GREEN}  Ephemery Retention Setup Successfully Deployed!   ${NC}"
  echo -e "${GREEN}====================================================${NC}"

  # Display guidance information for monitoring and troubleshooting
  echo -e "${YELLOW}The Ephemery node will now automatically reset to the latest genesis state${NC}"
  echo -e "${YELLOW}Check the retention logs on the server with:${NC}"
  echo -e "  ${GREEN}tail -f /root/ephemery/logs/retention.log${NC}"
  echo -e "${YELLOW}Monitor sync status with:${NC}"
  echo -e "  ${GREEN}docker logs ephemery-lighthouse | grep -E 'slot|sync|distance'${NC}"
else
  # Display error message if deployment failed
  echo -e "${RED}Deployment failed. Please check the error messages above.${NC}"
  exit 1
fi
