#!/bin/bash
# Version: 1.0.0

# Ephemery Path Validation Script
# This script checks that all Ephemery components are using the standardized paths configuration

set -e

# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Ephemery Path Validation ===${NC}"
echo -e "${BLUE}Checking if all components use standardized paths...${NC}"

# Path to the standard config
STANDARD_CONFIG="/opt/ephemery/config/ephemery_paths.conf"

# Main Ephemery workspace directory
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo -e "${YELLOW}Using workspace directory: ${WORKSPACE_DIR}${NC}"

# Check if the standard config exists
if [ ! -f "${STANDARD_CONFIG}" ]; then
  echo -e "${RED}Standard configuration file not found at ${STANDARD_CONFIG}${NC}"

  # Check if it exists in the workspace
  WORKSPACE_CONFIG="${WORKSPACE_DIR}/config/ephemery_paths.conf"
  if [ -f "${WORKSPACE_CONFIG}" ]; then
    echo -e "${YELLOW}Configuration file found in workspace at ${WORKSPACE_CONFIG}${NC}"
    echo -e "${YELLOW}Consider copying it to the standard location${NC}"
  else
    echo -e "${RED}Configuration file not found in workspace either${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}Standard configuration file exists at ${STANDARD_CONFIG}${NC}"
fi

# Arrays to track validation results
declare -a COMPLIANT_FILES
declare -a NON_COMPLIANT_FILES

# Function to check a shell script for config file usage
check_script() {
  local file="$1"
  local basename=$(basename "${file}")

  # Skip if we've already checked this file
  if [[ " ${COMPLIANT_FILES[*]} " =~ " ${basename} " ]] || [[ " ${NON_COMPLIANT_FILES[*]} " =~ " ${basename} " ]]; then
    return
  fi

  echo -e "${BLUE}Checking ${basename}...${NC}"

  # Check for existence of config loading code
  if grep -q "ephemery_paths.conf" "${file}"; then
    # Check if the file sources the config file properly
    # Look for either direct sourcing or sourcing through a variable
    if grep -q "source.*ephemery_paths.conf" "${file}" || grep -q "\. .*ephemery_paths.conf" "${file}" \
      || (grep -q "CONFIG_FILE.*ephemery_paths.conf" "${file}" && grep -q "source.*CONFIG_FILE" "${file}"); then
      echo -e "${GREEN}✓ ${basename} sources the config file${NC}"
      COMPLIANT_FILES+=("${basename}")
    else
      echo -e "${YELLOW}⚠ ${basename} references the config file but may not source it properly${NC}"
      NON_COMPLIANT_FILES+=("${basename}")
    fi
  else
    # Check if it uses hardcoded paths that should come from config
    if grep -q "EPHEMERY_BASE_DIR=" "${file}" || grep -q "JWT_SECRET" "${file}" || grep -q "/opt/ephemery" "${file}"; then
      echo -e "${RED}✗ ${basename} uses hardcoded paths but doesn't reference the config file${NC}"
      NON_COMPLIANT_FILES+=("${basename}")
    else
      echo -e "${BLUE}- ${basename} doesn't seem to need path configuration${NC}"
    fi
  fi
}

# Function to check YAML files (playbooks, etc.)
check_yaml() {
  local file="$1"
  local basename=$(basename "${file}")

  echo -e "${BLUE}Checking ${basename}...${NC}"

  # For YAML files, check if they reference the config file or use the standardized variable names
  if grep -q "ephemery_paths.conf" "${file}"; then
    echo -e "${GREEN}✓ ${basename} references the config file${NC}"
    COMPLIANT_FILES+=("${basename}")
  elif grep -q "ephemery_config_dir" "${file}" && grep -q "ephemery_base_dir" "${file}"; then
    echo -e "${GREEN}✓ ${basename} uses standardized variable names${NC}"
    COMPLIANT_FILES+=("${basename}")
  else
    if grep -q "/opt/ephemery" "${file}"; then
      echo -e "${RED}✗ ${basename} may use hardcoded paths${NC}"
      NON_COMPLIANT_FILES+=("${basename}")
    else
      echo -e "${BLUE}- ${basename} doesn't seem to need path configuration${NC}"
    fi
  fi
}

echo -e "\n${YELLOW}Checking core scripts...${NC}"
# Using process substitution instead of pipe to avoid subshell issues with arrays
while read -r script; do
  check_script "${script}"
done < <(find "${WORKSPACE_DIR}/scripts/core" -name "*.sh" -type f)

echo -e "\n${YELLOW}Checking local scripts...${NC}"
while read -r script; do
  check_script "${script}"
done < <(find "${WORKSPACE_DIR}/scripts/local" -name "*.sh" -type f)

echo -e "\n${YELLOW}Checking remote scripts...${NC}"
while read -r script; do
  check_script "${script}"
done < <(find "${WORKSPACE_DIR}/scripts/remote" -name "*.sh" -type f)

echo -e "\n${YELLOW}Checking monitoring scripts...${NC}"
while read -r script; do
  check_script "${script}"
done < <(find "${WORKSPACE_DIR}/scripts/monitoring" -name "*.sh" -type f)

echo -e "\n${YELLOW}Checking utility scripts...${NC}"
while read -r script; do
  check_script "${script}"
done < <(find "${WORKSPACE_DIR}/scripts/utilities" -name "*.sh" -type f | grep -v "validate_paths.sh")

echo -e "\n${YELLOW}Checking maintenance scripts...${NC}"
while read -r script; do
  check_script "${script}"
done < <(find "${WORKSPACE_DIR}/scripts/maintenance" -name "*.sh" -type f)

echo -e "\n${YELLOW}Checking playbooks...${NC}"
while read -r playbook; do
  check_yaml "${playbook}"
done < <(find "${WORKSPACE_DIR}/playbooks" -name "*.yml" -type f)

echo -e "\n${YELLOW}Checking Ansible inventories...${NC}"
while read -r inventory; do
  check_yaml "${inventory}"
done < <(find "${WORKSPACE_DIR}/inventories" -name "*.yaml" -type f)

# Summary report
echo -e "\n${BLUE}=== Validation Summary ===${NC}"
echo -e "${GREEN}Compliant files (${#COMPLIANT_FILES[@]}):${NC}"
for file in "${COMPLIANT_FILES[@]}"; do
  echo -e "${GREEN}- ${file}${NC}"
done

echo -e "\n${RED}Non-compliant files (${#NON_COMPLIANT_FILES[@]}):${NC}"
for file in "${NON_COMPLIANT_FILES[@]}"; do
  echo -e "${RED}- ${file}${NC}"
done

if [ ${#NON_COMPLIANT_FILES[@]} -eq 0 ]; then
  echo -e "\n${GREEN}✓ All checked files are using standardized paths${NC}"
  exit 0
else
  echo -e "\n${YELLOW}⚠ Some files need to be updated to use standardized paths${NC}"
  echo -e "${YELLOW}Please update the listed non-compliant files to source ${STANDARD_CONFIG}${NC}"
  exit 1
fi
