#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: reorganize_scripts.sh
# Description: Identifies and migrates scripts to the new directory structure
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17
#
# Usage: ./reorganize_scripts.sh [options]
#
# Options:
#   -h, --help       Display this help message
#   -d, --dry-run    Run in dry-run mode (don't make any changes)
#   -f, --force      Force overwrite if files already exist
#   -v, --verbose    Enable verbose output
#
# This script performs the following:
# 1. Identifies scripts in the root directory that need to be moved
# 2. Determines the appropriate category for each script
# 3. Modifies scripts to use the new common library
# 4. Moves scripts to their new locations
# 5. Generates a report of what was moved and what needs manual attention

# Enable strict mode
set -euo pipefail

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source the common library
source "${SCRIPT_DIR}/lib/common.sh"

# Default configuration
DRY_RUN=false
FORCE=false
VERBOSE=false

# Script categories and patterns - using regular variables instead of associative array
CATEGORY_CORE="setup|config|path|common|validator|version|retention|ephemery.*main|init|restore|standardize"
CATEGORY_DEPLOYMENT="deploy|provision|install|setup.*environment|ansible|collections|verify-collections"
CATEGORY_MAINTENANCE="update|upgrade|backup|restore|clean|fix|reset|secrets|password|unencrypted|prune"
CATEGORY_MONITORING="monitor|check|status|dashboard|analyze|diagnose|logs|output|performance|metrics"
CATEGORY_TESTING="test|validate|verify|audit|lint|shellcheck|pre-commit|script_audit|run-tests"
CATEGORY_DEVELOPMENT="dev|template|example|demo|organize_scripts|reorganize|standardize|script_organization"
CATEGORY_TOOLS="tool|utility|benchmark|enhance|wrapper|container|client|tasks|yaml|extension"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      echo "Usage: $(basename "$0") [options]"
      echo ""
      echo "Options:"
      echo "  -h, --help       Display this help message"
      echo "  -d, --dry-run    Run in dry-run mode (don't make any changes)"
      echo "  -f, --force      Force overwrite if files already exist"
      echo "  -v, --verbose    Enable verbose output"
      exit 0
      ;;
    -d | --dry-run)
      DRY_RUN=true
      shift
      ;;
    -f | --force)
      FORCE=true
      shift
      ;;
    -v | --verbose)
      VERBOSE=true
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
print_banner "Ephemery Scripts Reorganization"

# Status tracking - using regular variables instead of associative arrays
SCRIPTS_TO_MOVE=""
MOVED_SCRIPTS=""
SKIPPED_SCRIPTS=""
FAILED_SCRIPTS=""
MODIFIED_SCRIPTS=""

# Determine category for a script
determine_category() {
  local script_name="$1"
  local script_content
  script_content=$(cat "$script_name" 2>/dev/null || echo "")

  # Default category if no match is found
  local category="core"

  # Convert script name to lowercase for matching
  local script_name_lower
  script_name_lower=$(echo "$script_name" | tr '[:upper:]' '[:lower:]')

  # Try to determine category from filename and content
  if [[ "$script_name_lower" =~ $CATEGORY_CORE ]] || [[ "$script_content" =~ $CATEGORY_CORE ]]; then
    category="core"
  elif [[ "$script_name_lower" =~ $CATEGORY_DEPLOYMENT ]] || [[ "$script_content" =~ $CATEGORY_DEPLOYMENT ]]; then
    category="deployment"
  elif [[ "$script_name_lower" =~ $CATEGORY_MAINTENANCE ]] || [[ "$script_content" =~ $CATEGORY_MAINTENANCE ]]; then
    category="maintenance"
  elif [[ "$script_name_lower" =~ $CATEGORY_MONITORING ]] || [[ "$script_content" =~ $CATEGORY_MONITORING ]]; then
    category="monitoring"
  elif [[ "$script_name_lower" =~ $CATEGORY_TESTING ]] || [[ "$script_content" =~ $CATEGORY_TESTING ]]; then
    category="testing"
  elif [[ "$script_name_lower" =~ $CATEGORY_DEVELOPMENT ]] || [[ "$script_content" =~ $CATEGORY_DEVELOPMENT ]]; then
    category="development"
  elif [[ "$script_name_lower" =~ $CATEGORY_TOOLS ]] || [[ "$script_content" =~ $CATEGORY_TOOLS ]]; then
    category="tools"
  fi

  # Special cases based on specific functionality
  if [[ "$script_content" == *"ansible"* || "$script_name_lower" == *"ansible"* ]]; then
    category="deployment"
  elif [[ "$script_content" == *"prometheus"* || "$script_name_lower" == *"prometheus"* ]]; then
    category="monitoring"
  elif [[ "$script_name_lower" == *"script_audit"* ]]; then
    category="tools"
  elif [[ "$script_name_lower" == *"reorganize"* ]]; then
    category="tools"
  fi

  echo "$category"
}

# Modify script to use common library
modify_script() {
  local script_path="$1"
  local script_content
  script_content=$(cat "$script_path")
  local modified=false

  # Create backup if not in dry-run mode
  if [[ "$DRY_RUN" == "false" ]]; then
    cp "$script_path" "${script_path}.bak"
  fi

  # Check if the script already sources the common library
  if ! grep -q "source.*lib/common.sh" "$script_path"; then
    log_debug "Modifying $script_path to use common library"

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

    # Replace common color definitions - using grep to find lines, then removing them
    if grep -q "RED=" "$script_path" || grep -q "GREEN=" "$script_path"; then
      grep -v -E "^[[:space:]]*[A-Z]+=['\"][\\]033\[[0-9];[0-9]+m['\"]" "$script_path" >"${script_path}.temp"
      mv "${script_path}.temp" "$script_path"
      modified=true
    fi

    # Write back modified content if not in dry-run mode
    if [[ "$DRY_RUN" == "false" && "$modified" == "true" ]]; then
      MODIFIED_SCRIPTS="${MODIFIED_SCRIPTS} ${script_path}"
    fi
  fi

  return 0
}

