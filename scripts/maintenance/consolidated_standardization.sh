#!/bin/bash
#
# Consolidated Standardization Script
# This script combines functionality from:
#   - standardize_scripts.sh
#   - organize_scripts.sh
#   - reorganize_scripts.sh
#   - update_script_readmes.sh
#   - standardize_repository.sh
#   - repo-standards.sh
#
# Author: Ephemery Team
# Created: $(date +%Y-%m-%d)
# Last Modified: $(date +%Y-%m-%d)

set -euo pipefail

# Print header
echo "====================================================="
echo "   Ephemery Codebase Standardization Tool            "
echo "====================================================="

# Define colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Default values
DRY_RUN=false
VERBOSE=false
MODE="all"
TARGET_DIR="scripts"

# Display help message
function show_help() {
    echo -e "${BLUE}Ephemery Codebase Standardization Tool${RESET}"
    echo
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help                 Show this help message"
    echo "  -d, --dry-run              Show what would be done without making changes"
    echo "  -v, --verbose              Enable verbose output"
    echo "  -m, --mode MODE            Specify operation mode: all, organize, standardize, readme, repo"
    echo "  -t, --target-dir DIR       Specify target directory (default: scripts)"
    echo
    echo "Modes:"
    echo "  all         - Run all standardization tasks (default)"
    echo "  organize    - Organize scripts into appropriate directories"
    echo "  standardize - Apply coding standards to scripts"
    echo "  readme      - Update README files"
    echo "  repo        - Apply repository-wide standards"
    echo
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -m|--mode)
            if [[ $# -lt 2 || $2 == -* ]]; then
                echo -e "${RED}Error: --mode requires an argument${RESET}"
                exit 1
            fi
            MODE="$2"
            shift 2
            ;;
        -t|--target-dir)
            if [[ $# -lt 2 || $2 == -* ]]; then
                echo -e "${RED}Error: --target-dir requires an argument${RESET}"
                exit 1
            fi
            TARGET_DIR="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${RESET}"
            show_help
            exit 1
            ;;
    esac
done

# Validate mode
if [[ ! "$MODE" =~ ^(all|organize|standardize|readme|repo)$ ]]; then
    echo -e "${RED}Error: Invalid mode: $MODE${RESET}"
    show_help
    exit 1
fi

# Check if target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: Target directory $TARGET_DIR does not exist${RESET}"
    exit 1
fi

# Log function
log() {
    local level="$1"
    local message="$2"
    local color="$RESET"
    
    case "$level" in
        "INFO")
            color="$BLUE"
            ;;
        "SUCCESS")
            color="$GREEN"
            ;;
        "WARNING")
            color="$YELLOW"
            ;;
        "ERROR")
            color="$RED"
            ;;
    esac
    
    if [[ "$level" == "DEBUG" && "$VERBOSE" != "true" ]]; then
        return
    fi
    
    echo -e "${color}[$level] $message${RESET}"
}

# Function to backup a file before modification
backup_file() {
    local file="$1"
    local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "DEBUG" "Would backup $file to $backup"
        return
    fi
    
    cp "$file" "$backup"
    log "DEBUG" "Backed up $file to $backup"
}

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log "INFO" "Starting standardization in mode: $MODE"
log "INFO" "Target directory: $TARGET_DIR"
if [ "$DRY_RUN" = "true" ]; then
    log "WARNING" "Running in dry-run mode, no changes will be made"
fi

# Functions from scripts/standardize_scripts.sh
# Mon Mar 17 16:23:07 CET 2025

