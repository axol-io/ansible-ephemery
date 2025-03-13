#!/bin/bash
#
# Enhanced Validator Key Restore Script for Ephemery
# This script provides robust key restore capabilities with validation and verification

set -e

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default values
BACKUP_DIR=""
TARGET_DIR=""
FORCE=false
DRY_RUN=false
VERIFY=true
CREATE_BACKUP=true
VERBOSE=false
EXPECTED_KEY_COUNT=0

# Help function
function show_help {
  echo -e "${BLUE}Enhanced Validator Key Restore for Ephemery${NC}"
  echo ""
  echo "This script restores validator keys from backup with verification and validation."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -b, --backup-dir DIR    Source backup directory containing validator keys (required)"
  echo "  -t, --target-dir DIR    Target directory to restore keys to (required)"
  echo "  -f, --force             Force restore even if validation fails"
  echo "  -d, --dry-run           Perform validation without actual restore"
  echo "  -n, --no-backup         Skip creating backup of existing keys"
  echo "  -s, --skip-verify       Skip verification steps"
  echo "  -c, --count NUM         Expected key count (set to 0 to skip count validation)"
  echo "  -v, --verbose           Enable verbose output"
  echo "  -h, --help              Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --backup-dir /path/to/backup --target-dir /path/to/validator/keys"
  echo "  $0 --backup-dir /path/to/backup --target-dir /path/to/validator/keys --force --no-backup"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--backup-dir)
      BACKUP_DIR="$2"
      shift 2
      ;;
    -t|--target-dir)
      TARGET_DIR="$2"
      shift 2
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    -d|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -n|--no-backup)
      CREATE_BACKUP=false
      shift
      ;;
    -s|--skip-verify)
      VERIFY=false
      shift
      ;;
    -c|--count)
      EXPECTED_KEY_COUNT="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local color="$NC"

  case "$level" in
    "INFO") color="$GREEN" ;;
    "WARN") color="$YELLOW" ;;
    "ERROR") color="$RED" ;;
    "DEBUG")
      color="$BLUE"
      if [[ "$VERBOSE" != "true" ]]; then
        return
      fi
      ;;
  esac

  echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
}

# Validate required parameters
if [[ -z "$BACKUP_DIR" ]]; then
  log "ERROR" "Backup directory is required. Use --backup-dir option."
  show_help
  exit 1
fi

if [[ -z "$TARGET_DIR" ]]; then
  log "ERROR" "Target directory is required. Use --target-dir option."
  show_help
  exit 1
fi

# Check if the backup directory exists
if [[ ! -d "$BACKUP_DIR" ]]; then
  log "ERROR" "Backup directory does not exist: $BACKUP_DIR"
  exit 1
fi

# Function to validate JSON files
validate_json_files() {
  local dir="$1"
  local valid_count=0
  local invalid_count=0
  local invalid_files=()

  log "INFO" "Validating JSON files in $dir..."

  # Find all JSON files
  local files=$(find "$dir" -type f -name "*.json" 2>/dev/null)
  local total_files=$(echo "$files" | wc -l)

  if [[ "$total_files" -eq 0 ]]; then
    log "ERROR" "No JSON files found in $dir"
    return 1
  }

  log "INFO" "Found $total_files JSON files"

  # Check each file for valid JSON format
  for file in $files; do
    if jq -e . "$file" >/dev/null 2>&1; then
      valid_count=$((valid_count + 1))
      log "DEBUG" "Valid JSON: $file"
    else
      invalid_count=$((invalid_count + 1))
      invalid_files+=("$file")
      log "DEBUG" "Invalid JSON: $file"
    fi
  done

  # Check for expected key count if specified
  if [[ "$EXPECTED_KEY_COUNT" -gt 0 ]]; then
    if [[ "$valid_count" -ne "$EXPECTED_KEY_COUNT" ]]; then
      log "WARN" "Expected $EXPECTED_KEY_COUNT keys but found $valid_count valid keys"
      if [[ "$FORCE" != "true" ]]; then
        log "ERROR" "Key count validation failed. Use --force to override."
        return 1
      fi
    else
      log "INFO" "Key count validation passed: $valid_count keys"
    fi
  fi

  # Report validation results
  log "INFO" "Validation results: $valid_count valid, $invalid_count invalid JSON files"

  if [[ "$invalid_count" -gt 0 ]]; then
    log "WARN" "Found $invalid_count invalid JSON files:"
    for file in "${invalid_files[@]}"; do
      log "WARN" "  - $file"
    done

    if [[ "$FORCE" != "true" ]]; then
      log "ERROR" "JSON validation failed. Use --force to override."
      return 1
    fi
  fi

  return 0
}

# Function to check for validator keys
check_validator_keys() {
  local dir="$1"
  local keys_found=false

  log "INFO" "Checking for validator keys in $dir..."

  # Find JSON files containing pubkey field (likely validator keys)
  local validator_keys=$(find "$dir" -type f -name "*.json" -exec grep -l "\"pubkey\":" {} \; 2>/dev/null)
  local key_count=$(echo "$validator_keys" | wc -l)

  if [[ "$key_count" -gt 0 ]]; then
    keys_found=true
    log "INFO" "Found $key_count potential validator keys"
  else
    log "WARN" "No validator keys found in $dir"
  fi

  echo "$keys_found"
}

