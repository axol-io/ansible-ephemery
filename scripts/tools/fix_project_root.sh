#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: fix_project_root.sh
# Description: Adds PROJECT_ROOT definition to scripts that need it
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17

# Enable strict mode
set -euo pipefail

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Default configuration
VERBOSE=false
FORCE=false
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      echo "Usage: $(basename "$0") [options]"
      echo ""
      echo "Options:"
      echo "  -h, --help       Display this help message"
      echo "  -v, --verbose    Enable verbose output"
      echo "  -f, --force      Force overwrite without confirmation"
      echo "  -n, --dry-run    Run without making changes"
      exit 0
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    -f | --force)
      FORCE=true
      shift
      ;;
    -n | --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Print banner
print_banner "Fix PROJECT_ROOT Definition"

# Function to add PROJECT_ROOT definition to a script
fix_project_root() {
  local script_path="$1"
  local modified=false

  log_info "Processing $script_path"

  # Skip if not a shell script
  if ! grep -q "^#!/.*sh" "$script_path"; then
    log_warn "$script_path does not appear to be a shell script, skipping"
    return 0
  fi

  # Check if script has SCRIPT_DIR defined but not PROJECT_ROOT
  if grep -q "SCRIPT_DIR=" "$script_path" && ! grep -q "PROJECT_ROOT=" "$script_path"; then
    log_info "Adding PROJECT_ROOT definition to $script_path"

    # Create backup if not in dry-run mode
    if [[ "$DRY_RUN" == "false" ]]; then
      cp "$script_path" "${script_path}.bak"
    fi

    # Find the line with SCRIPT_DIR and add PROJECT_ROOT after it
    local line_num
    line_num=$(grep -n "SCRIPT_DIR=" "$script_path" | head -n 1 | cut -d: -f1)

    if [[ -n "$line_num" ]]; then
      if [[ "$DRY_RUN" == "false" ]]; then
        # Add PROJECT_ROOT after SCRIPT_DIR
        cat >"${script_path}.temp" <<EOF
$(head -n "$line_num" "$script_path")
PROJECT_ROOT="\$(cd "\${SCRIPT_DIR}/../.." && pwd)"
$(tail -n +"$((line_num + 1))" "$script_path")
EOF
        mv "${script_path}.temp" "$script_path"
      fi
      modified=true
    fi
  fi

  if [[ "$modified" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log_info "Would fix PROJECT_ROOT definition in $script_path (dry run)"
    else
      log_success "Fixed PROJECT_ROOT definition in $script_path"
    fi
  else
    log_info "No changes needed for $script_path"
    # Remove backup if no changes were made
    if [[ "$DRY_RUN" == "false" ]]; then
      rm -f "${script_path}.bak"
    fi
  fi
}

# Function to get scripts to process
get_scripts_to_process() {
  # List of scripts that need PROJECT_ROOT definition
  cat <<EOF
/Users/droo/Documents/CODE/ansible-ephemery/scripts/demo_validator_monitoring.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/ephemery_output.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/local/run-ephemery-local.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/enhanced_checkpoint_sync.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/manage-validator.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/organize_scripts.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/remote/run-ephemery-remote.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/setup/setup_ephemery.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/start-validator-dashboard.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/update_script_readmes.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/common.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/enhanced_key_restore.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/ephemery_key_restore_wrapper.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/key_performance_metrics.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/validate_configuration.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/validator/backup_restore_validators.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/validator/dashboard/validator-dashboard.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/validator/integration_test.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/validator/manage_validator_keys.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/validator/monitor_validator.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/validator/setup_ephemery_validator.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/validator/test_validator_config.sh
/Users/droo/Documents/CODE/ansible-ephemery/scripts/validator/validator_key_management/password_manager.sh
EOF
}

# Main function
main() {
  log_info "Starting PROJECT_ROOT definition fix"

  # Get scripts to process
  local scripts=()
  while IFS= read -r script; do
    if [[ -n "$script" ]]; then
      scripts+=("$script")
    fi
  done < <(get_scripts_to_process)

  local total_scripts=${#scripts[@]}

  log_info "Found $total_scripts scripts to fix"

  # Fix each script
  if [[ $total_scripts -gt 0 ]]; then
    for script in "${scripts[@]}"; do
      fix_project_root "$script"
    done
    log_success "PROJECT_ROOT definition fix completed!"
  else
    log_info "No scripts to fix"
  fi
}

# Run main function
main
