#!/bin/bash

# Validate Container Names Script
# This script checks for inconsistent container naming across the codebase
# Version: 1.0.0

# Ensure we're in the project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "${PROJECT_ROOT}" || {
  echo "Failed to change to project root"
  exit 1
}

# Source path configuration to get standardized names
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CORE_DIR="${PROJECT_ROOT}/scripts/core"
if [[ -f "${CORE_DIR}/path_config.sh" ]]; then
  source "${CORE_DIR}/path_config.sh"
else
  echo "Error: path_config.sh not found in ${CORE_DIR}"
  exit 1
fi

# Source common library for logging functions
if [[ -f "${CORE_DIR}/common.sh" ]]; then
  source "${CORE_DIR}/common.sh"
else
  echo "Error: common.sh not found in ${CORE_DIR}"
  exit 1
fi

# Print header
echo -e "${BOLD}${CYAN}====== Ephemery Container Name Validator ======${NC}"
echo -e "Checking for inconsistent container naming conventions...\n"

# Define the standard container names
STANDARD_EXECUTION_CONTAINER="${EPHEMERY_EXECUTION_CONTAINER}" # e.g., ephemery-execution-geth
STANDARD_CONSENSUS_CONTAINER="${EPHEMERY_CONSENSUS_CONTAINER}" # e.g., ephemery-consensus-lighthouse
STANDARD_VALIDATOR_CONTAINER="${EPHEMERY_VALIDATOR_CONTAINER}" # e.g., ephemery-validator-lighthouse

# Define legacy/non-standard container names to check
LEGACY_EXECUTION_NAMES=("ephemery-geth")
LEGACY_CONSENSUS_NAMES=("ephemery-lighthouse")
LEGACY_VALIDATOR_NAMES=("ephemery-validator" "ephemery-validator-lighthouse")

# Define non-standard patterns to look for
NONSTANDARD_PATTERNS=(
  "ephemery-geth"
  "ephemery-lighthouse"
  "ephemery-validator"
  "ephemery-validator-lighthouse"
  'network.*-validator-.*cl'
)

# Function to count occurrences of a pattern in the codebase (excluding git, node_modules)
count_occurrences() {
  local pattern="$1"
  local count=$(grep -r --include="*.sh" --include="*.yaml" --include="*.yml" \
    --include="*.md" --include="Dockerfile*" --include="docker-compose*" \
    -l "${pattern}" . \
    | grep -v "node_modules\|\.git\|validate_container_names.sh" \
    | wc -l | tr -d ' ')
  echo "${count}"
}

# Function to print a file list with occurrences of a pattern
list_files_with_pattern() {
  local pattern="$1"
  local max_files="${2:-10}"
  local files=$(grep -r --include="*.sh" --include="*.yaml" --include="*.yml" \
    --include="*.md" --include="Dockerfile*" --include="docker-compose*" \
    -l "${pattern}" . \
    | grep -v "node_modules\|\.git\|validate_container_names.sh" \
    | head -n "${max_files}")

  if [[ -n "${files}" ]]; then
    echo -e "${YELLOW}Files containing pattern '${pattern}':${NC}"
    echo "${files}" | sed 's/^/  - /'

    # If there are more files than the limit, print a message
    local total_count=$(count_occurrences "${pattern}")
    if ((total_count > max_files)); then
      echo -e "  ... and $((total_count - max_files)) more files"
    fi
    echo ""
  fi
}

# Check for non-standard container names
echo -e "${BOLD}Checking for Non-Standard Container Names:${NC}"
echo -e "${CYAN}Standardized Names (recommended):${NC}"
echo -e "  Execution Client: ${GREEN}${STANDARD_EXECUTION_CONTAINER}${NC}"
echo -e "  Consensus Client: ${GREEN}${STANDARD_CONSENSUS_CONTAINER}${NC}"
echo -e "  Validator Client: ${GREEN}${STANDARD_VALIDATOR_CONTAINER}${NC}"
echo ""

# Count and output stats for non-standard patterns
total_issues=0
echo -e "${BOLD}${YELLOW}Container Pattern Issues:${NC}"

for pattern in "${NONSTANDARD_PATTERNS[@]}"; do
  count=$(count_occurrences "${pattern}")
  total_issues=$((total_issues + count))

  if [[ ${count} -gt 0 ]]; then
    echo -e "${YELLOW}Found ${count} occurrences of non-standard pattern:${NC} ${pattern}"
    list_files_with_pattern "${pattern}" 5
  fi
done

# Output for Ansible variable patterns like {{ network }}-validator-{{ cl }}
ansible_pattern='{{ network }}-validator-{{ cl }}'
ansible_count=$(grep -r --include="*.yaml" --include="*.yml" -l 'name: "{{ network }}-validator-{{ cl }}"' . | wc -l | tr -d ' ')
total_issues=$((total_issues + ansible_count))

if [[ ${ansible_count} -gt 0 ]]; then
  echo -e "${YELLOW}Found ${ansible_count} occurrences of Ansible template pattern:${NC} ${ansible_pattern}"
  grep -r --include="*.yaml" --include="*.yml" -l 'name: "{{ network }}-validator-{{ cl }}"' . | head -n 5 | sed 's/^/  - /'
  echo ""
fi

# Summary report
echo -e "${BOLD}===== Summary Report =====${NC}"
if [[ ${total_issues} -eq 0 ]]; then
  echo -e "${GREEN}✓ No container naming issues found. All container names follow the standardized convention.${NC}"
else
  echo -e "${YELLOW}! Found ${total_issues} container naming issues.${NC}"

  # Print recommendation
  echo -e "\n${BOLD}Recommendation:${NC}"
  echo -e "Update container names to follow the standardized convention:"
  echo -e "  {network}-{role}-{client}"
  echo -e "Examples:"
  echo -e "  ${GREEN}${EPHEMERY_NETWORK}-execution-${EPHEMERY_EXECUTION_CLIENT}${NC} (instead of ephemery-geth)"
  echo -e "  ${GREEN}${EPHEMERY_NETWORK}-consensus-${EPHEMERY_CONSENSUS_CLIENT}${NC} (instead of ephemery-lighthouse)"
  echo -e "  ${GREEN}${EPHEMERY_NETWORK}-validator-${EPHEMERY_VALIDATOR_CLIENT}${NC} (instead of ephemery-validator)"

  # How to fix
  echo -e "\n${BOLD}How to fix:${NC}"
  echo -e "1. Use the standardized container variables from path_config.sh:"
  echo -e "   - ${GREEN}EPHEMERY_EXECUTION_CONTAINER${NC} instead of hardcoded container names"
  echo -e "   - ${GREEN}EPHEMERY_CONSENSUS_CONTAINER${NC} instead of hardcoded container names"
  echo -e "   - ${GREEN}EPHEMERY_VALIDATOR_CONTAINER${NC} instead of hardcoded container names"
  echo -e "2. For Ansible playbooks, use the updated container variables from paths.yaml:"
  echo -e "   - ${GREEN}{{ ephemery_containers.execution }}${NC} instead of hardcoded container names"
  echo -e "   - ${GREEN}{{ ephemery_containers.consensus }}${NC} instead of hardcoded container names"
  echo -e "   - ${GREEN}{{ ephemery_containers.validator }}${NC} instead of hardcoded container names"
fi

exit $((total_issues > 0))
