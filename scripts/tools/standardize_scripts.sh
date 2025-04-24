#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: standardize_scripts.sh
# Description: Standardizes all scripts to use the common library and removes duplicate code
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17
#
# Usage: ./standardize_scripts.sh [options]
#
# Options:
#   -h, --help       Display this help message
#   -d, --directory  Directory to process (default: all script directories)
#   -v, --verbose    Enable verbose output
#   -f, --force      Force overwrite without confirmation
#   -s, --script     Process a specific script
#   -n, --dry-run    Run without making changes

# Enable strict mode
set -euo pipefail

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh"

# Define additional functions needed if they're not in common_consolidated.sh
print_banner() {
  local message="$1"
  local separator
  separator=$(printf '=%.0s' $(seq 1 ${#message}))
  echo ""
  echo "$separator"
  echo "$message"
  echo "$separator"
  echo ""
}

confirm_action() {
  local message="$1"
  local response=""
  read -rp "$message (y/n): " response
  if [[ "$response" =~ ^[Yy] ]]; then
    return 0
  else
    return 1
  fi
}

# Define logging functions if they aren't available
log_info() {
  echo "[INFO] $*"
}

log_warn() {
  echo "[WARNING] $*" >&2
}

log_error() {
  echo "[ERROR] $*" >&2
}

log_success() {
  echo "[SUCCESS] $*"
}

# Default configuration
DIRECTORY_TO_PROCESS=""
VERBOSE=false
FORCE=false
SPECIFIC_SCRIPT=""
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      echo "Usage: $(basename "$0") [options]"
      echo ""
      echo "Options:"
      echo "  -h, --help       Display this help message"
      echo "  -d, --directory  Directory to process (default: all script directories)"
      echo "  -v, --verbose    Enable verbose output"
      echo "  -f, --force      Force overwrite without confirmation"
      echo "  -s, --script     Process a specific script"
      echo "  -n, --dry-run    Run without making changes"
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
print_banner "Ephemery Script Standardization"

# Calculate relative path to project root
calculate_relative_path() {
  local script_path="$1"
  local depth
  depth=$(echo "$script_path" | tr -cd '/' | wc -c)
  local relative_path=""

  # For each directory level, add one "../"
  # Start from 3 because we need to go up from scripts/category/script.sh to the project root
  local i=3
  while [ "$i" -le "$depth" ]; do
    relative_path="${relative_path}../"
    i=$((i + 1))
  done

  # If no path was calculated, default to ".."
  if [[ -z "$relative_path" ]]; then
    relative_path=".."
  fi

  echo "$relative_path"
}

# Function to standardize a script
standardize_script() {
  local script_path="$1"
  local modified=false

  log_info "Processing $script_path"

  # Skip if not a shell script
  if ! grep -q "^#!/.*sh" "$script_path"; then
    log_warn "$script_path does not appear to be a shell script, skipping"
    return 0
  fi

  # Create backup if not in dry-run mode
  if [[ "$DRY_RUN" == "false" ]]; then
    cp "$script_path" "${script_path}.bak"
  fi

  # Check if script uses common library
  if ! grep -q "source.*scripts/lib/common.sh" "$script_path"; then
    log_info "Adding common library import to $script_path"

    # Add script directory determination if not present
    if ! grep -q "SCRIPT_DIR=.*dirname.*BASH_SOURCE" "$script_path"; then
      # Using a here-document to avoid linter issues with sed
      if [[ "$DRY_RUN" == "false" ]]; then
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
      fi
      modified=true
    else
      # Script already has SCRIPT_DIR, just add sourcing the common library
      # Find the line with SCRIPT_DIR and add common library sourcing after it
      local line_num
      line_num=$(grep -n "SCRIPT_DIR=" "$script_path" | head -n 1 | cut -d: -f1)

      # Fix the PROJECT_ROOT definition if it exists but is incorrect
      if grep -q "PROJECT_ROOT=" "$script_path"; then
        local relative_path
        relative_path=$(calculate_relative_path "$script_path")

        if [[ "$DRY_RUN" == "false" ]]; then
          # Use proper quoting to avoid subshell pipeline issues
          sed -i.tmp -e "s|PROJECT_ROOT=.*|PROJECT_ROOT=\"\$(cd \"\${SCRIPT_DIR}/${relative_path}\" \&\& pwd)\"|" "$script_path"
          rm -f "${script_path}.tmp"
        fi
        modified=true
      fi

      if [[ -n "$line_num" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
          # If PROJECT_ROOT is already defined
          if grep -q "PROJECT_ROOT=" "$script_path"; then
            # Add source line after PROJECT_ROOT line
            local project_root_line
            project_root_line=$(grep -n "PROJECT_ROOT=" "$script_path" | head -n 1 | cut -d: -f1)
            cat >"${script_path}.temp" <<EOF
$(head -n "$project_root_line" "$script_path")

# Source the common library
source "\${PROJECT_ROOT}/scripts/lib/common.sh"
$(tail -n +"$((project_root_line + 1))" "$script_path")
EOF
          else
            # Add PROJECT_ROOT and source after SCRIPT_DIR
            cat >"${script_path}.temp" <<EOF
$(head -n "$line_num" "$script_path")
PROJECT_ROOT="\$(cd "\${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "\${PROJECT_ROOT}/scripts/lib/common.sh"
$(tail -n +"$((line_num + 1))" "$script_path")
EOF
          fi
          mv "${script_path}.temp" "$script_path"
        fi
        modified=true
      fi
    fi
  fi

  # Remove color definitions
  if grep -q "^[[:space:]]*[A-Z]\+=['\"]\\\\033\[[0-9];[0-9]\+m['\"]" "$script_path"; then
    log_info "Removing color definitions from $script_path"
    if [[ "$DRY_RUN" == "false" ]]; then
      # Create a temporary file without color definitions
      grep -v -E "^[[:space:]]*[A-Z]+=['\"]\\\\033\[[0-9];[0-9]+m['\"]|^[[:space:]]*NC=['\"]\\\\033\[0m['\"]" "$script_path" >"${script_path}.temp"
      mv "${script_path}.temp" "$script_path"
    fi
    modified=true
  fi

  # Make script executable
  if [[ "$DRY_RUN" == "false" ]]; then
    chmod +x "$script_path"
  fi

  if [[ "$modified" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log_info "Would standardize $script_path (dry run)"
    else
      log_success "Standardized $script_path"
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
  if [[ -n "$SPECIFIC_SCRIPT" ]]; then
    if [[ -f "$SPECIFIC_SCRIPT" ]]; then
      echo "$SPECIFIC_SCRIPT"
    else
      log_error "Script not found: $SPECIFIC_SCRIPT"
      exit 1
    fi
  elif [[ -n "$DIRECTORY_TO_PROCESS" ]]; then
    if [[ -d "$DIRECTORY_TO_PROCESS" ]]; then
      find "$DIRECTORY_TO_PROCESS" -name "*.sh" -type f | grep -v "\.bak$"
    else
      log_error "Directory not found: $DIRECTORY_TO_PROCESS"
      exit 1
    fi
  else
    # Process all scripts in standard directories
    find "${PROJECT_ROOT}/scripts" -name "*.sh" -type f | grep -v "\.bak$"
  fi
}

# Main function
main() {
  log_info "Starting script standardization"

  # Get scripts to process
  scripts=()
  while IFS= read -r script; do
    scripts+=("$script")
  done < <(get_scripts_to_process)

  log_info "Found ${#scripts[@]} scripts to process"

  local processed=0
  local skipped=0
  local failed=0

  for script in "${scripts[@]}"; do
    if [[ "$FORCE" == "true" ]]; then
      standardize_script "$script"
      processed=$((processed + 1))
    else
      if [[ "$DRY_RUN" == "true" ]] || confirm_action "Standardize $script?"; then
        standardize_script "$script"
        processed=$((processed + 1))
      else
        log_info "Skipping $script"
        skipped=$((skipped + 1))
      fi
    fi
  done

  log_success "Script standardization completed!"
  log_info "Processed: $processed, Skipped: $skipped, Failed: $failed"
}

# Run the main function
main