# Function to create a backup of existing keys
create_backup() {
  local source_dir="$1"
  local backup_name="validator_keys_backup_$(date +%Y%m%d%H%M%S)"
  local backup_path="${source_dir}_backups/${backup_name}"

  log "INFO" "Creating backup of existing keys: $backup_path"

  # Create backup directory
  mkdir -p "$(dirname "$backup_path")"

  # Copy files to backup
  if rsync -a "$source_dir/" "$backup_path/"; then
    log "INFO" "Backup created successfully: $backup_path"
    # Create a symlink to the latest backup
    ln -sf "$backup_name" "$(dirname "$backup_path")/latest"
    return 0
  else
    log "ERROR" "Failed to create backup"
    return 1
  fi
}

# Function to restore keys
restore_keys() {
  local source_dir="$1"
  local target_dir="$2"

  log "INFO" "Restoring keys from $source_dir to $target_dir..."

  # Create target directory if it doesn't exist
  mkdir -p "$target_dir"

  # Create a temporary directory for staging
  local tmp_dir=$(mktemp -d)
  log "DEBUG" "Created temporary directory: $tmp_dir"

  # Copy files to temporary directory
  if ! rsync -a "$source_dir/" "$tmp_dir/"; then
    log "ERROR" "Failed to copy files to temporary directory"
    rm -rf "$tmp_dir"
    return 1
  fi

  # Verify the copy
  local source_count=$(find "$source_dir" -type f -name "*.json" | wc -l)
  local tmp_count=$(find "$tmp_dir" -type f -name "*.json" | wc -l)

  if [[ "$source_count" -ne "$tmp_count" ]]; then
    log "ERROR" "File count mismatch: source=$source_count, tmp=$tmp_count"
    rm -rf "$tmp_dir"
    return 1
  fi

  # Perform atomic move to target directory
  if rsync -a --delete "$tmp_dir/" "$target_dir/"; then
    log "INFO" "Keys restored successfully to $target_dir"
    rm -rf "$tmp_dir"
    return 0
  else
    log "ERROR" "Failed to move files to target directory"
    rm -rf "$tmp_dir"
    return 1
  fi
}

# Verify the backup directory contains valid keys
if [[ "$VERIFY" == "true" ]]; then
  validate_json_files "$BACKUP_DIR" || exit 1

  # Check for validator keys
  keys_found=$(check_validator_keys "$BACKUP_DIR")
  if [[ "$keys_found" != "true" && "$FORCE" != "true" ]]; then
    log "ERROR" "No validator keys found in backup directory. Use --force to override."
    exit 1
  fi
fi

# Check if target directory exists and contains keys
if [[ -d "$TARGET_DIR" ]]; then
  log "INFO" "Target directory exists: $TARGET_DIR"

  # Count existing keys
  existing_keys=$(find "$TARGET_DIR" -type f -name "*.json" | wc -l)
  if [[ "$existing_keys" -gt 0 ]]; then
    log "INFO" "Target directory contains $existing_keys existing key files"

    # Create backup of existing keys if requested
    if [[ "$CREATE_BACKUP" == "true" ]]; then
      create_backup "$TARGET_DIR" || exit 1
    else
      log "WARN" "Skipping backup of existing keys"
    fi
  else
    log "INFO" "Target directory is empty"
  fi
else
  log "INFO" "Target directory does not exist, will create: $TARGET_DIR"
fi

# Perform the restore (or dry run)
if [[ "$DRY_RUN" == "true" ]]; then
  log "INFO" "Dry run completed successfully, no changes made"
  exit 0
else
  # Perform the actual restore
  restore_keys "$BACKUP_DIR" "$TARGET_DIR" || exit 1

  # Verify the restore if requested
  if [[ "$VERIFY" == "true" ]]; then
    log "INFO" "Verifying restore..."

    # Count restored keys
    restored_keys=$(find "$TARGET_DIR" -type f -name "*.json" | wc -l)
    source_keys=$(find "$BACKUP_DIR" -type f -name "*.json" | wc -l)

    if [[ "$restored_keys" -ne "$source_keys" ]]; then
      log "ERROR" "Restore verification failed: expected $source_keys, found $restored_keys"
      exit 1
    fi

    log "INFO" "Restore verification passed: $restored_keys keys restored"
  fi

  log "INFO" "Restore operation completed successfully"
fi

# Print summary
log "INFO" "----- Restore Summary -----"
log "INFO" "Backup Source: $BACKUP_DIR"
log "INFO" "Restore Target: $TARGET_DIR"
log "INFO" "Keys Restored: $(find "$TARGET_DIR" -type f -name "*.json" | wc -l)"
if [[ "$CREATE_BACKUP" == "true" && -d "$TARGET_DIR" ]]; then
  log "INFO" "Backup Created: ${TARGET_DIR}_backups/latest"
fi
log "INFO" "-------------------------"
