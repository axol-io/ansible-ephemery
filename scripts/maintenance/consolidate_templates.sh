#!/bin/bash

# consolidate_templates.sh - Script to consolidate templates into a single location
# This script helps migrate templates from /templates to /ansible/templates

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Import common functions
if [[ -f "${PROJECT_ROOT}/scripts/lib/common_basic.sh" ]]; then
    source "${PROJECT_ROOT}/scripts/lib/common_basic.sh"
else
    # Define colors for output if common library is not available
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
    
    # Function to print colored messages
    print_status() {
        local color=$1
        local message=$2
        echo -e "${color}${message}${NC}"
    }
fi

# Define source and target directories
SOURCE_DIR="${PROJECT_ROOT}/templates"
TARGET_DIR="${PROJECT_ROOT}/ansible/templates"

# Function to show help message
show_help() {
    echo "Template Consolidator - Tool to consolidate templates into a single location"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --analyze               Analyze templates and report (no changes made)"
    echo "  --dry-run               Show what would be done (no changes made)"
    echo "  --organize              Organize templates by category"
    echo "  --execute               Actually perform the migration"
    echo "  --help                  Show this help message"
}

# Function to analyze templates
analyze_templates() {
    if [[ ! -d "$SOURCE_DIR" ]]; then
        print_status "$YELLOW" "Source directory does not exist: $SOURCE_DIR"
        return 1
    fi
    
    if [[ ! -d "$TARGET_DIR" ]]; then
        print_status "$YELLOW" "Target directory does not exist: $TARGET_DIR"
        return 1
    fi
    
    print_status "$GREEN" "Analyzing templates..."
    
    # Count templates in source directory
    local source_count=$(find "$SOURCE_DIR" -type f | grep -v '.git' | wc -l | tr -d '[:space:]')
    print_status "$BLUE" "Found $source_count templates in source directory: $SOURCE_DIR"
    
    # Count templates in target directory
    local target_count=$(find "$TARGET_DIR" -type f | grep -v '.git' | wc -l | tr -d '[:space:]')
    print_status "$BLUE" "Found $target_count templates in target directory: $TARGET_DIR"
    
    # Find unique and duplicate templates
    local duplicates=0
    local unique=0
    local duplicate_files=""
    local unique_files=""
    
    print_status "$GREEN" "Checking for duplicates..."
    
    find "$SOURCE_DIR" -type f | grep -v '.git' | while read source_file; do
        local rel_path="${source_file#${SOURCE_DIR}/}"
        local target_file="${TARGET_DIR}/${rel_path}"
        
        if [[ -f "$target_file" ]]; then
            if diff -q "$source_file" "$target_file" > /dev/null; then
                duplicates=$((duplicates + 1))
                duplicate_files="${duplicate_files}${rel_path}\n"
            else
                print_status "$YELLOW" "Warning: File exists in both locations but content differs: ${rel_path}"
            fi
        else
            unique=$((unique + 1))
            unique_files="${unique_files}${rel_path}\n"
        fi
    done
    
    print_status "$BLUE" "Found $duplicates duplicate templates"
    if [[ $duplicates -gt 0 ]]; then
        print_status "$BLUE" "Duplicate templates:"
        echo -e "$duplicate_files"
    fi
    
    print_status "$BLUE" "Found $unique unique templates in source that need to be migrated"
    if [[ $unique -gt 0 ]]; then
        print_status "$BLUE" "Unique templates to migrate:"
        echo -e "$unique_files"
    fi
    
    return 0
}

# Function to perform a dry run
dry_run() {
    if [[ ! -d "$SOURCE_DIR" || ! -d "$TARGET_DIR" ]]; then
        print_status "$RED" "Source or target directory does not exist"
        return 1
    fi
    
    print_status "$GREEN" "Dry run: showing actions that would be performed..."
    
    find "$SOURCE_DIR" -type f | grep -v '.git' | while read source_file; do
        local rel_path="${source_file#${SOURCE_DIR}/}"
        local target_file="${TARGET_DIR}/${rel_path}"
        
        if [[ -f "$target_file" ]]; then
            if diff -q "$source_file" "$target_file" > /dev/null; then
                print_status "$BLUE" "Would skip (identical): ${rel_path}"
            else
                print_status "$YELLOW" "Would need manual review (content differs): ${rel_path}"
            fi
        else
            print_status "$GREEN" "Would copy: ${rel_path}"
        fi
    done
    
    return 0
}