# Function: print_usage from scripts/standardize_scripts.sh
function print_usage() {
    log_info "Ephemery Script Standardization Tool"
    log_info ""
    log_info "This script automates the standardization of shell scripts in the Ephemery project."
    log_info "It applies consistent error handling, logging, and configuration mechanisms."
    log_info ""
    log_info "Usage:"
    log_info "  $0 [options] [scripts...]"
    log_info ""
    log_info "Options:"
    log_info "  -d, --dry-run         Show what would be changed without making actual changes"
    log_info "  -v, --verbose         Enable verbose output"
    log_info "  -n, --no-backup       Don't create backup files"
    log_info "  -a, --all             Process all shell scripts in the project"
    log_info "  -h, --help            Show this help message"
    log_info ""
    log_info "Examples:"
    log_info "  $0 --all              # Standardize all scripts"
    log_info "  $0 scripts/core/ephemery_reset_handler.sh  # Standardize a specific script"
}


# Function: create_backup from scripts/standardize_scripts.sh
create_backup() {
    local script="$1"
    local backup="${script}.bak"
    
    if [[ "${BACKUP}" == "true" ]]; then
        log_info "Creating backup of ${script} to ${backup}"
        cp "${script}" "${backup}"
    fi
}


# Function: uses_common_lib from scripts/standardize_scripts.sh
uses_common_lib() {
    local script="$1"
    
    if grep -q "source.*scripts/lib/common.sh" "${script}"; then
        return 0
    else
        return 1
    fi
}


# Function: uses_config_lib from scripts/standardize_scripts.sh
uses_config_lib() {
    local script="$1"
    
    if grep -q "source.*scripts/lib/config.sh" "${script}"; then
        return 0
    else
        return 1
    fi
}


