#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: standardize_scripts.sh
# Description: Automates standardization of shell scripts for the Ephemery project
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source the common library
source "${SCRIPT_DIR}/lib/common.sh"

# Setup error handling
setup_traps

# Default settings
DRY_RUN=false
VERBOSE=false
BACKUP=true
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
TARGET_SCRIPTS=()

# Print usage information
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

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            print_usage
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
        -n|--no-backup)
            BACKUP=false
            shift
            ;;
        -a|--all)
            # Find all shell scripts
            mapfile -t TARGET_SCRIPTS < <(find "${SCRIPTS_DIR}" -type f -name "*.sh" ! -path "*/lib/*" ! -path "*/testing/*")
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            # Add script to the list
            TARGET_SCRIPTS+=("$1")
            shift
            ;;
    esac
done

# Verify we have scripts to process
if [[ ${#TARGET_SCRIPTS[@]} -eq 0 ]]; then
    log_error "No scripts specified for standardization"
    print_usage
    exit 1
fi

# Function to create a backup of a script
create_backup() {
    local script="$1"
    local backup="${script}.bak"
    
    if [[ "${BACKUP}" == "true" ]]; then
        log_info "Creating backup of ${script} to ${backup}"
        cp "${script}" "${backup}"
    fi
}

# Function to check if a script already uses the common library
uses_common_lib() {
    local script="$1"
    
    if grep -q "source.*scripts/lib/common.sh" "${script}"; then
        return 0
    else
        return 1
    fi
}

# Function to check if a script already uses the config library
uses_config_lib() {
    local script="$1"
    
    if grep -q "source.*scripts/lib/config.sh" "${script}"; then
        return 0
    else
        return 1
    fi
}

# Function to add common library import
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
        ' "${script}" > "${temp_file}" && mv "${temp_file}" "${script}"
        
        # Remove temporary header file
        rm -f "${temp_file}.header"
    else
        # Create full header template 
        cat > "${temp_file}.header" << 'EOF'
#!/usr/bin/env bash
# Version: 1.0.0
#
EOF
        
        # Add script name and date
        echo "# Script Name: $(basename "${script}")" >> "${temp_file}.header"
        echo "# Description: " >> "${temp_file}.header"
        echo "# Author: Ephemery Team" >> "${temp_file}.header"
        echo "# Created: $(date +%Y-%m-%d)" >> "${temp_file}.header"
        echo "# Last Modified: $(date +%Y-%m-%d)" >> "${temp_file}.header"
        echo "" >> "${temp_file}.header"
        echo "# Get the absolute path to the script directory" >> "${temp_file}.header"
        echo 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"' >> "${temp_file}.header"
        echo 'PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"' >> "${temp_file}.header"
        echo "" >> "${temp_file}.header"
        echo "# Source the common library" >> "${temp_file}.header"
        echo 'source "${PROJECT_ROOT}/scripts/lib/common.sh"' >> "${temp_file}.header"
        echo "" >> "${temp_file}.header"
        echo "# Setup error handling" >> "${temp_file}.header"
        echo "setup_traps" >> "${temp_file}.header"
        echo "" >> "${temp_file}.header"
        
        # Combine header with existing script
        cat "${temp_file}.header" "${script}" > "${temp_file}" && mv "${temp_file}" "${script}"
        
        # Remove temporary header file
        rm -f "${temp_file}.header"
    fi
}

# Function to add config library import
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

# Function to replace echo statements with log_* functions
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
    
    # Replace warning patterns
    match($0, /(^|[[:space:]])echo[[:space:]]+(-e[[:space:]]+)?".*(Warn|WARNING|[Cc]aution).*"/) {
        before = substr($0, 1, RSTART-1);
        cmd = substr($0, RSTART, RLENGTH);
        after = substr($0, RSTART+RLENGTH);
        
        msg_start = index(cmd, "\"");
        msg_part = substr(cmd, msg_start);
        sub(/;?[[:space:]]*$/, "", msg_part);
        
        print before "log_warn " msg_part after;
        next;
    }
    
    # Replace success patterns
    match($0, /(^|[[:space:]])echo[[:space:]]+(-e[[:space:]]+)?".*(Success|SUCCESS|[Cc]omplete|COMPLETE).*"/) {
        before = substr($0, 1, RSTART-1);
        cmd = substr($0, RSTART, RLENGTH);
        after = substr($0, RSTART+RLENGTH);
        
        msg_start = index(cmd, "\"");
        msg_part = substr(cmd, msg_start);
        sub(/;?[[:space:]]*$/, "", msg_part);
        
        print before "log_success " msg_part after;
        next;
    }
    
    # Replace debug patterns
    match($0, /(^|[[:space:]])echo[[:space:]]+(-e[[:space:]]+)?".*(Debug|DEBUG).*"/) {
        before = substr($0, 1, RSTART-1);
        cmd = substr($0, RSTART, RLENGTH);
        after = substr($0, RSTART+RLENGTH);
        
        msg_start = index(cmd, "\"");
        msg_part = substr(cmd, msg_start);
        sub(/;?[[:space:]]*$/, "", msg_part);
        
        print before "log_debug " msg_part after;
        next;
    }
    
    # For all other echo statements (info level)
    match($0, /(^|[[:space:]])echo[[:space:]]+(-e[[:space:]]+)?["'"]/) {
        cmd = substr($0, RSTART);
        before = substr($0, 1, RSTART-1);
        
        # Only replace if it"s a real echo statement, not inside commands or functions
        if (before ~ /^[[:space:]]*$/ || before ~ /[;|][[:space:]]*$/ || before ~ /\)[[:space:]]*$/ || before ~ /\{[[:space:]]*$/ || before ~ /\[\[[[:space:]]*$/) {
            # Find the quoted string
            quote_char = substr(cmd, length(cmd), 1);
            
            # Find the closing quote - need to handle escaped quotes
            i = 1;
            in_quote = 0;
            quote_end = 0;
            quote_start = 0;
            for (i = 1; i <= length(cmd); i++) {
                char = substr(cmd, i, 1);
                if (char == quote_char && (i == 1 || substr(cmd, i-1, 1) != "\\")) {
                    if (!in_quote) {
                        in_quote = 1;
                        quote_start = i;
                    } else {
                        in_quote = 0;
                        quote_end = i;
                        break;
                    }
                }
            }
            
            if (quote_end > 0) {
                msg_part = substr(cmd, quote_start, quote_end - quote_start + 1);
                command_start = substr(cmd, 1, quote_start - 1);
                command_end = substr(cmd, quote_end + 1);
                
                # Check if echo has -e option
                if (command_start ~ /-e/) {
                    sub(/-e[[:space:]]+/, "", command_start);
                }
                
                # Replace echo with log_info
                print before "log_info " msg_part command_end;
                next;
            }
        }
    }
    
    # Default case: print unchanged
    { print; }
    ' "${script}" > "${temp_file}" && mv "${temp_file}" "${script}"
}

# Function to replace exit handling
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

EOF
        
        # Add cleanup function before main or at the end of the file
        awk -v cleanupfile="${temp_file}.cleanup" '
        BEGIN { added = 0; }
        /^# Main/              { if (!added) { system("cat " cleanupfile); added = 1; } print; next; }
        /^# Run main/          { if (!added) { system("cat " cleanupfile); added = 1; } print; next; }
        /^main/                { if (!added) { system("cat " cleanupfile); added = 1; } print; next; }
        END                    { if (!added) { system("cat " cleanupfile); } }
        { print; }
        ' "${script}" > "${temp_file}" && mv "${temp_file}" "${script}"
        
        # Remove temporary cleanup file
        rm -f "${temp_file}.cleanup"
    fi
    
    # Replace set -e with setup_traps
    sed -i.tmp 's/set -e/# Strict error handling is now handled by setup_traps/g' "${script}" && rm "${script}.tmp"
    sed -i.tmp 's/set -euo pipefail/# Strict error handling is now handled by setup_traps/g' "${script}" && rm "${script}.tmp"
}

# Function to update path handling to use config
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

# Function to generate standardized documentation header
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

# Process each script
for script in "${TARGET_SCRIPTS[@]}"; do
    if [[ ! -f "${script}" ]]; then
        log_warn "Script not found: ${script}"
        continue
    fi
    
    log_info "Processing script: ${script}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would standardize ${script}"
        continue
    fi
    
    # Create backup
    create_backup "${script}"
    
    # Add common library if not already present
    if ! uses_common_lib "${script}"; then
        add_common_lib "${script}"
    fi
    
    # Add config library if needed
    if ! uses_config_lib "${script}"; then
        add_config_lib "${script}"
    fi
    
    # Replace echo statements with log_* functions
    replace_echo_with_log "${script}"
    
    # Add error handling
    add_error_handling "${script}"
    
    # Update path handling to use config system
    update_path_handling "${script}"
    
    # Generate standardized documentation header
    generate_doc_header "${script}"
    
    log_success "Standardized script: ${script}"
done

log_success "Script standardization completed"
exit 0 