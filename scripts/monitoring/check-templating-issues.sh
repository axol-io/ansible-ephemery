#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0

# Script to check for templating issues in Ansible playbooks
# This helps identify recursive variable references and templating problems

set -e

echo "===== Checking for templating issues in Ansible playbooks ====="

# Define colors for output

# Function to run ansible-playbook in check mode with verbose output
check_playbook() {
  local playbook=$1
  local inventory=$2

  echo -e "${YELLOW}Checking playbook: ${playbook} with inventory: ${inventory}${NC}"

  # Run ansible-playbook in check mode with verbose output
  ansible-playbook -i "${inventory}" "${playbook}" --check -vvv

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ No templating issues found in ${playbook}${NC}"
    return 0
  else
    echo -e "${RED}❌ Templating issues found in ${playbook}${NC}"
    return 1
  fi
}

# Check specific files
INVENTORY_FILE="inventory.yaml"
MAIN_PLAYBOOK="ansible/playbooks/ephemery.yaml"

# Run checks
check_result=0

echo "Checking main playbook..."
check_playbook "${MAIN_PLAYBOOK}" "${INVENTORY_FILE}"
if [ $? -ne 0 ]; then
  check_result=1
fi

# If any checks failed, provide troubleshooting guidance
if [ ${check_result} -ne 0 ]; then
  echo -e "${RED}===== Templating issues detected! =====${NC}"
  echo -e "${YELLOW}Troubleshooting tips:${NC}"
  echo "1. Look for recursive variable references (variables that reference themselves)"
  echo "2. Check for undefined variables or dictionary keys"
  echo "3. Make sure all required variables are defined in inventory or defaults"
  echo "4. Use '--syntax-check' flag with ansible-playbook for a more focused check"
  echo "5. Consider using 'ansible-inventory -i inventory.yaml --graph --vars' to debug variable values"
  exit 1
else
  echo -e "${GREEN}===== All templating checks passed! =====${NC}"
  exit 0
fi
