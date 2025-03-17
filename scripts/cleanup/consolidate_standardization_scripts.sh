#!/bin/bash
#
# This script consolidates standardization-related scripts
# 

set -e

# Print header
echo "====================================================="
echo "     Consolidating Standardization Scripts            "
echo "====================================================="

# Define scripts to consolidate
SCRIPT_FILES=(
    "scripts/standardize_scripts.sh"
    "scripts/organize_scripts.sh"
    "scripts/reorganize_scripts.sh"
    "scripts/update_script_readmes.sh"
    "scripts/script_backups/standardize_repository.sh"
    "scripts/script_backups/repo-standards.sh"
)

# Define the target consolidated script
TARGET_SCRIPT="scripts/consolidated_standardization.sh"
BACKUP_DIR="standardization_scripts_backup_$(date +%Y%m%d_%H%M%S)"

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "Created backup directory: $BACKUP_DIR"

# Verify script files
EXISTING_SCRIPTS=()
for script in "${SCRIPT_FILES[@]}"; do
    if [ -f "$script" ]; then
        EXISTING_SCRIPTS+=("$script")
        cp "$script" "$BACKUP_DIR/$(basename "$script")"
        echo "Backed up $script"
    else
        echo "Warning: Script $script not found, skipping"
    fi
done

if [ ${#EXISTING_SCRIPTS[@]} -eq 0 ]; then
    echo "No standardization scripts found. Exiting."
    exit 1
fi

# Create consolidated script header
cat > "$TARGET_SCRIPT" << 'EOF'
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

EOF

# Define a function to extract functions from standardization scripts
extract_standardization_functions() {
    local file="$1"
    local output="$2"
    
    if [ ! -f "$file" ]; then
        echo "Warning: File $file does not exist"
        return 1
    fi
    
    echo "# Functions from $file" >> "$output"
    echo "# $(date)" >> "$output"
    echo "" >> "$output"
    
    # Extract all function definitions
    grep -n "^[[:space:]]*\(function[[:space:]]\+\)\?[a-zA-Z0-9_]\+[[:space:]]*()[[:space:]]*{" "$file" | \
    while IFS=":" read -r line_num pattern; do
        local func_name=$(echo "$pattern" | sed -E 's/^[[:space:]]*(function[[:space:]]+)?([a-zA-Z0-9_]+)[[:space:]]*\(\).*$/\2/')
        echo "Extracting function: $func_name from $file"
        
        # Find the end of the function
        local start_line=$line_num
        local end_line=$(tail -n +$start_line "$file" | grep -n "^[[:space:]]*}[[:space:]]*$" | head -1 | cut -d: -f1)
        end_line=$((start_line + end_line))
        
        # Extract the function with a header comment
        echo "# Function: $func_name from $file" >> "$output"
        sed -n "${start_line},${end_line}p" "$file" >> "$output"
        echo "" >> "$output"
    done
}

# Extract functions from each standardization script
for script in "${EXISTING_SCRIPTS[@]}"; do
    extract_standardization_functions "$script" "$TARGET_SCRIPT"
done

# Add mode-specific execution functions
cat >> "$TARGET_SCRIPT" << 'EOF'

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
EOF

# Make the consolidated script executable
chmod +x "$TARGET_SCRIPT"

echo 
echo "Created consolidated standardization script: $TARGET_SCRIPT"
echo "Original scripts backed up to $BACKUP_DIR"
echo
echo "Next steps:"
echo "1. Review the consolidated script"
echo "2. Test it with --dry-run option: $TARGET_SCRIPT --dry-run"
echo "3. Test individual modes: $TARGET_SCRIPT --mode organize/standardize/readme/repo"
echo "4. After verifying everything works, you can remove the original scripts" 