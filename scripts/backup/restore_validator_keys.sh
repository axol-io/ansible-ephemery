#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
# Validator Key Restore Script
# This script restores validator keys from backups created by the Ansible Ephemery system

set -e # Exit on error

# Default variables
EPHEMERY_BASE_DIR="${EPHEMERY_BASE_DIR:-${HOME}/ephemery}"
BACKUP_DIR="${EPHEMERY_BASE_DIR}/backups/validator/keys"
KEYS_DIR="${EPHEMERY_BASE_DIR}/secrets/validator/keys"
TEMP_DIR="${EPHEMERY_BASE_DIR}/tmp/restore_temp"
BACKUP_TO_RESTORE=""
VERBOSE=false
FORCE=false
CONTAINER_NAME="ephemery-validator-lighthouse"

# Function to display usage information
function show_usage() {
  echo "Validator Key Restore Utility"
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -l, --list                List available backups"
  echo "  -b, --backup [PATH]       Specify backup to restore (full path or timestamp)"
  echo "  -r, --restore-latest      Restore from the latest backup"
  echo "  -f, --force               Force restore without confirmation"
  echo "  -v, --verbose             Show detailed information during restore"
  echo "  -c, --container [NAME]    Specify validator container name (default: ${CONTAINER_NAME})"
  echo "  -h, --help                Show this help message"
  echo ""
  echo "Example: $0 --restore-latest"
  echo "         $0 --backup 20230415_120000"
}

# Function to list available backups
function list_backups() {
  echo "Available validator key backups:"
  echo "----------------------------------"

  if [ ! -d "${BACKUP_DIR}" ]; then
    echo "No backups directory found at: ${BACKUP_DIR}"
    exit 1
  fi

  # List backups with details
  backup_count=0
  latest_backup=""

  if [ -f "${BACKUP_DIR}/latest_backup" ]; then
    latest_backup=$(cat "${BACKUP_DIR}/latest_backup")
  fi

  echo "| Timestamp | Key Count | Size | Path |"
  echo "|-----------|-----------|------|------|"

  for backup in $(find "${BACKUP_DIR}" -maxdepth 1 -mindepth 1 -type d | sort -r); do
    # Skip the "latest_backup" file
    if [ "${backup}" == "${BACKUP_DIR}/latest_backup" ]; then
      continue
    fi

    # Count keys in the backup
    key_count=$(find "${backup}" -name "keystore-*.json" | wc -l)

    # Calculate backup size
    backup_size=$(du -sh "${backup}" | cut -f1)

    # Get basename for timestamp display
    timestamp=$(basename "${backup}")

    # Mark the latest backup
    latest_marker=""
    if [ "${backup}" == "${latest_backup}" ]; then
      latest_marker=" (latest)"
    fi

    echo "| ${timestamp}${latest_marker} | ${key_count} keys | ${backup_size} | ${backup} |"

    backup_count=$((backup_count + 1))
  done

  if [ ${backup_count} -eq 0 ]; then
    echo "No backups found in ${BACKUP_DIR}"
  else
    echo ""
    echo "Found ${backup_count} backup(s)"
  fi
}