# Function to organize templates by category
organize_templates() {
    local execute=$1
    
    if [[ ! -d "$TARGET_DIR" ]]; then
        print_status "$RED" "Target directory does not exist: $TARGET_DIR"
        return 1
    fi
    
    print_status "$GREEN" "Organizing templates by category..."
    
    # Define categories and patterns using separate arrays
    local categories=("monitoring" "configuration" "services" "scripts" "nginx" "docker")
    local patterns=("monitor|dashboard|grafana|prometheus" "conf|config|cfg|yaml|yml|ini" "service|systemd" "sh|bash|py|python" "nginx" "docker|compose")
    
    # Create category directories (if in execute mode)
    if [[ "$execute" == "true" ]]; then
        for category in "${categories[@]}"; do
            mkdir -p "${TARGET_DIR}/${category}"
            print_status "$BLUE" "Created category directory: ${category}"
        done
    fi
    
    # Organize files
    find "$TARGET_DIR" -maxdepth 1 -type f | while read file; do
        local filename=$(basename "$file")
        local matched=false
        
        for i in "${!categories[@]}"; do
            local category="${categories[$i]}"
            local pattern="${patterns[$i]}"
            if echo "$filename" | grep -iE "$pattern" > /dev/null; then
                matched=true
                if [[ "$execute" == "true" ]]; then
                    mv "$file" "${TARGET_DIR}/${category}/"
                    print_status "$GREEN" "Moved: $filename -> ${category}/"
                else
                    print_status "$GREEN" "Would move: $filename -> ${category}/"
                fi
                break
            fi
        done
        
        if [[ "$matched" == "false" ]]; then
            print_status "$YELLOW" "No category match for: $filename"
        fi
    done
    
    # Handle subdirectories separately - scripts is already a subdirectory
    if [[ -d "${TARGET_DIR}/scripts" && "$execute" == "true" ]]; then
        print_status "$BLUE" "Scripts directory already exists, leaving intact"
    fi
    
    return 0
}

# Function to execute the migration
execute_migration() {
    if [[ ! -d "$SOURCE_DIR" || ! -d "$TARGET_DIR" ]]; then
        print_status "$RED" "Source or target directory does not exist"
        return 1
    fi
    
    print_status "$GREEN" "Executing template migration..."
    
    # Create a backup directory for conflicting files
    local backup_dir="${PROJECT_ROOT}/scripts/maintenance/template_backup"
    mkdir -p "$backup_dir"
    
    find "$SOURCE_DIR" -type f | grep -v '.git' | while read source_file; do
        local rel_path="${source_file#${SOURCE_DIR}/}"
        local target_file="${TARGET_DIR}/${rel_path}"
        local target_dir=$(dirname "$target_file")
        
        # Create target directory if it doesn't exist
        if [[ ! -d "$target_dir" ]]; then
            mkdir -p "$target_dir"
            print_status "$BLUE" "Created directory: ${target_dir#${PROJECT_ROOT}/}"
        fi
        
        if [[ -f "$target_file" ]]; then
            if diff -q "$source_file" "$target_file" > /dev/null; then
                print_status "$BLUE" "Skipping identical file: ${rel_path}"
            else
                # Backup the conflicting file
                local backup_file="${backup_dir}/${rel_path}"
                mkdir -p "$(dirname "$backup_file")"
                cp "$source_file" "$backup_file"
                print_status "$YELLOW" "Conflict: ${rel_path} (backed up to template_backup)"
            fi
        else
            cp "$source_file" "$target_file"
            print_status "$GREEN" "Copied: ${rel_path}"
        fi
    done
    
    print_status "$GREEN" "Migration completed."
    print_status "$YELLOW" "Note: You should manually verify the results and update references."
    print_status "$YELLOW" "Once verified, you can remove the source directory."
    
    return 0
}

# Main function
main() {
    # Default configuration
    local analyze=false
    local dry_run=false
    local organize=false
    local execute=false
    
    # No arguments provided, show help
    if [[ $# -eq 0 ]]; then
        show_help
        return 1
    fi
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --analyze)
                analyze=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --organize)
                organize=true
                shift
                ;;
            --execute)
                execute=true
                shift
                ;;
            --help)
                show_help
                return 0
                ;;
            *)
                print_status "$RED" "Error: Unknown option: $1"
                show_help
                return 1
                ;;
        esac
    done
    
    # Execute the requested actions
    if [[ "$analyze" == "true" ]]; then
        analyze_templates
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        dry_run
    fi
    
    if [[ "$organize" == "true" ]]; then
        if [[ "$execute" == "true" ]]; then
            organize_templates "true"
        else
            organize_templates "false"
        fi
    fi
    
    if [[ "$execute" == "true" ]]; then
        print_status "$YELLOW" "WARNING: This will copy templates from $SOURCE_DIR to $TARGET_DIR"
        print_status "$YELLOW" "Conflicting files will be backed up in scripts/maintenance/template_backup"
        read -p "Do you want to proceed? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            execute_migration
        else
            print_status "$YELLOW" "Migration cancelled."
        fi
    fi
    
    return 0
}

# Call main function with all arguments
main "$@"

exit $? 