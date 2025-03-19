#!/bin/bash
# Script to help identify and prune files that have been consolidated
# as part of the Ephemery repository reorganization.

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "${SCRIPT_DIR}/../..")"
cd "${REPO_ROOT}"

echo -e "${BLUE}Ephemery Repository Consolidation - File Pruning Helper${NC}"
echo "This script will help identify files that can be pruned after consolidation."
echo

function print_section() {
    echo -e "${GREEN}=== $1 ===${NC}"
}

function check_directory_exists() {
    if [ -d "$1" ]; then
        echo -e "${YELLOW}[EXISTS]${NC} $1"
        return 0
    else
        echo -e "${RED}[MISSING]${NC} $1"
        return 1
    fi
}

# Check if necessary consolidated roles exist
print_section "Checking if consolidated roles exist"
ROLE_CHECK_PASSED=true

for role in "common" "execution_client" "consensus_client"; do
    if ! check_directory_exists "ansible/roles/${role}"; then
        ROLE_CHECK_PASSED=false
    fi
done

if [ "$ROLE_CHECK_PASSED" != true ]; then
    echo -e "${RED}Error: Some consolidated roles are missing. Cannot proceed with pruning recommendations.${NC}"
    exit 1
fi

# Identify legacy client configurations
print_section "Legacy client configurations that can be pruned"
if [ -d "ansible/clients" ]; then
    find ansible/clients -type d -mindepth 1 -maxdepth 1 | sort | while read -r client_dir; do
        echo -e "${YELLOW}[LEGACY]${NC} $client_dir"
    done
else
    echo "No legacy client configurations found."
fi

# Identify legacy playbooks
print_section "Legacy playbooks that can be pruned"
LEGACY_PLAYBOOKS=(
    "ansible/main.yaml"
    "ansible/ephemery.yaml" 
    "ansible/validator.yaml"
)

for playbook in "${LEGACY_PLAYBOOKS[@]}"; do
    if [ -f "$playbook" ]; then
        echo -e "${YELLOW}[LEGACY]${NC} $playbook"
    fi
done

if [ -d "ansible/playbooks/clients" ]; then
    find ansible/playbooks/clients -name "*.yaml" -o -name "*.yml" | sort | while read -r playbook; do
        echo -e "${YELLOW}[LEGACY]${NC} $playbook"
    done
fi

# Summarize findings
print_section "Summary"
echo "This script has identified legacy files that might be candidates for pruning."
echo "Before removing any files, ensure that:"
echo "1. All functionality has been migrated to the new consolidated structure"
echo "2. No active deployments rely on these files"
echo "3. You have a backup or the files are versioned in git"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the identified files and confirm they can be safely removed"
echo "2. Update CONSOLIDATION.md to track progress"
echo "3. Create a migration plan for any users of the legacy structure"

exit 0 