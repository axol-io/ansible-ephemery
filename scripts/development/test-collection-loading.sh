#!/usr/bin/env bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0

# Script to test Ansible collection loading to verify our configuration fixes

set -e

# Colors for output

echo -e "${YELLOW}Testing Ansible Collection Loading${NC}"
echo "------------------------------------"

# Determine the root of the repository
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
COLLECTIONS_DIR="${REPO_ROOT}/collections"

echo "Repository root: ${REPO_ROOT}"
echo "Collections directory: ${COLLECTIONS_DIR}"

# Set environment variables for test
export ANSIBLE_COLLECTIONS_PATH="${COLLECTIONS_DIR}"
export ANSIBLE_COLLECTIONS_SCAN_SYS_PATH=false

echo
echo -e "${YELLOW}Testing with ansible-inventory command:${NC}"
ansible-inventory --version

echo
echo -e "${YELLOW}Verifying collections loading paths:${NC}"
ansible-config dump | grep COLLECTIONS

echo
echo -e "${YELLOW}Testing community.docker collection import:${NC}"
python3 -c "from ansible.plugins.loader import module_loader; print('docker_container module path:', module_loader.find_plugin_with_context('docker_container'))" || echo -e "${RED}Failed to import docker_container module${NC}"

echo
echo -e "${YELLOW}Testing ansible.posix collection import:${NC}"
python3 -c "from ansible.plugins.loader import module_loader; print('synchronize module path:', module_loader.find_plugin_with_context('synchronize'))" || echo -e "${RED}Failed to import synchronize module${NC}"

echo
echo -e "${YELLOW}Displaying all available collections:${NC}"
ansible-galaxy collection list

echo
echo -e "${GREEN}Test completed.${NC}"