# Move script to new location
move_script() {
  local script_path="$1"
  local category="$2"
  local script_name
  script_name=$(basename "$script_path")
  local target_dir="${SCRIPT_DIR}/${category}"
  local target_path="${target_dir}/${script_name}"

  if [[ ! -d "$target_dir" ]]; then
    if [[ "$DRY_RUN" == "false" ]]; then
      log_info "Creating directory $target_dir"
      mkdir -p "$target_dir"
    else
      log_info "[DRY RUN] Would create directory $target_dir"
    fi
  fi

  if [[ -f "$target_path" && "$FORCE" == "false" ]]; then
    log_warn "Target file $target_path already exists. Use --force to overwrite."
    SKIPPED_SCRIPTS="${SKIPPED_SCRIPTS} ${script_path}:Target already exists"
    return 1
  fi

  # Modify the script to use common library
  if ! modify_script "$script_path"; then
    log_error "Failed to modify $script_path"
    FAILED_SCRIPTS="${FAILED_SCRIPTS} ${script_path}:Failed to modify"
    return 1
  fi

  if [[ "$DRY_RUN" == "false" ]]; then
    log_info "Moving $script_path to $target_path"
    mv "$script_path" "$target_path"
    chmod +x "$target_path"
    MOVED_SCRIPTS="${MOVED_SCRIPTS} ${script_path}:${target_path}"
  else
    log_info "[DRY RUN] Would move $script_path to $target_path"
    MOVED_SCRIPTS="${MOVED_SCRIPTS} ${script_path}:${target_path}"
  fi

  return 0
}

# Find scripts in the root directory
find_scripts() {
  log_info "Finding scripts in the root directory"

  # Find shell scripts in the scripts directory
  while IFS= read -r script; do
    if [[ -f "$script" && -x "$script" ]]; then
      local category
      category=$(determine_category "$script")
      SCRIPTS_TO_MOVE="${SCRIPTS_TO_MOVE} ${script}:${category}"

      if [[ "$VERBOSE" == "true" ]]; then
        log_debug "Found script $script - Category: $category"
      fi
    fi
  done < <(find "${SCRIPT_DIR}" -maxdepth 1 -name "*.sh" -type f)

  # Find shell scripts in the root directory
  while IFS= read -r script; do
    if [[ -f "$script" && -x "$script" ]]; then
      local category
      category=$(determine_category "$script")
      SCRIPTS_TO_MOVE="${SCRIPTS_TO_MOVE} ${script}:${category}"

      if [[ "$VERBOSE" == "true" ]]; then
        log_debug "Found script $script - Category: $category"
      fi
    fi
  done < <(find "${PROJECT_ROOT}" -maxdepth 1 -name "*.sh" -type f)

  # Find scripts in old script directories that should be migrated
  local old_script_dirs=("utils" "tools" "validator" "remote" "local" "setup" "utilities")
  for dir in "${old_script_dirs[@]}"; do
    if [[ -d "${SCRIPT_DIR}/${dir}" ]]; then
      while IFS= read -r script; do
        if [[ -f "$script" && -x "$script" ]]; then
          local category
          category=$(determine_category "$script")
          SCRIPTS_TO_MOVE="${SCRIPTS_TO_MOVE} ${script}:${category}"

          if [[ "$VERBOSE" == "true" ]]; then
            log_debug "Found script $script - Category: $category"
          fi
        fi
      done < <(find "${SCRIPT_DIR}/${dir}" -name "*.sh" -type f)
    fi
  done

  log_info "Found scripts to process: $(echo "$SCRIPTS_TO_MOVE" | wc -w)"
}

# Process the scripts
process_scripts() {
  log_info "Processing scripts"

  for script_entry in $SCRIPTS_TO_MOVE; do
    IFS=":" read -r script category <<<"$script_entry"

    log_info "Processing $script -> $category"
    if ! move_script "$script" "$category"; then
      log_warn "Failed to process $script"
    fi
  done
}

# Generate report
generate_report() {
  log_info "Generating report"

  echo -e "\n${BLUE}=== Script Reorganization Report ===${NC}\n"

  echo -e "${GREEN}Successfully moved:${NC}"
  for entry in $MOVED_SCRIPTS; do
    IFS=":" read -r script target <<<"$entry"
    echo "  $script -> $target"
  done

  if [[ -n "$MODIFIED_SCRIPTS" ]]; then
    echo -e "\n${CYAN}Modified to use common library:${NC}"
    for script in $MODIFIED_SCRIPTS; do
      echo "  $script"
    done
  fi

  if [[ -n "$SKIPPED_SCRIPTS" ]]; then
    echo -e "\n${YELLOW}Skipped:${NC}"
    for entry in $SKIPPED_SCRIPTS; do
      IFS=":" read -r script reason <<<"$entry"
      echo "  $script - $reason"
    done
  fi

  if [[ -n "$FAILED_SCRIPTS" ]]; then
    echo -e "\n${RED}Failed:${NC}"
    for entry in $FAILED_SCRIPTS; do
      IFS=":" read -r script reason <<<"$entry"
      echo "  $script - $reason"
    done
  fi

  echo -e "\n${BLUE}======================${NC}\n"
}

# Main function
main() {
  log_info "Starting script reorganization"

  # Find scripts to process
  find_scripts

  # Process scripts
  process_scripts

  # Generate report
  generate_report

  log_success "Script reorganization completed successfully!"
}

# Run the main function
main
