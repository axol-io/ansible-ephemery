#!/bin/bash

set -euo pipefail

# Configuration
LEGACY_FILES=(
    "ansible/clients/*"
    "ansible/tasks/*"
    "ansible/playbooks/*"
    "templates/legacy/*"
    "config/old/*"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if file is obsolete
is_obsolete() {
    local file="$1"
    local pattern="$2"
    
    # Check if file matches any of the legacy patterns
    if [[ "$file" == $pattern ]]; then
        return 0
    fi
    
    # Check if file has been replaced by new role structure
    if [[ "$file" == *"/clients/"* ]] || [[ "$file" == *"/tasks/"* ]] || [[ "$file" == *"/playbooks/"* ]]; then
        return 0
    fi
    
    return 1
}

# Function to safely remove file
remove_file() {
    local file="$1"
    if [ -f "$file" ] || [ -d "$file" ]; then
        # Create backup of the file before removing
        local backup_dir="backups/cleanup/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        local rel_path="${file#./}"
        local backup_path="$backup_dir/$rel_path"
        mkdir -p "$(dirname "$backup_path")"
        
        log_info "Backing up $file to $backup_path"
        cp -r "$file" "$backup_path"
        
        log_info "Removing $file"
        rm -rf "$file"
    else
        log_warn "File $file does not exist, skipping"
    fi
}

# Function to check if migration was successful
check_migration() {
    log_info "Checking if migration was successful..."
    
    # Check if new roles exist
    if [ ! -d "ansible/roles/common" ] || [ ! -d "ansible/roles/execution_client" ] || [ ! -d "ansible/roles/consensus_client" ] || [ ! -d "ansible/roles/validator" ]; then
        log_error "New roles not found. Please run migration first."
        return 1
    fi
    
    # Check if test playbook exists
    if [ ! -f "playbooks/test_role_migration.yml" ]; then
        log_error "Test playbook not found. Migration may not be complete."
        return 1
    fi
    
    return 0
}

# Main cleanup process
main() {
    log_info "Starting cleanup process..."

    # Step 1: Verify test playbook passed
    log_info "Step 1: Verifying test results..."
    if ! check_migration; then
        log_error "Migration verification failed. Please complete the migration process first."
        exit 1
    fi

    # Step 2: Check for obsolete files
    log_info "Step 2: Checking for obsolete files..."
    declare -a files_to_remove=()
    for pattern in "${LEGACY_FILES[@]}"; do
        for file in $pattern; do
            if [ -e "$file" ] && is_obsolete "$file" "$pattern"; then
                log_info "Found obsolete file: $file"
                files_to_remove+=("$file")
            fi
        done
    done
    
    # Display summary of files to be removed
    if [ ${#files_to_remove[@]} -eq 0 ]; then
        log_info "No obsolete files found. Nothing to clean up."
        exit 0
    else
        log_info "Found ${#files_to_remove[@]} obsolete files to remove."
        for file in "${files_to_remove[@]}"; do
            echo "  - $file"
        done
    fi

    # Step 3: Confirm removal
    read -p "Do you want to proceed with removing these files? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Cleanup cancelled by user"
        exit 0
    fi

    # Step 4: Remove obsolete files
    log_info "Step 4: Removing obsolete files..."
    for file in "${files_to_remove[@]}"; do
        remove_file "$file"
    done

    # Step 5: Clean up empty directories
    log_info "Step 5: Cleaning up empty directories..."
    find ansible -type d -empty -delete
    find templates -type d -empty -delete
    find config -type d -empty -delete

    log_info "Cleanup completed successfully!"
    log_warn "Please verify that all required functionality is working with the new role structure."
}

# Check if running as source
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    main
fi 