# Function to verify backup exists
function verify_backup() {
  local backup_path="$1"

  # If timestamp was provided instead of full path
  if [[ ! "${backup_path}" == /* ]]; then
    # Try to resolve backup path from timestamp
    resolved_path="${BACKUP_DIR}/${backup_path}"
    if [ -d "${resolved_path}" ]; then
      backup_path="${resolved_path}"
    else
      echo "Error: Backup with timestamp ${backup_path} not found."
      exit 1
    fi
  fi

  # Check if the backup directory exists
  if [ ! -d "${backup_path}" ]; then
    echo "Error: Backup directory not found at ${backup_path}"
    exit 1
  fi

  # Check if the backup directory contains keystore files
  key_count=$(find "${backup_path}" -name "keystore-*.json" | wc -l)
  if [ "${key_count}" -eq 0 ]; then
    echo "Error: No validator keys found in backup directory"
    exit 1
  fi

  echo "Verified backup at ${backup_path} containing ${key_count} keys"
  return 0
}

# Function to get the latest backup
function get_latest_backup() {
  if [ -f "${BACKUP_DIR}/latest_backup" ]; then
    latest=$(cat "${BACKUP_DIR}/latest_backup")
    if [ -d "${latest}" ]; then
      echo "${latest}"
      return 0
    fi
  fi

  # If latest_backup file doesn't exist or points to an invalid directory,
  # find the most recent backup directory
  latest=$(find "${BACKUP_DIR}" -maxdepth 1 -mindepth 1 -type d | sort -r | head -n 1)

  if [ -z "${latest}" ]; then
    echo "Error: No backups found."
    exit 1
  fi

  echo "${latest}"
  return 0
}

# Function to stop the validator container
function stop_validator() {
  echo "Stopping validator container to prevent slashing..."
  if docker container inspect "${CONTAINER_NAME}" &>/dev/null; then
    docker stop "${CONTAINER_NAME}"
    echo "Validator container stopped"
  else
    echo "Warning: Validator container ${CONTAINER_NAME} not found or not running"
  fi
}

# Function to start the validator container
function start_validator() {
  echo "Starting validator container..."
  if docker container inspect "${CONTAINER_NAME}" &>/dev/null; then
    docker start "${CONTAINER_NAME}"
    echo "Validator container started"
  else
    echo "Warning: Validator container ${CONTAINER_NAME} not found"
  fi
}

# Function to restore keys from backup
function restore_keys() {
  local source_dir="$1"
  local key_count=$(find "${source_dir}" -name "keystore-*.json" | wc -l)

  echo "Starting key restore process from: ${source_dir}"
  echo "Found ${key_count} keys to restore"

  # Create a backup of the current keys before restoration (for safety)
  if [ -d "${KEYS_DIR}" ] && [ -n "$(ls -A "${KEYS_DIR}" 2>/dev/null)" ]; then
    BACKUP_TIME=$(date +%Y%m%d_%H%M%S)
    PRE_RESTORE_BACKUP="${BACKUP_DIR}/pre_restore_${BACKUP_TIME}"
    echo "Creating safety backup of current keys to: ${PRE_RESTORE_BACKUP}"
    mkdir -p "${PRE_RESTORE_BACKUP}"
    cp -a "${KEYS_DIR}"/* "${PRE_RESTORE_BACKUP}"/ 2>/dev/null || true
    echo "Safety backup created"
  fi

  # Create temporary directory for staged restore
  echo "Creating temporary directory for staged restore..."
  mkdir -p "${TEMP_DIR}"
  rm -rf "${TEMP_DIR}"/* 2>/dev/null || true

  # Copy backup keys to temporary directory
  echo "Copying keys to temporary directory..."
  cp -a "${source_dir}"/* "${TEMP_DIR}"/

  # Verify keys in temporary directory
  temp_key_count=$(find "${TEMP_DIR}" -name "keystore-*.json" | wc -l)
  if [ "${temp_key_count}" -ne "${key_count}" ]; then
    echo "Error: Key count mismatch after copying to temporary directory"
    echo "Expected: ${key_count}, Found: ${temp_key_count}"
    echo "Restore aborted"
    exit 1
  fi

  # Clear existing keys directory
  echo "Clearing existing keys directory..."
  mkdir -p "${KEYS_DIR}"
  rm -rf "${KEYS_DIR}"/* 2>/dev/null || true

  # Move keys from temporary directory to keys directory
  echo "Moving keys to final destination..."
  cp -a "${TEMP_DIR}"/* "${KEYS_DIR}"/

  # Verify keys in final location
  final_key_count=$(find "${KEYS_DIR}" -name "keystore-*.json" | wc -l)
  if [ "${final_key_count}" -ne "${key_count}" ]; then
    echo "Error: Key count mismatch after final copy"
    echo "Expected: ${key_count}, Found: ${final_key_count}"
    echo "Attempting rollback..."

    # Rollback to pre-restore state
    if [ -d "${PRE_RESTORE_BACKUP}" ]; then
      rm -rf "${KEYS_DIR}"/* 2>/dev/null || true
      cp -a "${PRE_RESTORE_BACKUP}"/* "${KEYS_DIR}"/ 2>/dev/null || true
      echo "Rollback completed"
    else
      echo "No pre-restore backup found for rollback"
    fi

    exit 1
  fi

  # Set correct permissions on restored keys
  echo "Setting correct permissions on restored keys..."
  chmod -R 600 "${KEYS_DIR}"/*

  # Clean up temporary directory
  echo "Cleaning up temporary files..."
  rm -rf "${TEMP_DIR}"

  echo "Key restore completed successfully!"
  echo "Restored ${final_key_count} keys from backup"
}

# Parse command line options
while [[ $# -gt 0 ]]; do
  key="$1"
  case ${key} in
    -l | --list)
      list_backups
      exit 0
      ;;
    -b | --backup)
      BACKUP_TO_RESTORE="$2"
      shift
      shift
      ;;
    -r | --restore-latest)
      BACKUP_TO_RESTORE="latest"
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
    -c | --container)
      CONTAINER_NAME="$2"
      shift
      shift
      ;;
    -h | --help)
      show_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_usage
      exit 1
      ;;
  esac
done

# Main execution
if [ -z "${BACKUP_TO_RESTORE}" ]; then
  echo "Error: No backup specified for restore"
  show_usage
  exit 1
fi

# Resolve the backup path
if [ "${BACKUP_TO_RESTORE}" == "latest" ]; then
  BACKUP_PATH=$(get_latest_backup)
  echo "Using latest backup: ${BACKUP_PATH}"
else
  BACKUP_PATH="${BACKUP_TO_RESTORE}"
  # If not a full path, assume it's a timestamp
  if [[ ! "${BACKUP_PATH}" == /* ]]; then
    BACKUP_PATH="${BACKUP_DIR}/${BACKUP_PATH}"
  fi
fi

# Verify the backup
verify_backup "${BACKUP_PATH}"

# Ask for confirmation unless force flag is set
if [ "${FORCE}" != "true" ]; then
  key_count=$(find "${BACKUP_PATH}" -name "keystore-*.json" | wc -l)
  echo ""
  echo "WARNING: This operation will replace all existing validator keys!"
  echo "You are about to restore ${key_count} keys from: ${BACKUP_PATH}"
  echo ""
  read -p "Are you sure you want to continue? (y/n) " -n 1 -r
  echo ""
  if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    echo "Restore aborted by user"
    exit 0
  fi
fi

# Stop validator container
stop_validator

# Perform the restore
restore_keys "${BACKUP_PATH}"

# Start validator container
start_validator

echo ""
echo "Restore process completed successfully!"
echo "Validator keys have been restored from: ${BACKUP_PATH}"
echo ""
echo "IMPORTANT: Verify validator status and performance after restore."

exit 0
