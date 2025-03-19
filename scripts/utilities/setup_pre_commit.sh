#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: setup_pre_commit.sh
# Description: Sets up a pre-commit hook for shell script linting
# Author: Ephemery Team
# Created: 2025-03-22
# Last Modified: 2025-03-22
#
# This script sets up a pre-commit hook to automatically lint shell scripts.

set -euo pipefail

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GIT_HOOKS_DIR="${PROJECT_ROOT}/.git/hooks"
PRE_COMMIT_HOOK="${GIT_HOOKS_DIR}/pre-commit"

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to create pre-commit hook
create_pre_commit_hook() {
  echo -e "${BLUE}Creating pre-commit hook...${NC}"
  
  # Create hooks directory if it doesn't exist
  mkdir -p "${GIT_HOOKS_DIR}"
  
  # Create pre-commit hook
  cat > "${PRE_COMMIT_HOOK}" << 'EOF'
#!/usr/bin/env bash
# Pre-commit hook for Ephemery

set -euo pipefail

# Get the project root directory
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
SHELL_LINT="${PROJECT_ROOT}/scripts/testing/lint_shell_scripts.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Running pre-commit checks...${NC}"

# Get staged shell scripts
STAGED_SHELL_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.sh$|\.bash$' || true)

if [[ -n "${STAGED_SHELL_FILES}" ]]; then
  echo -e "${BLUE}Checking shell scripts...${NC}"
  
  # Check if shellharden is installed
  if ! command -v shellharden &> /dev/null; then
    echo -e "${YELLOW}shellharden is not installed. Installing...${NC}"
    cargo install shellharden || {
      echo -e "${RED}Failed to install shellharden. You can install it manually:${NC}"
      echo "  https://github.com/anordal/shellharden"
      exit 1
    }
  fi
  
  # Run linting on staged shell files
  echo "${STAGED_SHELL_FILES}" | while read -r file; do
    echo -e "Checking ${file}..."
    "${SHELL_LINT}" --check "${file}" || {
      echo -e "${RED}Shell script linting failed.${NC}"
      echo -e "${YELLOW}Run '${SHELL_LINT} --fix ${file}' to fix issues automatically.${NC}"
      exit 1
    }
  done
  
  echo -e "${GREEN}All shell scripts passed linting.${NC}"
fi

# Additional checks can be added here (ansible-lint, yamllint, etc.)

echo -e "${GREEN}Pre-commit checks passed.${NC}"
exit 0
EOF
  
  # Make hook executable
  chmod +x "${PRE_COMMIT_HOOK}"
  
  echo -e "${GREEN}Pre-commit hook created at ${PRE_COMMIT_HOOK}${NC}"
}

# Function to check if hook already exists
check_existing_hook() {
  if [[ -f "${PRE_COMMIT_HOOK}" ]]; then
    echo -e "${YELLOW}Pre-commit hook already exists.${NC}"
    echo -e "Would you like to overwrite it? [y/N] "
    read -r response
    if [[ "${response}" =~ ^[Yy]$ ]]; then
      create_pre_commit_hook
    else
      echo -e "${YELLOW}Skipping pre-commit hook creation.${NC}"
      exit 0
    fi
  else
    create_pre_commit_hook
  fi
}

# Main function
main() {
  echo -e "${BLUE}Setting up pre-commit hook for shell script linting${NC}"
  
  # Check if we're in a git repository
  if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo -e "${RED}Error: Not in a git repository.${NC}"
    exit 1
  fi
  
  # Check if hook already exists
  check_existing_hook
  
  echo -e "${GREEN}Pre-commit hook setup complete.${NC}"
  echo -e "The hook will automatically check shell scripts before each commit."
}

# Run main function
main 