# Function: add_common_lib from scripts/standardize_scripts.sh
add_common_lib() {
    local script="$1"
    local temp_file="${script}.tmp"
    
    log_info "Adding common library import to ${script}"
    
    # Find the right location to add the import
    if grep -q "^#!/" "${script}"; then
        # Create header template file 
        cat > "${temp_file}.header" << 'EOF'

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Setup error handling
setup_traps

EOF

        # Add after shebang and any initial comments
        awk -v headerfile="${temp_file}.header" '
        BEGIN { added = 0; in_header = 1; header_count = 0; }
        /^#!/              { print; next; }
        /^#/               { if (in_header) { print; header_count++; next; } }
        !added && in_header && header_count > 0 {
            system("cat " headerfile);
            added = 1;
        }
        { in_header = 0; print; }

# Function: add_config_lib from scripts/standardize_scripts.sh
add_config_lib() {
    local script="$1"
    local temp_file="${script}.tmp"
    
    log_info "Adding config library import to ${script}"
    
    # Find the common library import line and add config import after it
    if grep -q "source.*scripts/lib/common.sh" "${script}"; then
        sed -i.tmp '/source.*scripts\/lib\/common.sh/a source "${PROJECT_ROOT}/scripts/lib/config.sh"' "${script}" && rm "${script}.tmp"
    else
        log_warn "Common library import not found in ${script}, adding config lib requires common lib"
        add_common_lib "${script}"
        add_config_lib "${script}"
    fi
}


# Function: replace_echo_with_log from scripts/standardize_scripts.sh
replace_echo_with_log() {
    local script="$1"
    local temp_file="${script}.tmp"
    
    log_info "Replacing echo statements with log_* functions in ${script}"
    
    # Define patterns for different log levels
    local error_pattern='(^|[[:space:]])echo[[:space:]]+(-e[[:space:]]+)?".*([Ee]rror|ERROR|[Ff]ail|FAIL).*"'
    local warn_pattern='(^|[[:space:]])echo[[:space:]]+(-e[[:space:]]+)?".*([Ww]arn|WARNING|[Cc]aution).*"'
    local success_pattern='(^|[[:space:]])echo[[:space:]]+(-e[[:space:]]+)?".*([Ss]uccess|SUCCESS|[Cc]omplete|COMPLETE).*"'
    local debug_pattern='(^|[[:space:]])echo[[:space:]]+(-e[[:space:]]+)?".*([Dd]ebug|DEBUG).*"'
    
    # Replace patterns with corresponding log_* functions
    awk -v script="${script}" '
    BEGIN { skip_next = 0; }
    # Skip if in a heredoc
    /<<[-]?EOF/ { in_heredoc = 1; print; next; }
    /^EOF/      { in_heredoc = 0; print; next; }
    in_heredoc  { print; next; }
    
    # Skip comment lines
    /^[[:space:]]*#/ { print; next; }
    
    # Skip if pattern already has log_* function
    /log_(error|warn|info|debug|success)/ { print; next; }
    
    # Replace error patterns
    match($0, /(^|[[:space:]])echo[[:space:]]+(-e[[:space:]]+)?".*(Error|ERROR|[Ff]ail|FAIL).*"/) {
        # Extract the message from the echo
        before = substr($0, 1, RSTART-1);
        cmd = substr($0, RSTART, RLENGTH);
        after = substr($0, RSTART+RLENGTH);
        
        # Extract the message part
        msg_start = index(cmd, "\"");
        msg_part = substr(cmd, msg_start);
        sub(/;?[[:space:]]*$/, "", msg_part);  # Remove trailing semicolon if any
        
        # Replace with log_error
        print before "log_error " msg_part after;
        next;
    }
    

# Function: add_error_handling from scripts/standardize_scripts.sh
add_error_handling() {
    local script="$1"
    local temp_file="${script}.tmp"
    
    log_info "Adding error handling to ${script}"
    
    # Add setup_traps if not already present
    if ! grep -q "setup_traps" "${script}"; then
        # Find the right location after common.sh import
        if grep -q "source.*common.sh" "${script}"; then
            sed -i.tmp '/source.*common.sh/a\
\
# Setup error handling\
setup_traps' "${script}" && rm "${script}.tmp"
        fi
    fi
    
    # Add cleanup function if not already present
    if ! grep -q "function cleanup()" "${script}" && ! grep -q "cleanup()" "${script}"; then
        # Create cleanup function template
        cat > "${temp_file}.cleanup" << 'EOF'

# Define cleanup function
cleanup() {
    log_info "Cleaning up..."
    # Add specific cleanup actions here if needed
}


# Function: cleanup from scripts/standardize_scripts.sh
cleanup() {
    log_info "Cleaning up..."
    # Add specific cleanup actions here if needed
}


# Function: update_path_handling from scripts/standardize_scripts.sh
update_path_handling() {
    local script="$1"
    local temp_file="${script}.tmp"
    
    log_info "Updating path handling to use config system in ${script}"
    
    # Add config variables to the top of the script if not already using them
    if ! grep -q "EPHEMERY_DATA_DIR" "${script}" && grep -q "data.*dir" "${script}" -i; then
        # Create config paths template
        cat > "${temp_file}.paths" << 'EOF'

# Use paths from configuration with fallbacks
DATA_DIR="${EPHEMERY_DATA_DIR:-${HOME}/ephemery/data}"
CONFIG_DIR="${EPHEMERY_CONFIG_DIR:-${HOME}/ephemery/config}"
LOGS_DIR="${EPHEMERY_LOGS_DIR:-${DATA_DIR}/logs}"
EOF
        
        # Add after setup_traps
        awk -v pathsfile="${temp_file}.paths" '
        BEGIN { added = 0; }
        /setup_traps/ { print; if (!added) { system("cat " pathsfile); added = 1; } next; }
        { print; }
        ' "${script}" > "${temp_file}" && mv "${temp_file}" "${script}"
        
        # Remove temporary paths file
        rm -f "${temp_file}.paths"
    fi
    
    # Replace hardcoded paths with config variables
    sed -i.tmp 's|/opt/ephemery/data|${DATA_DIR}|g' "${script}" && rm "${script}.tmp"
    sed -i.tmp 's|/opt/ephemery/config|${CONFIG_DIR}|g' "${script}" && rm "${script}.tmp"
    sed -i.tmp 's|/opt/ephemery/logs|${LOGS_DIR}|g' "${script}" && rm "${script}.tmp"
    sed -i.tmp 's|${HOME}/ephemery/data|${DATA_DIR}|g' "${script}" && rm "${script}.tmp"
    sed -i.tmp 's|${HOME}/ephemery/config|${CONFIG_DIR}|g' "${script}" && rm "${script}.tmp"
    sed -i.tmp 's|${HOME}/ephemery/logs|${LOGS_DIR}|g' "${script}" && rm "${script}.tmp"
}


# Function: generate_doc_header from scripts/standardize_scripts.sh
generate_doc_header() {
    local script="$1"
    local temp_file="${script}.tmp"
    local script_name=$(basename "${script}")
    local description=""
    
    # Try to extract existing description
    if grep -q "Description:" "${script}"; then
        description=$(grep -E "^#[[:space:]]*Description:" "${script}" | sed -E 's/^#[[:space:]]*Description:[[:space:]]*(.*)/\1/')
    else
        # Try to guess from other header comments
        description=$(grep -E "^#[[:space:]]*[^#]" "${script}" | head -1 | sed -E 's/^#[[:space:]]*(.*)/\1/')
    fi
    
    log_info "Generating standardized documentation header for ${script}"
    
    # Create the new header
    if grep -q "^#!/" "${script}"; then
        # Extract the shebang line
        shebang=$(grep "^#!/" "${script}")
        
        # Create the new header
        cat > "${temp_file}.newheader" << EOF
${shebang}
# Version: 1.0.0
#
# Script Name: ${script_name}
# Description: ${description}
# Author: Ephemery Team
# Created: $(date +%Y-%m-%d)
# Last Modified: $(date +%Y-%m-%d)
EOF
        
        # Combine new header with rest of script, skipping old header
        sed '1d' "${script}" | awk '
        BEGIN { skip = 1; }
        /^[^#]/ { skip = 0; }
        !skip { print; }
        ' > "${temp_file}.body"
        
        cat "${temp_file}.newheader" "${temp_file}.body" > "${temp_file}" && mv "${temp_file}" "${script}"
        
        # Remove temporary files
        rm -f "${temp_file}.newheader" "${temp_file}.body"
    fi
}


# Functions from scripts/organize_scripts.sh
# Mon Mar 17 16:23:07 CET 2025

# Function: find_target_directory from scripts/organize_scripts.sh
find_target_directory() {
  local script="$1"
  for dir in "${!script_categories[@]}"; do
    if [[ " ${script_categories[${dir}]} " == *" ${script} "* ]]; then
      echo "${dir}"
      return 0
    fi
  done
  echo "utilities" # Default category
  return 0
}


# Functions from scripts/reorganize_scripts.sh
# Mon Mar 17 16:23:07 CET 2025

# Function: determine_category from scripts/reorganize_scripts.sh
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


# Function: modify_script from scripts/reorganize_scripts.sh
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
            cat > "${script_path}.temp" << EOF
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
                cat > "${script_path}.temp" << EOF
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
            grep -v -E "^[[:space:]]*[A-Z]+=['\"][\\]033\[[0-9];[0-9]+m['\"]" "$script_path" > "${script_path}.temp"
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


# Function: move_script from scripts/reorganize_scripts.sh
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


# Function: find_scripts from scripts/reorganize_scripts.sh
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


# Function: process_scripts from scripts/reorganize_scripts.sh
process_scripts() {
    log_info "Processing scripts"
    
    for script_entry in $SCRIPTS_TO_MOVE; do
        IFS=":" read -r script category <<< "$script_entry"
        
        log_info "Processing $script -> $category"
        if ! move_script "$script" "$category"; then
            log_warn "Failed to process $script"
        fi
    done
}


# Function: generate_report from scripts/reorganize_scripts.sh
generate_report() {
    log_info "Generating report"
    
    echo -e "\n${BLUE}=== Script Reorganization Report ===${NC}\n"
    
    echo -e "${GREEN}Successfully moved:${NC}"
    for entry in $MOVED_SCRIPTS; do
        IFS=":" read -r script target <<< "$entry"
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
            IFS=":" read -r script reason <<< "$entry"
            echo "  $script - $reason"
        done
    fi
    
    if [[ -n "$FAILED_SCRIPTS" ]]; then
        echo -e "\n${RED}Failed:${NC}"
        for entry in $FAILED_SCRIPTS; do
            IFS=":" read -r script reason <<< "$entry"
            echo "  $script - $reason"
        done
    fi
    
    echo -e "\n${BLUE}======================${NC}\n"
}


# Function: main from scripts/reorganize_scripts.sh
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


# Functions from scripts/update_script_readmes.sh
# Mon Mar 17 16:23:07 CET 2025


# Function for script organization mode
run_organize_mode() {
    log "INFO" "Running script organization..."
    
    # Create standard directory structure if it doesn't exist
    local standard_dirs=(
        "$TARGET_DIR/core"
        "$TARGET_DIR/utilities"
        "$TARGET_DIR/lib"
        "$TARGET_DIR/setup"
        "$TARGET_DIR/maintenance"
        "$TARGET_DIR/deployment"
        "$TARGET_DIR/monitoring"
        "$TARGET_DIR/validator"
        "$TARGET_DIR/testing"
    )
    
    for dir in "${standard_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log "DEBUG" "Would create directory: $dir"
            else
                mkdir -p "$dir"
                log "SUCCESS" "Created directory: $dir"
            fi
        fi
    done
    
    # Find all shell scripts in the target directory
    local scripts=$(find "$TARGET_DIR" -maxdepth 1 -name "*.sh" -type f)
    
    for script in $scripts; do
        local script_name=$(basename "$script")
        local target_subdir=""
        
        # Determine the appropriate subdirectory based on filename pattern or content
        if grep -q "validator\|key" "$script"; then
            target_subdir="validator"
        elif grep -q "monitor\|alert\|metric" "$script"; then
            target_subdir="monitoring"
        elif grep -q "deploy\|provision" "$script"; then
            target_subdir="deployment"
        elif grep -q "setup\|install\|configure" "$script"; then
            target_subdir="setup"
        elif grep -q "maintenance\|backup\|restore\|clean" "$script"; then
            target_subdir="maintenance"
        elif grep -q "common\|util\|helper\|lib" "$script"; then
            target_subdir="lib"
        elif grep -q "test\|check" "$script"; then
            target_subdir="testing"
        fi
        
        # Skip if no appropriate directory found
        [ -z "$target_subdir" ] && continue
        
        # Move the script to the appropriate directory
        if [ "$DRY_RUN" = "true" ]; then
            log "DEBUG" "Would move $script to $TARGET_DIR/$target_subdir/$script_name"
        else
            # Check if destination file already exists
            if [ -f "$TARGET_DIR/$target_subdir/$script_name" ]; then
                log "WARNING" "Destination file already exists: $TARGET_DIR/$target_subdir/$script_name"
                if diff -q "$script" "$TARGET_DIR/$target_subdir/$script_name" >/dev/null; then
                    log "INFO" "Files are identical, removing source file"
                    rm "$script"
                else
                    log "WARNING" "Files differ, keeping both, renaming source"
                    mv "$script" "$TARGET_DIR/$target_subdir/${script_name%.sh}_orig.sh"
                fi
            else
                # Move the file
                mv "$script" "$TARGET_DIR/$target_subdir/"
                log "SUCCESS" "Moved $script_name to $target_subdir/"
            fi
        fi
    done
    
    log "SUCCESS" "Script organization completed"
}

# Function for script standardization mode
run_standardize_mode() {
    log "INFO" "Running script standardization..."
    
    # Find all shell scripts in the target directory and subdirectories
    local scripts=$(find "$TARGET_DIR" -name "*.sh" -type f)
    
    for script in $scripts; do
        log "INFO" "Standardizing $script"
        
        if [ "$DRY_RUN" = "true" ]; then
            log "DEBUG" "Would standardize $script"
            continue
        fi
        
        # Backup the file before modification
        backup_file "$script"
        
        # Apply standard header if missing
        if ! grep -q "#!/bin/bash\|#!/usr/bin/env bash" "$script"; then
            local temp_file=$(mktemp)
            echo '#!/bin/bash' > "$temp_file"
            echo '#' >> "$temp_file"
            echo "# $(basename "$script")" >> "$temp_file"
            echo "# Description: " >> "$temp_file"
            echo "# Author: Ephemery Team" >> "$temp_file"
            echo "# Created: $(date +%Y-%m-%d)" >> "$temp_file"
            echo "# Last Modified: $(date +%Y-%m-%d)" >> "$temp_file"
            echo '#' >> "$temp_file"
            echo "" >> "$temp_file"
            cat "$script" >> "$temp_file"
            mv "$temp_file" "$script"
            log "SUCCESS" "Added standard header to $script"
        fi
        
        # Fix common shell script issues
        sed -i 's/\r$//' "$script"  # Remove Windows line endings
        chmod +x "$script"  # Make script executable
        
        log "SUCCESS" "Standardized $script"
    done
    
    log "SUCCESS" "Script standardization completed"
}

# Function for README update mode
run_readme_mode() {
    log "INFO" "Running README updates..."
    
    # Find all directories that should have README files
    local dirs=$(find "$TARGET_DIR" -type d)
    
    for dir in $dirs; do
        local readme_file="$dir/README.md"
        
        # Skip if README already exists
        [ -f "$readme_file" ] && continue
        
        if [ "$DRY_RUN" = "true" ]; then
            log "DEBUG" "Would create README file for $dir"
            continue
        fi
        
        # Create a basic README file
        local dir_name=$(basename "$dir")
        cat > "$readme_file" << EOT
# $dir_name

This directory contains scripts for the Ephemery node system.

## Contents

$(find "$dir" -maxdepth 1 -name "*.sh" -type f | while read -r script; do
    script_name=$(basename "$script")
    description=$(grep -m 1 "# Description:" "$script" | sed 's/# Description: //g' || echo "No description available")
    echo "- **$script_name**: $description"
done)

## Usage

Please refer to individual script files for specific usage instructions.
EOT
        
        log "SUCCESS" "Created README file for $dir"
    done
    
    log "SUCCESS" "README updates completed"
}

# Function for repository-wide standardization
run_repo_mode() {
    log "INFO" "Running repository-wide standardization..."
    
    # Fix file permissions
    if [ "$DRY_RUN" = "true" ]; then
        log "DEBUG" "Would fix file permissions"
    else
        find "$PROJECT_ROOT" -name "*.sh" -type f -exec chmod +x {} \;
        log "SUCCESS" "Fixed permissions for shell scripts"
    fi
    
    # Standardize line endings
    if [ "$DRY_RUN" = "true" ]; then
        log "DEBUG" "Would standardize line endings"
    else
        find "$PROJECT_ROOT" -name "*.sh" -type f -exec sed -i 's/\r$//' {} \;
        find "$PROJECT_ROOT" -name "*.py" -type f -exec sed -i 's/\r$//' {} \;
        find "$PROJECT_ROOT" -name "*.md" -type f -exec sed -i 's/\r$//' {} \;
        log "SUCCESS" "Standardized line endings"
    fi
    
    # Run additional repo-wide standardization tasks here
    # ...
    
    log "SUCCESS" "Repository-wide standardization completed"
}

# Main execution based on mode
if [[ "$MODE" == "all" || "$MODE" == "organize" ]]; then
    run_organize_mode
fi

if [[ "$MODE" == "all" || "$MODE" == "standardize" ]]; then
    run_standardize_mode
fi

if [[ "$MODE" == "all" || "$MODE" == "readme" ]]; then
    run_readme_mode
fi

if [[ "$MODE" == "all" || "$MODE" == "repo" ]]; then
    run_repo_mode
fi

log "SUCCESS" "All standardization tasks completed"
