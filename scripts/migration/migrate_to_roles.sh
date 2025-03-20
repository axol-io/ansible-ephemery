#!/bin/bash

set -euo pipefail

# Configuration
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
LEGACY_DIRS=(
  "ansible/clients"
  "ansible/tasks"
  "ansible/playbooks"
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

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to backup a directory
backup_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    log_info "Backing up $dir to $BACKUP_DIR"
    cp -r "$dir" "$BACKUP_DIR/"
  else
    log_warn "Directory $dir does not exist, skipping backup"
  fi
}

# Function to verify backup
verify_backup() {
  local dir="$1"
  if [ -d "$BACKUP_DIR/$(basename "$dir")" ]; then
    log_info "Backup verified for $dir"
    return 0
  else
    log_error "Backup verification failed for $dir"
    return 1
  fi
}

# Main migration process
main() {
  log_info "Starting migration process..."

  # Step 1: Backup legacy directories
  log_info "Step 1: Creating backups..."
  for dir in "${LEGACY_DIRS[@]}"; do
    backup_dir "$dir"
    if ! verify_backup "$dir"; then
      log_error "Backup verification failed. Aborting migration."
      exit 1
    fi
  done

  # Step 2: Verify new role structure
  log_info "Step 2: Verifying new role structure..."
  if [ ! -d "ansible/roles" ]; then
    log_error "New role structure not found. Please ensure roles are properly set up."
    exit 1
  fi

  # Step 3: Run test playbook
  log_info "Step 3: Running test playbook..."
  TEST_PLAYBOOK="playbooks/test_role_migration.yml"
  if [ ! -f "$TEST_PLAYBOOK" ]; then
    log_error "Test playbook not found at $TEST_PLAYBOOK. Please ensure it exists."
    exit 1
  fi

  # Verify the playbook doesn't have syntax errors
  log_info "Checking playbook syntax..."
  if ! ansible-playbook --syntax-check "$TEST_PLAYBOOK"; then
    log_error "Playbook syntax check failed. Please fix the errors and try again."
    exit 1
  fi

  # Run the test playbook
  if ! ansible-playbook "$TEST_PLAYBOOK" -e "test_mode=true"; then
    log_error "Test playbook failed. Please review the errors and fix them."
    exit 1
  fi

  # Step 4: Remove legacy directories
  log_info "Step 4: Removing legacy directories..."
  read -p "Tests have passed. Do you want to proceed with removing legacy directories? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Migration cancelled by user"
    exit 0
  fi

  for dir in "${LEGACY_DIRS[@]}"; do
    if [ -d "$dir" ]; then
      log_info "Removing $dir"
      rm -rf "$dir"
    else
      log_warn "Directory $dir already removed"
    fi
  done

  # Step 5: Update inventory files
  log_info "Step 5: Updating inventory files..."
  if [ -f "ansible/inventory.ini" ]; then
    sed -i.bak 's/\[clients\]/[execution_nodes]/' ansible/inventory.ini
    sed -i.bak 's/\[validators\]/[consensus_nodes]/' ansible/inventory.ini
    rm -f ansible/inventory.ini.bak
  fi

  log_info "Migration completed successfully!"
  log_info "Backup location: $BACKUP_DIR"
  log_warn "Please review the changes and update any custom configurations as needed."
}

# Run main function
main
