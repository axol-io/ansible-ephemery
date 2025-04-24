#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: check-unencrypted-secrets.sh
# Description: Checks for unencrypted secrets in the repository
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Pre-commit hook to detect unencrypted secrets in yaml files
# This script checks for common patterns of unencrypted secrets in yaml files

set -euo pipefail

# Colors for output
NC='\033[0m' # No Color

# Patterns to search for (excluding commented lines)
PATTERNS=(
  "jwt_secret:.*[a-f0-9]{32,}"
  "jwtsecret:.*[a-f0-9]{32,}"
  "telegram_bot_token:.*[0-9]{8,}:.*[a-zA-Z0-9_-]{35,}"
  "telegram_chat_id:.*-?[0-9]{10,}"
  "password:.*[^\$ANSIBLE_VAULT]"
  "admin_password:.*[^\$ANSIBLE_VAULT]"
  "secret_key:.*[^\$ANSIBLE_VAULT]"
  "access_key:.*[^\$ANSIBLE_VAULT]"
  "api_key:.*[^\$ANSIBLE_VAULT]"
)

# Files to exclude from checks
EXCLUDES=(
  ".git/"
  "collections/"
  "molecule/default/"
  "example-*"
)

# Build exclude arguments for grep
EXCLUDE_ARGS=""
for exclude in "${EXCLUDES[@]}"; do
  EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude-dir=$exclude"
done

# Function to check for unencrypted values
check_unencrypted_secrets() {
  local found_secrets=0

  echo -e "${YELLOW}Checking for unencrypted secrets in YAML files...${NC}"

  for pattern in "${PATTERNS[@]}"; do
    # Find matches excluding commented lines (lines that start with #)
    matches=$(grep -r "$pattern" $EXCLUDE_ARGS --include="*.yaml" --include="*.yml" . | grep -v '^\s*#' || true)

    if [ -n "$matches" ]; then
      echo -e "${RED}Found potential unencrypted secrets:${NC}"
      echo "$matches"
      echo ""
      found_secrets=1
    fi
  done

  if [ $found_secrets -eq 0 ]; then
    echo -e "${GREEN}No unencrypted secrets found.${NC}"
    return 0
  else
    echo -e "${RED}Error: Unencrypted secrets found in YAML files.${NC}"
    echo -e "${YELLOW}Please encrypt sensitive values using ansible-vault:${NC}"
    echo "ansible-vault encrypt_string --name 'secret_name' 'your_secret_value'"
    return 1
  fi
}

# Main execution
check_unencrypted_secrets
