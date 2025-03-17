#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0

# prune_migrated_docs.sh
# A script to safely remove documentation files that have been migrated to the PRD structure

set -e

# Colors for output
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Ephemery Documentation Pruner${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "This script will help you prune documentation files that have been migrated to the PRD structure."
echo -e "${YELLOW}Note: This will permanently remove files from the repository.${NC}\n"

# Check if we're in the root directory
if [ ! -d "docs" ] || [ ! -d "scripts" ]; then
  echo -e "${RED}Error: This script must be run from the root directory of the repository.${NC}"
  exit 1
fi

# Array of files to be pruned
declare -a files_to_prune=(
  "docs/EPHEMERY_SETUP.md"
  "docs/EPHEMERY_SCRIPT_REFERENCE.md"
  "docs/EPHEMERY_SPECIFIC.md"
  "docs/VALIDATOR_README.md"
  "docs/VALIDATOR_KEY_MANAGEMENT.md"
  "docs/SYNC_MONITORING.md"
  "docs/CHECKPOINT_SYNC_FIX.md"
  "docs/MONITORING.md"
  "docs/TROUBLESHOOTING.md"
  "docs/IMPLEMENTATION_DETAILS.md"
  "docs/KNOWN_ISSUES.md"
  "docs/CHECKPOINT_SYNC.md"
  "docs/TESTING.md"
  "docs/inventory-management.md"
  "docs/remote-deployment.md"
  "docs/local-deployment.md"
  "docs/configuration.md"
  "docs/VARIABLE_MANAGEMENT.md"
  "docs/REPOSITORY_STRUCTURE.md"
  "docs/VALIDATOR_KEY_RESTORE.md"
  "docs/VALIDATOR_PERFORMANCE_MONITORING.md"
  "docs/DASHBOARD_IMPLEMENTATION.md"
  "docs/CHECKPOINT_SYNC_DASHBOARD.md"
  "docs/CHECKPOINT_SYNC_PERFORMANCE.md"
  "docs/VALIDATOR_STATUS_DASHBOARD.md"
  "docs/INSTATUS_INTEGRATION.md"
  "docs/CONTRIBUTING.md"
  "docs/UNIFIED_DEPLOYMENT.md"
)

# Special files that need confirmation
declare -a special_files=(
  "docs/README.md"
  "docs/CHANGELOG.md"
)

# Count files
total_files=${#files_to_prune[@]}
special_files_count=${#special_files[@]}

echo -e "Found ${total_files} regular files and ${special_files_count} special files that can be pruned.\n"

# Ask for confirmation
echo -e "${YELLOW}Are you sure you want to proceed with pruning these files? (y/n)${NC}"
read -r confirm
if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
  echo -e "${BLUE}Operation cancelled.${NC}"
  exit 0
fi

# Function to check if file has been added to git
file_in_git() {
  git ls-files --error-unmatch "$1" >/dev/null 2>&1
  return $?
}

# Function to safely remove a file
remove_file() {
  local file="$1"
  local force="$2"

  if [ ! -f "${file}" ]; then
    echo -e "${YELLOW}File not found: ${file}${NC}"
    return 1
  fi

  # Check if file has been added to git
  if file_in_git "${file}"; then
    if [ "${force}" == "force" ] || { echo -e "${YELLOW}Remove ${file}? (y/n)${NC}" && read -r confirm && [[ "${confirm}" =~ ^[Yy]$ ]]; }; then
      git rm "${file}"
      echo -e "${GREEN}Removed: ${file}${NC}"
      return 0
    else
      echo -e "${BLUE}Skipping: ${file}${NC}"
      return 1
    fi
  else
    if [ "${force}" == "force" ] || { echo -e "${YELLOW}Remove untracked file ${file}? (y/n)${NC}" && read -r confirm && [[ "${confirm}" =~ ^[Yy]$ ]]; }; then
      rm "${file}"
      echo -e "${GREEN}Removed untracked file: ${file}${NC}"
      return 0
    else
      echo -e "${BLUE}Skipping untracked file: ${file}${NC}"
      return 1
    fi
  fi
}

# Process regular files
echo -e "\n${BLUE}Processing regular files...${NC}"
echo -e "These files can be safely removed as they have been fully migrated to the PRD structure.\n"

removed_count=0
for file in "${files_to_prune[@]}"; do
  if remove_file "${file}" "force"; then
    ((removed_count++))
  fi
done

# Process special files (with extra confirmation)
echo -e "\n${BLUE}Processing special files...${NC}"
echo -e "${YELLOW}These files may require special handling. Please verify before removing.${NC}\n"

special_removed=0
for file in "${special_files[@]}"; do
  echo -e "${YELLOW}${file} might be referenced by external tools or scripts.${NC}"
  if remove_file "${file}"; then
    ((special_removed++))
  fi
done

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}              Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Regular files removed: ${removed_count}/${total_files}"
echo -e "Special files removed: ${special_removed}/${special_files_count}"
echo -e "\nTotal files removed: $((removed_count + special_removed))/$((total_files + special_files_count))"

echo -e "\n${GREEN}Pruning complete!${NC}"
echo -e "${YELLOW}Remember to commit these changes to git with an appropriate message.${NC}"
echo -e "Suggested commit message: \"docs: Remove migrated documentation files\""

exit 0
