#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: fix_common_issues.sh
# Description: Fixes common issues in scripts identified by script_audit.sh
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17
#
# Usage: ./fix_common_issues.sh [options]
#
# Options:
#   -h, --help       Display this help message
#   -d, --directory  Directory to process (default: ..)
#   -v, --verbose    Enable verbose output
#   -f, --force      Force overwrite without confirmation
#   -s, --script     Process a specific script

# Enable strict mode
set -euo pipefail

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Default configuration
DIRECTORY_TO_PROCESS="${SCRIPT_DIR}/.."
VERBOSE=false
FORCE=false
SPECIFIC_SCRIPT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      echo "Usage: $(basename "$0") [options]"
      echo ""
      echo "Options:"
      echo "  -h, --help       Display this help message"
      echo "  -d, --directory  Directory to process (default: ../scripts)"
      echo "  -v, --verbose    Enable verbose output"
      echo "  -f, --force      Force overwrite without confirmation"
      echo "  -s, --script     Process a specific script"
      exit 0
      ;;
    -d | --directory)
      DIRECTORY_TO_PROCESS="$2"
      shift 2
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    -f | --force)
      FORCE=true
      shift
      ;;
    -s | --script)
      SPECIFIC_SCRIPT="$2"
      shift 2
      ;;
    *)
      log_error "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Print banner
print_banner "Ephemery Script Fixer"

# Function to fix common issues in a script
fix_script() {
  local script_path="$1"
  local modified=false

  log_info "Processing $script_path"

  # Create backup
  cp "$script_path" "${script_path}.bak"

  # Check if script uses common library
  if ! grep -q "source.*lib/common.sh" "$script_path"; then
    log_info "Adding common library import to $script_path"

    # Add script directory determination if not present
    if ! grep -q "SCRIPT_DIR=.*dirname.*BASH_SOURCE" "$script_path"; then
      # Using a here-document to avoid linter issues with sed
      cat >"${script_path}.temp" <<EOF
$(head -n 1 "$script_path")
# Get the absolute path to the script directory
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="\$(cd "\${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "\${PROJECT_ROOT}/scripts/lib/common.sh"

$(tail -n +2 "$script_path")
EOF
      mv "${script_path}.temp" "$script_path"
      modified=true
    else
      # Script already has SCRIPT_DIR, just add sourcing the common library
      # Find the line with SCRIPT_DIR and add common library sourcing after it
      local line_num
      line_num=$(grep -n "SCRIPT_DIR=" "$script_path" | head -n 1 | cut -d: -f1)
      if [[ -n "$line_num" ]]; then
        cat >"${script_path}.temp" <<EOF
$(head -n "$line_num" "$script_path")
# Source the common library
source "\${PROJECT_ROOT}/scripts/lib/common.sh"
$(tail -n +"$((line_num + 1))" "$script_path")
EOF
        mv "${script_path}.temp" "$script_path"
        modified=true
      fi
    fi
  fi

  # Remove color definitions
  if grep -q "^[[:space:]]*[A-Z]\+=['\"]\\033\[[0-9];[0-9]\+m['\"]" "$script_path"; then
    log_info "Removing color definitions from $script_path"
    grep -v -E "^[[:space:]]*[A-Z]+=['\"][\\]033\[[0-9];[0-9]+m['\"]" "$script_path" >"${script_path}.temp"
    mv "${script_path}.temp" "$script_path"
    modified=true
  fi

  # Make script executable
  chmod +x "$script_path"

  if [[ "$modified" == "true" ]]; then
    log_success "Fixed issues in $script_path"
  else
    log_info "No issues to fix in $script_path"
    # Remove backup if no changes were made
    rm "${script_path}.bak"
  fi
}

# Main function
main() {
  log_info "Starting script fixer"

  if [[ -n "$SPECIFIC_SCRIPT" ]]; then
    if [[ -f "$SPECIFIC_SCRIPT" ]]; then
      fix_script "$SPECIFIC_SCRIPT"
    else
      log_error "Script not found: $SPECIFIC_SCRIPT"
      exit 1
    fi
  else
    # Find all shell scripts
    while IFS= read -r script; do
      if [[ "$FORCE" == "true" ]]; then
        fix_script "$script"
      else
        if confirm_action "Process $script?"; then
          fix_script "$script"
        else
          log_info "Skipping $script"
        fi
      fi
    done < <(find "$DIRECTORY_TO_PROCESS" -name "*.sh" -type f)
  fi

  log_success "Script fixing completed!"
}

# Run the main function
main
